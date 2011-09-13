local error = error
local pcall = pcall
local socket = require'socket'
local proxy = require'tango.proxy'
local send_message = require'tango.utils.socket_message'.send
local receive_message = require'tango.utils.socket_message'.receive
local default = require'tango.config'.client_default

module('tango.client.socket')

connect = 
  function(config)         
    config = default(config)
    config.timeout = config.timeout or 5000
    config.address = config.address or 'localhost'
    config.port = config.port or 12345
    local sock = socket.tcp()
    sock:settimeout(config.timeout)
    sock:setoption('tcp-nodelay',true)
    local connected,err = sock:connect(config.address,
                                       config.port)
    if not connected then
      error(err)
    end      
    local serialize = config.serialize
    local unserialize = config.unserialize
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
    return proxy.new(send_request,recv_response)
  end

return {
  connect = connect
}
