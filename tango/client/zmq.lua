local zmq = require"zmq"
local proxy = require'tango.proxy'
local print = print
local pcall = pcall
local globals = _G
local require = require

--- A zmq (zeromq) compatible transport backend for tango.
module('tango.client.zmq')

local new = 
  function(config)
    config = config or {}
    local context = config.context or zmq.init(1)
    local socket = context:socket(zmq.REQ)
    socket:connect(config.url or 'tcp://localhost:12345')

    local serialize = config.serialize or require'tango.utils.serialization'.serialize
    local unserialize = config.unserialize or require'tango.utils.serialization'.unserialize

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
    
    return proxy(send_request,recv_response)
  end

return new
