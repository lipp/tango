local zmq = require"zmq"
zmq.poller = require'zmq.poller'
local core = require'tango'
local print = print
local pcall = pcall
local globals = _G

--- A zmq (zeromq) compatible transport backend for tango.
module('tango.zmq')

--- Creates a zmq poller compatible tango rpc server.
-- @return All the stuff nedded by poller:add
-- @usage poller = zmq.poller(123); poller:add(tango.zmq.server(context,'tcp://*:12345')
server = 
  function(context,zmq_url,functab)  
    local functab = functab or globals
    local socket = context:socket(zmq.REP)
    socket:bind(zmq_url or 'tcp://*:12345')
    return socket,zmq.POLLIN,function()                                   
                               local request = socket:recv()
                               if not request then
                                 socket:close()
                               end
                               local response = core.dispatch(request,functab,pcall)
                               if response then
                                 socket:send(response)
                               end
                             end
  end

--- Creates and starts a zmq based tango rpc server.
-- Never returns.
-- If you need to handle multiple sockets use @see tango.zmq.server.
serve = 
  function(zmq_url)
    local context = zmq.init(1)
    local socket = context:socket(zmq.REP)
    socket:bind(zmq_url or 'tcp://*:12345')
    while true do            
      local request = socket:recv()
      local response = core.dispatch(request,globals,pcall)
      if response then
        socket:send(response)
      end
    end
    socket:close()
    context:term()          
  end

--- Connects to a tango.zmq.server and returns a (call) proxy to it.
client = 
  function(zmq_url,context,call_type)
    local context = context or zmq.init(1)
    local socket = context:socket(zmq.REQ)
    socket:connect(zmq_url or 'tcp://localhost:12345')
    local transport = {
      context = context,
      socket = socket,
      send_message = 
        function(tab)
          socket:send(tab)
        end,
      receive_message = 
        function(tab)
          return socket:recv()     
        end
    }           
    return core.proxy(transport,call_type or core.call)
  end

subscriber = 
  function(zmq_url, context)
    local context = context or zmq.init(1)
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

publisher = 
  function(zmq_url, context)
    local context = context or zmq.init(1)
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

