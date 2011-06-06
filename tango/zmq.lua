local zmq = require"zmq"
local handler = require'tango.handler'
local proxy = require'tango.proxy'
local copas = require'copas'
local copcall = copcall
local print = print
local pcall = pcall
--local collectgarbage = collectgarbage
local globals = _G

module('tango.zmq')


serve = function(zmq_url)
          local context = zmq.init(1)
          local socket = context:socket(zmq.REP)
          socket:bind(zmq_url or 'tcp://*:12345')
          --socket:bind("ipc://horst")
          while true do            
            --  Wait for next request from client
            local request = socket:recv()
            local response = handler.call(request,globals,pcall)--function(f,...) f(...) return {true} end)
            socket:send(response)
          end
          --socket:close()
          --context:term()          
end
--  We never get here but if we did, this would be how we end

client = function(zmq_url)
           context = zmq.init(1)
           socket = context:socket(zmq.REQ)
           socket:connect(zmq_url or 'tcp://localhost:12345')
           local send = 
             function(tab)
               socket:send(tab)
             end
           local receive = 
             function(tab)
               return socket:recv()     
             end
           return proxy.new(send,receive)
end
