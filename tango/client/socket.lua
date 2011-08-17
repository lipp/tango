local tonumber = tonumber
local tostring = tostring
local error = error
local pcall = pcall
local socket = require'socket'
local proxy = require'tango.proxy'
local send_message = require'tango.utils.socket_message'.send
local receive_message = require'tango.utils.socket_message'.receive
local serialize = require'tango.utils.serialization'.serialize
local unserialize = require'tango.utils.serialization'.unserialize

module('tango.client.socket')

local new
new = 
   function(adr,port,timeout)
      local sock = socket.tcp()
      sock:settimeout(timeout or 5000)
      sock:setoption('tcp-nodelay',true)
      local connected,err = sock:connect(adr or 'localhost',port or 12345)
      if not connected then
         error(err)
      end

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
