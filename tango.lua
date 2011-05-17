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
local error = error
local print = print
local loadstring = loadstring
local unpack = unpack

-- to access outer function in the proxy remote call (__call)
local globals = _G

--- A simple and transparent remote procedure module inspired by LuaRPC.
-- It requires LuaSocket and Copas.
-- Tango relies on a customizable table serialization. 
module('tango')

--- error codes
invalid_path = 1
no_function = 2

-- private helper for serialize
-- converts a value to a string, used by @see tango.serialize
-- copied from http://lua/users.org/wiki/TableUtils
local valtostr = function(v)
                    local vtype = type(v)
                    if 'string' == vtype then
                      v = sgsub(v,"\n","\\n")
                      if smatch(sgsub(v,"[^'\"]",""),'^"+$') then
                        return "'"..v.."'"
                      end
                      return '"'..sgsub(v,'"','\\"')..'"'
                    else
                      return 'table' == vtype and serialize(v) or tostring(v)
                    end
                  end

-- private helper for serialize
-- converts a key to a string, used by @see tango.serialize
-- copied from http://lua/users.org/wiki/TableUtils
local keytostr = function(k)
                    if 'string' == type(k) and smatch(k,"^[_%a][_%a%d]*$") then
                      return k
                    else
                      return '['..valtostr(k)..']'
                    end
                  end

--- Default table serializer.
-- Implementation copied from http://lua/users.org/wiki/TableUtils.
-- May be overwritten for custom serialization (function must take a table and return a string).
-- @param tbl the table to be serialized
-- @return the serialized table as string
-- @usage tango.serialize = table.marshal (using lua-marshal as serializer)
serialize = function(tbl)
              local result,done = {},{}
              for k,v in ipairs(tbl) do
                tinsert(result,valtostr(v))
                done[k] = true
              end
              for k,v in pairs(tbl) do
                if not done[k] then
                  tinsert(result,keytostr(k)..'='..valtostr(v))
                end
              end
              return '{'..tconcat(result,',')..'}'
            end

--- Default table unserializer.
-- May be overwritten with custom serialization.
-- Unserializer must take a string as argument and return a table.
-- @param strtbl the serialized table as string
-- @return the unserialized table
-- @usage tango.unserialize = table.unmarshal (using lua-marshal as serializer)
unserialize = function(strtab)
                -- assuming strtab contains a stringified table
                return loadstring('return '..strtab)()
              end

--- The maximum number of decimals the serialized table's size can grow to.
-- This value can be reduced to save very some bytes of traffic.
-- @usage tango.tabmaxdecimals=3 (allow 999 bytes maximum table length and safe some bytes traffic)
tabmaxdecimals = 12

--- private helper
local formatlen = function(len)
                     return sformat('%'..tabmaxdecimals..'d',len)
                   end

