local socket = require'socket'
local copas = require'copas'
local coxpcall = require'coxpcall'
local copcall = copcall
local print = print
local send_message = require'tango.utils.socket_message'.send
local receive_message = require'tango.utils.socket_message'.receive
local dispatcher = require'tango.dispatcher'
local default = require'tango.config'.server_default

module('tango.server.copas_socket')

new = 
  function(config)
    config = default(config)
    config.pcall = copcall
    config.interface = config.interface or '*'
    config.port = config.port or 12345
    local request_loop = 
      function(sock)
        sock:setoption('tcp-nodelay',true)
        local wrapsock = copas.wrap(sock)        
        local dispatcher = dispatcher.new(config)        
        local serialize = config.serialize
        local unserialize = config.unserialize        
        local ok,err = copcall(
          function()
            while true do
              local request_str = receive_message(wrapsock)
              local request = unserialize(request_str)
              local response = dispatcher:dispatch(request)
              local response_str = serialize(response)
              send_message(wrapsock,response_str)
              wrapsock:flush()
            end
          end)
        if not ok then
          print(err)
        end
      end
    return socket.bind(config.interface,config.port),request_loop    
  end

loop = 
  function(config)
    copas.addserver(new(config))
    copas.loop()
  end

return {
  new = new,
  loop = loop
}

