local zmq = require"zmq"
zmq.poller = require'zmq.poller'
local serialize = require'tango.utils.serialization'.serialize
local unserialize = require'tango.utils.serialization'.unserialize
local dispatcher = require'tango.dispatcher'
local require = require
local print = print
local pcall = pcall
local globals = _G

module('tango.server.zmq')

local new = 
  function(config)
    config = config or {}
    local serialize = config.serialize or require'tango.utils.serialization'.serialize
    local unserialize = config.unserialize or require'tango.utils.serialization'.unserialize
    local functab = config.functab or globals
    local dispatcher = dispatcher.new(functab,pcall)
    local socket = config.context:socket(zmq.REP)
    socket:bind(config.url or 'tcp://*:12345')
    local poller = config.poller
    local response_str
    local handle_request
    local send_response = function()
                            socket:send(response_str)
                            poller:modify(socket,zmq.POLLIN,handle_request)
                          end
    
    handle_request = function()
                       local request_str = socket:recv()
                       if not request_str then
                         socket:close()
                         return 
                       end
                       local request = unserialize(request_str)
                       local response = dispatcher:dispatch(request)
                       response_str = serialize(response) 
                       poller:modify(socket,zmq.POLLOUT,send_response)
                     end
    
    poller:add(socket,zmq.POLLIN,handle_request)
  end

--- Creates and starts a zmq based tango rpc server.
-- Never returns.
local loop = 
  function(config)     
    config = config or {}
    config.context = config.context or zmq.init(1)
    config.poller = zmq.poller(2)
    local server = new(config)
    config.poller:start()
    config.context:term()          
  end

return {loop=loop,new=new}