call = function(proxy,...)
           -- wrap the proxy path and the variable arguments into a table
           local request = serialize{
              rawget(proxy,'path'),
              {...}
           }
           local options = rawget(proxy,'options')
           local socket = rawget(proxy,'socket')
           local comtimeout = options.comtimeout
           local calltimeout = options.calltimeout
           if comtimeout ~= calltimeout then
              socket:settimeout(comtimeout)
           end
           -- send tabmaxdecimals ascii coded length
           local sent,err = socket:send(formatlen(#request))
           if not sent then
              -- propagate error
              error('tango error socket.send:'..err)
           end
           -- send the table
           sent,err = socket:send(request)
           if not sent then
              -- propagate error
              error('tango error socket.send:'..err)
           end
           
           -- receive/wait on answer
           if comtimeout ~= calltimeout then
              socket:settimeout(calltimeout)
           end
           local responselen,err = socket:receive(tabmaxdecimals)
           if not responselen then
              -- propagate error
              error('tango error socket.receive:'..err)
              return 
           end
           
           -- convert ascii len to number of bytes
           responselen = tonumber(responselen)
           if not responselen then
              -- propagate error
              error('response format error')
              return 
           end
           
           if comtimeout ~= calltimeout then
              socket:settimeout(comtimeout)
           end
           -- receive the response
           local response,err = socket:receive(responselen)
           if not response then
              -- propagate error
              error(err)
              return 
           end
           
           -- unserialize into a table
           return unserialize(response)
        end

--- Private helper. Do not use directly, use client function instead.
-- Create a rpc proxy which operates on the socket provided (socket is not allowed to be copas.wrap'ed)
-- functionpath is used internally and should not be assigned by users (addresses the remote function and may look like "a.b.c")
-- @see client
proxy = function(socket,options,path)
          return setmetatable( {options=options,
                                path=path,
                                socket=socket},{
               --- Private helper.
               -- Called when dot operator is invoked on proxy
               -- to access function or table
               -- @param self the parent proxy
               -- @param key the proxy / remote table key to index
               __index = function(self,key)
                           -- look up if proxy already exists
                           local proxytab = rawget(self,key)
                           -- if proxy is not yet created, create proxy
                           if not proxytab then 
                             -- make deep copy of old fpath
                             local newpath
                             if not path then
                               newpath = key
                             else
                               newpath = path..'.'..key
                             end
                             -- call proxy constructor
                             proxytab = proxy(socket,options,newpath)
                             -- store proxytab for next __index call
                             rawset(self,key,proxytab)
                           end                            
                           return proxytab
                         end,

               --- Private helper.
               -- When trying to invoke functions on the proxy, this method will be called
               -- wraps the variable arguments into a table and transmits them to the server 
               -- @param self the proxy
               -- @param ... variable argument list
               __call = function(self,...)
                           local resulttab = call(self,...)
                           if resulttab[1] == true then
                              tremove(resulttab,1)
                              -- return all results
                              return unpack(resulttab)
                           else
                              -- propagate error
                              error(resulttab[2])
                           end                                                      
                        end
             })
        end

pcall = function(proxy,...)
           return unpack(call(proxy,...))
        end

--- Returns a proxy to the specified client.
-- Invoke remote functions on the returned variable.
-- @usage c = tango.connect('localhost'); c.greet('horst')
-- it is also possible to functions inside tables, like
-- @usage c.utils.greetall()
-- @return a proxy to the server global table
-- @param adr the server address, may be server name e.g. www.horst.de
-- @param port the port on which the server listens (default 12345)
-- @param options
client = function(adr,port,options)
           local options = options or {}
           options.comtimeout = options.comtimeout or 5000
           options.calltimeout = options.calltimeout or 5000
           local sock = socket.tcp()
           sock:settimeout(options.comtimeout)
           sock:setoption('tcp-nodelay',true)
           local ok,err = sock:connect(adr,port or 12345)
           if not ok then
             return nil,err
           end
           return proxy(sock,options)
         end

--- Returns a copas compatible server, which holds the connection and 
-- dispatches all proxy / client requests. 
-- @return a copas server
-- @param socket a lua socket instance, which should be delivered by copas
copasserver = function(socket)
                socket:setoption('tcp-nodelay',true)
                local ok,callerr
                
                -- wrap to allow copas to yield / let other asznc services run
                local wrapsocket = copas.wrap(socket)
                repeat 
                  -- read length of request as ascii
                  local requestlen,err = wrapsocket:receive(tabmaxdecimals)
                  if not requestlen then
                    return 
                  end
                  local requestlen = tonumber(requestlen)

                  -- read request
                  local request = wrapsocket:receive(requestlen)
                  if not request then
                    return 
                  end

                  -- method 
                  ok,callerr = copcall(function()    
                                         -- backing up serialization to allow serialization exchange
                                         local unserialize = unserialize
                                         local serialize = serialize
                                         
                                         local requesttab = unserialize(request)
                                         -- grab global table as root 
                                         local func = globals
                                         -- iterate over path and search corresponding tab
                                         -- requesttab[1] contains the proxy path, e.g. 'a.b.c.d'
                                         local errtab = nil
                                         local path = requesttab[1]
                                         for pathpart in sgmatch(path,'[%w_]+') do
                                            if type(func) == 'table' and func[pathpart] then
                                               func = func[pathpart]
                                            else
                                               errtab = {source='tango',
                                                         code=invalid_path,
                                                         desc='invalid proxy path: '..path,
                                                         value=path}
                                            end  
                                         end
                                         
                                         if not errtab and type(func) ~= 'function' then
                                            errtab = {source='tango',
                                                      code=no_function,
                                                      desc='proxy path is not a function: '..path,
                                                      value=path}
                                         end

                                         local responsetab = nil
                                         if errtab then
                                            responsetab = {false,errtab.desc,errtab}
                                         else
                                            -- call the function and collect all return values in table
                                            -- requesttab[2] contains the arguments as table
                                            responsetab = {copcall(
                                                              function()
                                                                 return func(unpack(requesttab[2]))
                                                              end)}
                                         end

                                         -- serialize table to string
                                         local response = serialize(responsetab)

                                         -- send response length
                                         local sent = wrapsocket:send(formatlen(#response))
                                         if not sent then
                                           return 
                                         end                                
                                         
                                         -- send response
                                         sent = wrapsocket:send(response)
                                         if not sent then
                                           return 
                                         end                                
                                         wrapsocket:flush()
                                       end)--pcall end
                until ok == false
                print(callerr)
              end


--- Starts a tango stand-alone server.
-- For standalone usage of tango server, never returns.
-- To use a server in 'parallel' with other copas service call manually copas.addserver(...,tango.copasserver)
-- @param port server will bind the all interfaces on the specified port (default 12345)
serve = function(port)
          copas.addserver(socket.bind('*',port or 12345),copasserver)
          copas.loop()
        end

