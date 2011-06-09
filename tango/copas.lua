local socket = require'socket'
local send_message = require'tango.socket'.send_message
local receive_message = require'tango.socket'.receive_message
local default_client = require'tango.socket'.client
local copas = require'copas'
local coxpcall = require'coxpcall'
local dispatch = require'tango'.dispatch

-- private helpers
local copcall = copcall
local print = print

-- to access outer function in the proxy remote call (__call)
local globals = _G

--- A copas compatible transport backend for tango.
-- It requires LuaSocket and Copas.
module('tango.copas')

client = default_client

--- Returns a copas compatible server, which holds the connection and 
-- dispatches all proxy / client requests. 
-- @return a copas server
-- @param socket a lua socket instance, which should be delivered by copas
-- @param functab A (deep/nested) table with the functions which are exposed by the server, if not
-- specified or nil the global table _G is used, which means that ALL functions (e.g. os.exit) reachable via _G are exported.
server = 
  function(socket,functab)
    socket:setoption('tcp-nodelay',true)
    local wrapsocket = copas.wrap(socket)
    while true do
      local request = receive_message(wrapsocket)
      local response = dispatch(request,functab,copcall)
      if response then
        send_message(wrapsocket,response)
        wrapsocket:flush()
      end
    end
  end

--- Starts a tango stand-alone server.
-- For standalone usage of tango server, never returns.
-- To use a server in 'parallel' with other copas service call manually copas.addserver(...,tango.copas.server)
-- @param port server will bind the all interfaces on the specified port (default 12345)
-- @param functab A (nested) table with the functions which are exposed by the server, if not
-- specified or nil the global table _G is used.
serve = 
  function(port,functab)
    copas.addserver(socket.bind('*',port or 12345),
                    function(socket) server(socket,functab or globals) end)
    copas.loop()
  end

