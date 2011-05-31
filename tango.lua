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

-- to access outer function in the proxy remote call (__call)
local globals = _G

--- A simple and transparent remote procedure module inspired by LuaRPC.
-- It requires LuaSocket and Copas.
-- Tango relies on a customizable table serialization. 
module('tango')

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

--- error codes
send_error = 1
receive_error = 2
comtimeout_error = 3
calltimeout_error = 4
path_error = 5
nofunction_error = 6
protocol_error = 7


local throw = function(errtab,level)
                if throwtable == true then
                  errtab.tangoerr = true
                  error(errtab,level or 1)
                else
                  error(errtab.desc,level or 1)
                end
              end

local throw_send_error = function(path,err)                           
                           if err == 'timeout' then
                             throw_comtimeout_error(path,'socket.send')
                           end                           
                           throw({type = 'socket',
                                  code = send_error,
                                  desc = 'tango socket.send error:'..err,
                                  path = path},2)
                         end

local throw_comtimeout_error = function(path,method)
                                 throw({type = 'timeout',
                                        code = comtimeout_error,
                                        desc = 'tango comtimeout error during '..method,
                                        path = path},3)
                               end

local throw_calltimeout_error = function(path)
                                  throw({type = 'timeout',
                                         code = calltimeout_error,
                                         desc = 'tango calltimeout during call to:'..path,
                                         path = path},2)
                                end

local throw_protocol_error = function(path,err)    
                               throw({type = 'protocol',
                                      code = protocol_error,
                                      desc = 'tango protocol error:'..err,
                                      path = path},2)
                             end

local throw_receive_error = function(path,err)                           
                              if err == 'timeout' and awaiting_call then
                                throw_comtimeout_error(path,'socket.receive')
                              end
                              throw({type = 'socket',
                                     code = receive_error,
                                     desc = 'tango socket.receive error:'..err,
                                     path = path},2)
                            end


local path_error = function(path)                           
                     return {type = 'server',
                             code = path_error,
                             desc = 'tango server could not resolve path:'..path,
                             path = path}
                   end

local nofunction_error = function(path)                           
                           return {type = 'server',
                                   code = nofunction_error,
                                   desc = 'tango server path does not resolve to function:'..path,
                                   path = path}
                         end

--- Private helper. Do not use directly, use client function instead.
-- Create a rpc proxy which operates on the socket provided (socket is not allowed to be copas.wrap'ed)
-- functionpath is used internally and should not be assigned by users (addresses the remote function and may look like "a.b.c")
-- @see client
proxy = function(socket,options,path)
          return setmetatable( 
            {options=options,
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
                         local path = rawget(self,'path')
                         -- wrap the proxy path and the variable arguments into a table and serialize it
                         local request = serialize{path,{...}}
                         local options = rawget(self,'options')
                         local socket = rawget(self,'socket')
                         local comtimeout = options.comtimeout
                         local calltimeout = options.calltimeout
                         if comtimeout ~= calltimeout then
                           socket:settimeout(comtimeout)
                         end
                         -- send tabmaxdecimals ascii coded length
                         local sent,err = socket:send(formatlen(#request))
                         if not sent then
                           throw_send_error(path,err)
                         end
                         -- send the actual table data
                         sent,err = socket:send(request)
                         if not sent then
                           throw_send_error(path,err)
                         end
                         -- receive/wait on answer
                         if comtimeout ~= calltimeout then
                           socket:settimeout(calltimeout)
                         end
                         local responselen,err = socket:receive(tabmaxdecimals)                         
                         if not responselen then
                           if err == 'timeout' then
                             throw_calltimeout_error(path)
                           else
                             throw_receive_error(path,err)
                           end
                         end                         
                         -- convert ascii len to number of bytes
                         responselen = tonumber(responselen)
                         if not responselen then
                           throw_protocol_error(path,'length as ascii number string not ok')
                         end                       
                         if comtimeout ~= calltimeout then
                           socket:settimeout(comtimeout)
                         end
                         -- receive the actual response table dataa
                         local response,err = socket:receive(responselen)
                         if not response then
                           throw_receive_error(path,err)
                         end
                         
                         -- unserialize into a table
                         local responsetab = unserialize(response)
                         if responsetab[1] == true then
                           tremove(responsetab,1)
                           return unpack(responsetab)                           
                         elseif responsetab[2] then
                           -- 'normal' error simply forward
                           error(responsetab[2])
                         else
                           throw(responsetab[3])
                         end
                       end
            })
        end

--- For programmatically handle tango errors.
-- Behaves as normal pcall but returns additional tango error table in case of error.
-- @return As pcall would. In case of a tango error, a third return value is given. @see throw and throw_xyz
-- for possible table content.
-- @usage status,msg,tangoerr=tango.pcall(function() proxy.risky_business(arg) end); if tangoerr then ...
pcall = function(f,...)
          -- changes behaviour of throw to 'error' tables in case of tange errors
          throwtable = true
          local result = {gpcall(f,...)}
          -- changes behaviour of throw to 'error' strings
          throwtable = false
          if result[1] == true then
            return unpack(resulttab)
          else 
            local err = result[2] 
            if type(err) == 'table' and err.tangoerr and err.code then
              return false,err.desc,err
            end
            return false,err
          end
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
                
                local servercall = function(requesttab)
                                     -- grab global table as root 
                                     local func = globals
                                     -- iterate over path and search corresponding tab
                                     -- requesttab[1] contains the proxy path, e.g. 'a.b.c.d'
                                     local path = requesttab[1]
                                     local responsetab = nil
                                     for pathpart in sgmatch(path,'[%w_]+') do
                                       if type(func) == 'table' and func[pathpart] then
                                         func = func[pathpart]
                                       else
                                         return {false,nil,path_error(path)}
                                       end  
                                     end
                                     
                                     if type(func) ~= 'function' then
                                       return {false,nil,nofunction_error(path)}
                                     end
                                     
                                     -- call the function and collect all return values in table
                                     -- requesttab[2] contains the arguments as table
                                     return {copcall(
                                               function()
                                                 return func(unpack(requesttab[2]))
                                               end)}                                       
                                   end
                  

                
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
                                         local response = serialize(servercall(unserialize(request)))                                         
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

