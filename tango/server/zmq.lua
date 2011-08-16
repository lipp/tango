local zmq = require"zmq"
zmq.poller = require'zmq.poller'
local serialize = require'tango.utils.serialization'.serialize
local unserialize = require'tango.utils.serialization'.unserialize
local dispatch = require'tango.dispatch'
local print = print
local pcall = pcall
local globals = _G

module('tango.server.zmq')

--- Creates a zmq poller compatible tango rpc server.
-- @return All the stuff nedded by poller:add
-- @usage poller = zmq.poller(123); poller:add(tango.zmq.server(context,'tcp://*:12345')
local new = 
   function(args)
      args = args or {}
      local functab = args.functab or globals
      local socket = args.context:socket(zmq.REP)
      socket:bind(args.url or 'tcp://*:12345')
      local poller = args.poller
      local response_str
      local handle_request
      local send_response = function()
                               socket:send(response_str)
                               poller:modify(socket,zmq.POLLIN,handle_request)
                               print('HALLO 2')
                            end
      
      handle_request = function()
                          local request_str = socket:recv()
                          print('HALLO')
                          if not request_str then
                             socket:close()
                             return 
                          end
                          local request = unserialize(request_str)
                          local response = dispatch(request,functab,pcall)
                          response_str = serialize(response) 
                          poller:modify(socket,zmq.POLLOUT,send_response)
                       end
      
      poller:add(socket,zmq.POLLIN,handle_request)
   end

--- Creates and starts a zmq based tango rpc server.
-- Never returns.
-- If you need to handle multiple sockets use @see tango.zmq.server.
local loop = 
  function(args)     
     args = args or {}
     args.context = args.context or zmq.init(1)
     args.poller = zmq.poller(2)
     local server = new(args)
     args.poller:start()
     args.context:term()          
  end

return {loop=loop,new=new}
