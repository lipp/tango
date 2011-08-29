local socket = require'socket'
local copas = require'copas'
local coxpcall = require'coxpcall'
local copcall = copcall
local print = print
local send_message = require'tango.utils.socket_message'.send
local receive_message = require'tango.utils.socket_message'.receive
local dispatch = require'tango.dispatch'
local require = require
local globals = _G

module('tango.server.copas_socket')

new = 
  function(config)
    config = config or {}
    local socket = config.socket
    socket:setoption('tcp-nodelay',true)
    local wrapsocket = copas.wrap(socket)

    local serialize = config.serialize or require'tango.utils.serialization'.serialize
    local unserialize = config.unserialize or require'tango.utils.serialization'.unserialize
    local functab = config.functab or globals
    local ok,err = copcall(
      function()
        while true do
          local request_str = receive_message(wrapsocket)
          local request = unserialize(request_str)
          local response = dispatch(request,functab,copcall)
          local response_str = serialize(response)
          send_message(wrapsocket,response_str)
          wrapsocket:flush()
        end
      end)
    if not ok then
      print(err)
    end
  end

loop = 
  function(config)
    config = config or {}
    copas.addserver(socket.bind(config.interfaces or '*',config.port or 12345),
                    function(socket) 
                      config.socket = socket
                      new(config) 
                    end)
    copas.loop()
  end

