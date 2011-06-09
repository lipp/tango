local socket = require'socket'
local copas = require'copas'
local coxpcall = require'coxpcall'
local core = require'tango'

-- private helpers
local tonumber = tonumber
local tostring = tostring
local copcall = copcall
local error = error
local print = print

-- to access outer function in the proxy remote call (__call)
local globals = _G

--- A copas compatible transport backend for tango.
-- It requires LuaSocket and Copas.
module('tango.copas')

--- Sends a string with arbitrary (binary) content.
local send = 
  function(socket,str)
    -- send length of the string as ascii line
    local sent,err = socket:send(tostring(#str)..'\n')
    if not sent then                                                      
      socket:shutdown()
      socket:close()
      error(err)
    end
    -- send the actual string data
    sent,err = socket:send(str)
    if not sent then
      socket:shutdown()
      socket:close()
      error(err)
    end
  end

--- Receives a string with arbitrary (binary) content.
local receive = 
  function(socket)
    local responselen,err = socket:receive('*l')                         
    if not responselen then
      error(err)
    end                         
    -- convert ascii len to number of bytes
    responselen = tonumber(responselen)
    if not responselen then
      socket:shutdown()
      socket:close()
      error('length as ascii number string not ok')
    end                       
    -- receive the actual response table dataa
    local response,err = socket:receive(responselen)
    if not response then
      socket:shutdown()
      socket:close()
      error(err)
    end            
    return response
  end

--- Returns a call proxy to the specified client.
-- Invoke remote functions on the returned variable.
-- @usage c = tango.connect('localhost'); c.greet('horst')
-- it is also possible to functions inside tables, like
-- @usage c.utils.greetall()
-- @return a proxy to the server global table
-- @param adr A string, which represents the server address, may be server name e.g. www.horst.de
-- @param port A number, which specifies the port on which the server listens (default 12345)
-- @param timeout A number in milliseconds, which define timeouts for all socket operations (default 5000)
-- involved using the proxy (connect,send,receive)
-- @param call A function which performs the actual call. Can be either tango.call or tango.notify (default tango.call).
client = 
  function(adr,port,timeout,call)
    local sock = socket.tcp()
    sock:settimeout(timeout or 5000)
    sock:setoption('tcp-nodelay',true)
    local connected,err = sock:connect(adr,port or 12345)
    if not connected then
      return error(err)
    end
    local transport = {
      socket = sock,
      send = function(data)
               send(sock,data)
             end,
      receive = function()
                  return receive(sock)
                end
    }
    return core.proxy(transport,call or core.call)
  end

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
      local request = receive(wrapsocket)
      local response = core.dispatch(request,functab,copcall)
      if response then
        send(wrapsocket,response)
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

