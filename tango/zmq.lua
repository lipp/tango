local zmq = require"zmq"
local core = require'tango'
local print = print
local pcall = pcall
local globals = _G

--- A zmq (zeromq) compatible transport backend for tango.
module('tango.zmq')


serve = function(zmq_url)
          local context = zmq.init(1)
          local socket = context:socket(zmq.REP)
          socket:bind(zmq_url or 'tcp://*:12345')
          while true do            
            local request = socket:recv()
            local response = core.dispatch(request,globals,pcall)
            socket:send(response)
          end
          socket:close()
          context:term()          
end

client = function(zmq_url,call_type)
           local context = zmq.init(1)
           local socket = context:socket(zmq.REQ)
           socket:connect(zmq_url or 'tcp://localhost:12345')
           local transport = {
             context = context,
             socket = socket,
             send = 
               function(tab)
                 socket:send(tab)
               end,
             receive = 
               function(tab)
                 return socket:recv()     
               end
           }           
           return core.proxy(transport,call_type or core.call)
end

subscriber = function(zmq_url)
          local context = zmq.init(1)
          local socket = context:socket(zmq.SUB)
          socket:connect(zmq_url or 'tcp://localhost:12346')
          socket:setopt(zmq.SUBSCRIBE, "")
          while true do            
            local request = socket:recv()
            core.dispatch(request,globals,pcall)
          end
          socket:close()
          context:term()                       
        end

publisher = function(zmq_url)
           local context = zmq.init(1)
           local socket = context:socket(zmq.PUB)
           socket:bind(zmq_url or 'tcp://*:12346')
           local transport = {
             context = context,
             socket = socket,
             send = 
               function(tab)
                 socket:send(tab)
               end
           }           
           return core.proxy(transport,core.notify)
end

