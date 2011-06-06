local socket = require'socket'
local copas = require'copas'
local coxpcall = require'coxpcall'

-- private helpers
local tinsert = table.insert
local tconcat = table.concat
local tremove = table.remove
local smatch = string.match
local sgmatch = string.gmatch
local sgsub = string.gsub
local sformat = string.format
local copas = copas
local socket = socket
local setmetatable = setmetatable
local rawget = rawget
local rawset = rawset
local ipairs = ipairs
local pairs = pairs
local type = type
local tostring = tostring
local tonumber = tonumber
local copcall = copcall
local gpcall = pcall
local error = error
local print = print
local loadstring = loadstring
local unpack = unpack
local assert = assert
local proxy = require'tango.proxy'
local handler = require'tango.handler'
local serialization = require'tango.serialization'
local serialize = serialization.serialize
local unserialize = serialization.unserialize

-- to access outer function in the proxy remote call (__call)
local globals = _G

--- A simple and transparent remote procedure module inspired by LuaRPC.
-- It requires LuaSocket and Copas.
-- Tango relies on a customizable table serialization. 
module('tango.copas')

--- The maximum number of decimals the serialized table's size can grow to.
-- This value can be reduced to save very some bytes of traffic.
-- @usage tango.tabmaxdecimals=3 (allow 999 bytes maximum table length and safe some bytes traffic)
tabmaxdecimals = 12

--- private helper
local formatlen = 
  function(len)
    return sformat('%'..tabmaxdecimals..'d',len)
  end

local send = 
  function(socket,tab)
    -- send tabmaxdecimals ascii coded length
    local sent,err = socket:send(formatlen(#tab))
    if not sent then                                                      
      error(err)
    end
    -- send the actual table data
    sent,err = socket:send(tab)
    if not sent then
      error(err)
    end
  end

local receive = 
  function(socket)
    local responselen,err = socket:receive(tabmaxdecimals)                         
    if not responselen then
      error(err)
    end                         
    -- convert ascii len to number of bytes
    responselen = tonumber(responselen)
    if not responselen then
      error('length as ascii number string not ok')
    end                       
    -- receive the actual response table dataa
    local response,err = socket:receive(responselen)
    if not response then
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
-- @param adr the server address, may be server name e.g. www.horst.de
-- @param port the port on which the server listens (default 12345)
-- @param options
client = 
  function(adr,port,timeout)
    local sock = socket.tcp()
    sock:settimeout(timeout or 5000)
    sock:setoption('tcp-nodelay',true)
    local ok,err = sock:connect(adr,port or 12345)
    if not ok then
      return error(err)
    end
    local send_tab 
      = function(tab)
          send(sock,tab)
        end
    local receive_tab 
      = function()
          return receive(sock)
        end
    return proxy.new(send_tab,receive_tab)
  end

--- Returns a copas compatible server, which holds the connection and 
-- dispatches all proxy / client requests. 
-- @return a copas server
-- @param socket a lua socket instance, which should be delivered by copas
-- @param functab A (nested) table with the functions which are exposed by the server, if not
-- specified or nil the global table _G is used, which means that ALL functions (e.g. os.exit) reachable via _G are exported.
server = 
  function(socket,functab)
    socket:setoption('tcp-nodelay',true)
    local wrapsocket = copas.wrap(socket)
    -- endless server loop
    while true do
      -- read length of request as ascii
      local request = receive(wrapsocket)
      local response = handler.call(request,functab,copcall)
      send(wrapsocket,response)
      wrapsocket:flush()
    end
  end

--- Starts a tango stand-alone server.
-- For standalone usage of tango server, never returns.
-- To use a server in 'parallel' with other copas service call manually copas.addserver(...,tango.copasserver)
-- @param port server will bind the all interfaces on the specified port (default 12345)
-- @param functab A (nested) table with the functions which are exposed by the server, if not
-- specified or nil the global table _G is used.
serve = 
  function(port,functab)
    copas.addserver(socket.bind('*',port or 12345),
                    function(socket) server(socket,functab or globals) end)
    copas.loop()
  end

