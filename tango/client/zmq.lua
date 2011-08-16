local zmq = require"zmq"
local serialize = require'tango.utils.serialization'.serialize
local unserialize = require'tango.utils.serialization'.unserialize
local proxy = require'tango.proxy'
local print = print
local pcall = pcall
local globals = _G

--- A zmq (zeromq) compatible transport backend for tango.
module('tango.client.zmq')

local new = 
   function(zmq_url,context,call_type)
      local context = context or zmq.init(1)
      local socket = context:socket(zmq.REQ)
      socket:connect(zmq_url or 'tcp://localhost:12345')

      local send_request = 
         function(request)             
            local request_str = serialize(request)
            socket:send(request_str)
         end
      
      local recv_response = 
         function()
            local response_str = socket:recv()
            return unserialize(response_str)    
         end
      
      return proxy.new(send_request,recv_response)
   end

return new
