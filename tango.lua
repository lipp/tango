require'socket'
require'copas'
require'coxpcall'

-- private helpers
local _tinsert = table.insert
local _tconcat = table.concat
local _tremove = table.remove
local _smatch = string.match
local _sgmatch = string.gmatch
local _sgsub = string.gsub
local _sformat = string.format
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

-- to access outer function in the remote call (__call)
local _G = _G

--- A simple and transparent remote procedure module inspired by LuaRPC.
-- It requires LuaSocket and Copas.
module('tango')


-- private helper for serialize
-- copied from http://lua/users.org/wiki/TableUtils
local _valtostr = function(v)
                    local vtype = type(v)
                    if "string" == vtype then
                      v = _sgsub(v,"\n","\\n")
                      if _smatch(_sgsub(v,"[^'\"]",""),'^"+$') then
                        return "'"..v.."'"
                      end
                      return '"'.._sgsub(v,'"','\\"')..'"'
                    else
                      return "table" == vtype and serialize(v) or tostring(v)
                    end
                  end

-- private helper for serialize
-- copied from http://lua/users.org/wiki/TableUtils
local _keytostr = function(k)
                    if "string" == type(k) and _smatch(k,"^[_%a][_%a%d]*$") then
                      return k
                    else
                      return "[".._valtostr(k).."]"
                    end
                  end

--- Default serializer.
-- Implementation copied from http://lua/users.org/wiki/TableUtils.
-- May be overwritten for custom serialization (function must take a table and return a string).
-- @param tbl the table to be serialized
-- @return the serialized table as string
-- @usage tango.serialize = table.marshal (using lua-marshal as serializer)
serialize = function(tbl)
              local result, done = {}, {}
              for k,v in ipairs(tbl) do
                _tinsert(result,_valtostr(v))
                done[k] = true
              end
              for k,v in pairs(tbl) do
                if not done[k] then
                  _tinsert(result,_keytostr(k).."=".._valtostr(v))
                end
              end
              return "{".._tconcat(result,",").."}"
            end

--- Default unserializer.
-- May be overwritten for custom serialization.
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
local _formatlen = function(len)
                     return _sformat("%"..tabmaxdecimals.."d",len)
                   end



--- Private helper. Do not use directly, use client function instead.
-- Create a rpc proxy which operates on the socket provided (socket is not allowed to be copas.wrap'ed)
-- functionpath is used internally and should not be assigned by users (addresses the remote function and may look like "a.b.c")
-- @see client
_proxy = function(socket,functionpath)
           return setmetatable( 
             {},{
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
                             local newfunctionpath
                             if not functionpath then
                               newfunctionpath = key
                             else
                               newfunctionpath = functionpath..'.'..key
                             end
                             -- call proxy constructor
                             proxytab = _proxy(socket,newfunctionpath)
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
                          -- wrap the functionparh and the variable arguments into a table
                          local request = serialize{
                            functionpath,
                            {...}
                          }
                          -- send tabmaxdecimalsgth ascii coded length
                          local sent,err = socket:send(_formatlen(#request))
                          if not sent then
                            -- propagate error
                            error(err)
                          end
                          -- send the table
                          sent,err = socket:send(request)
                          if not sent then
                            -- propagate error
                            error(err)
                          end

                          -- receive/wait on answer
                          local responselen,err = socket:receive(tabmaxdecimals)
                          if not responselen then
                            -- propagate error
                            error(err)
                            return 
                          end

                          -- convert ascii len to number of bytes
                          responselen = tonumber(responselen)
                          if not responselen then
                            -- propagate error
                            error("response format error")
                            return 
                          end

                          -- receive the response
                          local response,err = socket:receive(responselen)
                          if not response then
                            -- propagate error
                            error(err)
                            return 
                          end
                          
                          -- unserialize into a table
                          local responsetab = unserialize(response)
                          -- the response table contains the {pcall(...)} table from the server 
                          if responsetab[1] == true then
                            _tremove(responsetab,1)
                            -- return all results
                            return unpack(responsetab)
                          else
                            -- propagate error
                            error(responsetab[2])
                          end                                                      
                        end
             })
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
           local sock = socket.tcp()
           sock:settimeout(options.timeout or 5000)
           sock:setoption('tcp-nodelay',true)
           local ok,err = sock:connect(adr,port or 12345)
           if not ok then
             return nil,err
           end
           return _proxy(sock)
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
                                         local unserialize_bak = unserialize
                                         local serialize_bak = serialize
                                         
                                         local requesttab = unserialize_bak(request)
                                         -- grab global table as root table
                                         local func = _G
                                         -- iterate over fpath and search corresponding tab
                                         -- requesttab[1] contains functionpath, e.g. 'a.b.c.d'
                                         for part in _sgmatch(requesttab[1],"[%w_]+") do
                                           func = func[part] 
                                         end
                                         -- call the function and collect all return values in table
                                         -- requesttab[2] contains the arguments as table
                                         local responsetab = {copcall(
                                                                function()
                                                                  return func(unpack(requesttab[2]))
                                                                end)}

                                         -- serialize table to string
                                         local response = serialize_bak(responsetab)

                                         -- send response length
                                         local sent = wrapsocket:send(_formatlen(#response))
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


--- Starts a copas server with tango.copasserver.
-- For standalone usage of tango server, never returns.
-- @param port server will bind the all interfaces on the specified port (default 12345)
serve = function(port)
          copas.addserver(socket.bind('*',port or 12345),copasserver)
          copas.loop()
        end

