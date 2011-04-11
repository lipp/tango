-- a simple rpc lib inspired by luarpc

require'socket'
require'copas'
require'marshal'
require'coxpcall'

module('tango',package.seeall)

-- default serializer
-- the serializer must take a table as argument and return a string
local serialize = table.sheriff

-- default unserializer
-- unserializer must take a string as argument and return a table
local unserialize = table.unsheriff

-- 
local asciilen = 12

local _formatlen = function(len)
                     return string.format("%"..asciilen.."d",len)
                   end

-- to remove the first return value of the (co)pcall on the server
local _tabremove = table.remove


-- create a rpc proxy which operates on the socket provided (socket is not allowed to be copas.wrap'ed)
-- functionpath is used internally and should not be assigned by users (addresses the remote function and may look like "a.b.c")
function proxy(socket,functionpath)
  local proxytab = {}
  return setmetatable( 
    proxytab,{
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
                    proxytab = proxy(socket,newfunctionpath)
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
                   _tabremove(responsetab,1)
                   -- return all results
                   return unpack(responsetab)
                 else
                   -- propagate error
                   error(responsetab[2])
                 end                                                      
               end
    })
end

function client(adr,port,options)
  local _socket = socket.tcp()
  _socket:settimeout(options.timeout or 5000)
  _socket:setoption('tcp-nodelay',true)
  local ok,err = _socket:connect(adr,port)
  if not ok then
    return nil,err
  end
  return proxy(_socket)
end

serveclient = function(socket)
                socket:setoption('tcp-nodelay',true)
                local ok,err2  
                local _socket = copas.wrap(socket)
                repeat 
                  -- read number of request bytes
                  local _nbytes,err = _socket:receive(6)
                  if not _nbytes then
                    if err == 'closed' then 
                      print(err)
                    else
                      print('receive error:',err)
                    end
                    return 
                  end
                  local toread = tonumber(_nbytes)
                  local _request = ""
--                  repeat 
  --                  print('toread:',toread)
                  local _request,err = _socket:receive(toread)
                  if not _request then
                    print('receive error:',err)
                    return 
                  end
--                    else
  --                    toread = toread - #_requestpart
    --                  _request = _request .. _requestpart

      --              end              
        --          until toread == 0
                  ok,err2 = copcall(function()                          
                                      local _requesttab = _unserialize(_request)
                                      -- iterate over fpath and search corresponding tab
                                      local _func = _G
--                                      for _,pathpart in ipairs(_requesttab[1]) do 
                                      for pathpart in string.gmatch(_requesttab[1],"[%a_]+") do
                          --              print(pathpart)
                                        _func = _func[pathpart] 
                                      end
                                      local _responsetab = {copcall(
                                                              function()
                                                                return _func(unpack(_requesttab[2]))
                                                              end)}
--                                      local _response = 
                                      local _response = _serialize(_responsetab)
--                                      print("asdklds")
                                      _socket:send(string.format("%6d",#_response))
                                    local sent,err = _socket:send(_response)
--                                      local _tosend = string.format("%6d",#_response).._response
  --                                    local sent,err = _socket:send(_tosend)

                                      if not sent then
                                        print('send error:',err)
                                      end                                
                                      _socket:flush()
                                      --                                _socket:read(1)
                                    end)--pcall end
                until ok == false
                print("GAME OVER",err2)
              end


serve = function(port)
          copas.addserver(socket.bind('*',port),
                          serveclient)
          copas.loop()
        end







