-- a simple rpc lib inspired by luarpc

require'socket'
require'copas'
require'coxpcall'

module('tango',package.seeall)

-- private helpers
local _tinsert = table.insert
local _tconcat = table.concat
local _smatch = string.match
local _sgmatch = string.gmatch
local _sgsub = string.gsub
local _sformat = string.format

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

-- default serializer
-- the serializer must take a table as argument and return a string
-- copied from http://lua/users.org/wiki/TableUtils
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

-- default unserializer
-- unserializer must take a string as argument and return a table
unserialize = function(strtab)
                 -- assuming strtab contains a stringified table
                 return loadstring('return '..strtab)()
              end

-- 
local asciilen = 12

local _formatlen = function(len)
                      return _sformat("%"..asciilen.."d",len)
                   end



-- create a rpc proxy which operates on the socket provided (socket is not allowed to be copas.wrap'ed)
-- functionpath is used internally and should not be assigned by users (addresses the remote function and may look like "a.b.c")
_proxy = function(socket,functionpath)
                  local tremove = table.remove
                  return setmetatable( 
                     {},{
                        -- called when dot operator is invoked on proxy
                        -- to access function or table
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

                        -- when trying to invoke functions on the proxy, this method will be called
                        -- wraps the variable arguments into a table and transmits them to the server 
                        __call = function(self,...)
                                    -- wrap the functionparh and the variable arguments into a table
                                    local request = serialize{
                                       functionpath,
                                       {...}
                                    }
                                    -- send asciilength ascii coded length
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
                                    local responselen,err = socket:receive(asciilen)
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
                                       tremove(responsetab,1)
                                       -- return all results
                                       return unpack(responsetab)
                                    else
                                       -- propagate error
                                       error(responsetab[2])
                                    end                                                      
                                 end
                     })
               end

-- returns a proxy to the specified client 
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

-- returns a copas compatible handler, which holds the connection and 
-- dispatches all proxy / client requests 
handler = function(socket)
             socket:setoption('tcp-nodelay',true)
             local ok,callerr
             
             -- wrap to allow copas to yield / let other asznc services run
             local wrapsocket = copas.wrap(socket)
             repeat 
                -- read length of request as ascii
                local requestlen,err = wrapsocket:receive(asciilen)
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
                                local requesttab = unserialize(request)
                                -- grab global table as root table
                                local func = _G
                                -- iterate over fpath and search corresponding tab
                                -- requesttab[1] contains functionpath, e.g. 'a.b.c.d'
                                for part in _sgmatch(requesttab[1],"[%a_]+") do
                                   func = func[part] 
                                end
                                -- call the function and collect all return values in table
                                -- requesttab[2] contains the arguments as table
                                local responsetab = {copcall(
                                                        function()
                                                           return func(unpack(requesttab[2]))
                                                        end)}

                                -- serialize table to string
                                local response = serialize(responsetab)

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


-- starts a copas server with tango.handler 
serve = function(port)
           copas.addserver(socket.bind('*',port or 12345),handler)
           copas.loop()
        end







