local tonumber = tonumber
local tostring = tostring
local error = error
local pcall = pcall
local socket = require'socket'
local proxy = require'tango.proxy'
local send_message = require'tango.utils.socket_message'.send
local receive_message = require'tango.utils.socket_message'.receive
local require = require

module('tango.client.socket')

local new
new = 
  function(config)     
    local sock = socket.tcp()
    config = config or {}
    sock:settimeout(config.timeout or 5000)
    sock:setoption('tcp-nodelay',true)
    local connected,err = sock:connect(config.address or 'localhost',config.port or 12345)
    if not connected then
      error(err)
    end      

    local serialize = config.serialize or require'tango.utils.serialization'.serialize
    local unserialize = config.unserialize or require'tango.utils.serialization'.unserialize

    local close_and_rethrow = 
      function(err)
        sock:shutdown()
        sock:close()
        error(err,3)
      end

    local send_request = 
      function(request)         
        local req_str = serialize(request)
        local ok,err = pcall(send_message,sock,req_str)
        if ok == false then
          close_and_rethrow(err)
        end
      end

    local recv_response = 
      function()
        local ok,result = pcall(receive_message,sock)
        if ok == true then
          return unserialize(result)
        else
          close_and_rethrow(result)
        end
      end  
    return proxy(send_request,recv_response)
  end

return new
