local zmq = require"zmq"
local proxy = require'tango.proxy'
local default = require'tango.config'.client_default

module('tango.client.zmq')

connect = 
  function(config)
    config = default(config)
    config.url = config.url or 'tcp://localhost:12345'
    config.context = config.context or zmq.init(1)
    local socket = config.context:socket(zmq.REQ)
    socket:connect(config.url)
    local serialize = config.serialize
    local unserialize = config.unserialize
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

return {
  connect = connect
}
