local socket = require'socket'
local copas = require'copas'
local coxpcall = require'coxpcall'
local copcall = copcall
local print = print
local send_message = require'tango.utils.socket_message'.send
local receive_message = require'tango.utils.socket_message'.receive
local serialize = require'tango.utils.serialization'.serialize
local unserialize = require'tango.utils.serialization'.unserialize
local dispatch = require'tango.dispatch'

-- to access outer function in the proxy remote call (__call)
local globals = _G

module('tango.server.copas_socket')

new = 
   function(socket,functab)
      print('aaaaa')
      socket:setoption('tcp-nodelay',true)
      local wrapsocket = copas.wrap(socket)
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
      if ok == false then
         print(err)
      end
   end

loop = 
   function(port,functab)
      copas.addserver(socket.bind('*',port or 12345),
                      function(socket) new(socket,functab or globals) end)
      copas.loop()
   end

