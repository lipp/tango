
require'socket'
require'copas'
require'marshal'
require'coxpcall'

module('tango',package.seeall)

--local _serialize = table.marshal
--local _unserialize = table.unmarshal
local _serialize = table.sheriff
local _unserialize = table.unsheriff
local _append = table.insert
local _remove = table.remove

-- create an rpc proxy which operates on the socket 
-- provided (socket is not allowed to be copas.wrap'ed)
function proxy(socket,fpath)
  local proxytab = {}
  return setmetatable( 
    proxytab,{
      -- called when dot operator is invoked on proxy
      -- to access function or table
      __index = function(self,key)
                  local _proxy = rawget(self,key)
                  -- if not yet created, create proxy
                  if not _proxy then 
                    -- make deep copy of old fpath
                    local _newfpath
                    if not fpath then
                      _newfpath = key
                    else
                      _newfpath = fpath..'.'..key
                    end
--                    print(_newfpath)
                    _proxy = proxy(socket,_newfpath)
                    rawset(self,key,_proxy)
                  end                            
                  return _proxy
                end,

      -- when trying to invoke functions on the proxy
      -- this method will be called
      __call = function(self,...)
                 local _request = _serialize{
                   --                              fpath=getmetatable(self).fpath,
                   fpath,
                   {...}
                 }
                 -- send number of bytes the serialized table will have
                 --                          local nbytes = #_request
--                 local _tosend = string.format("%6d",#_request).._request
                 socket:send(string.format("%6d",#_request))
                 socket:send(_request)

                 -- local _tosend = string.format("%4d",#_request).._request
                 -- local sent,err = socket:send(_tosend)
                 -- if not sent then
                 --   error(err)
                 -- end
                 -- send the serialized table
                 -- local sent = 0
                 -- repeat 
                 --   local sent,err = socket:send(_request,sent+1,)
                 --   if not sent then
                 --     error(err)
                 --   end
                 --   nbytes = nbytes - sent
                 -- until nbytes > 0
                 -- flush the socket to allow fast response
                 --                            copas.flush(socket:flush()
                 
                 -- receive the length of the response
                 --                            local nbytes,err = socket:receive('*l')
                 local nbytes,err = socket:receive(6)
                 if not nbytes then
                   -- propagate error
                   error(err)
                   return 
                 end
                 -- receive the response
                 local _response,err = socket:receive(tonumber(nbytes))
                 if not _response then
                   -- propagate error
                   error(err)
                   return 
                 end
                 local _responsetab = _unserialize(_response)
                 -- the response table contains all, the 
                 -- {pcall(...)} returns on the server side
                 if _responsetab[1] == true then
                   _remove(_responsetab,1)
                   -- return all results
                   return unpack(_responsetab)
                 else
                   -- propagate error
                   error(_responsetab[2])
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







