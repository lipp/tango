-- private helpers
local tremove = table.remove
local setmetatable = setmetatable
local rawget = rawget
local rawset = rawset
local type = type
local error = error
local print = print
local unpack = unpack
local serialization = require'tango.serialization'
local serialize = serialization.serialize
local unserialize = serialization.unserialize

module('tango.proxy')

local throw = function(errtab,level)
                if throw_table == true then
                  errtab. proxy_err= true
                  errtab.path = self.path
                  error(errtab,level or 1)
                else
                  error(errtab.desc,level or 1)
                end
              end

--- A call proxy.
-- Call proxies send a request table object and receive a table object in reponse.
-- @param path The remote table address delimited by dots, e.g. os.exit string.format etc.
-- @param send The method to send the serialized request table
-- @param receive The method to receive the serialized resonse table
new = 
  function(send,receive,path)
    return setmetatable(
      {},
      {
        --- Returns a proxy to the specified key path. If no proxy
        -- exists, a new one is created.
        -- Called when dot operator is invoked on proxy
        -- to access function or table
        -- @param self the parent proxy
        -- @param key the proxy / remote table key to index
        -- @return a proxy to the corresponding key / path.
        __index= 
          function(self,key)
            -- look up if proxy already exists
            local proxy = rawget(self,key)
            if not proxy then 
              local new_path
              if not path then
                new_path = key
              else
                new_path = path..'.'..key
              end
              -- create new call proxy
              proxy = new(send,receive,new_path)
              rawset(self,key,proxy)
            end                            
            return proxy
          end,        
        --- Actually calls the remote method on the proxy.
        -- When trying to invoke functions on the proxy, this method will be called
        -- wraps the variable arguments into a table and transmits them to the server 
        -- @param self the proxy
        -- @param ... variable argument list
        __call=
          function(self,...)
            local request_tab = {path,{...}}
            local request = serialize(request_tab)
--            print('aaa')
            send(request)
  --          print('bbb')
            local response = receive()
--            print('ccc')
            local response_tab = unserialize(response)
            if response_tab[1] == true then
              tremove(response_tab,1)
              return unpack(response_tab)                           
            elseif response_tab[2] then
              -- 'normal' error simply forward
              error(response_tab[2])
            else
              error(response_tab[3])
            end
          end
      })
  end

--- For programmatically handle tango errors.
-- Behaves as normal pcall but returns additional tango error table in case of error.
-- @return As pcall would. In case of a tango error, a third return value is given. @see throw and throw_xyz
-- for possible table content.
-- @usage status,msg,tangoerr=tango.pcall(function() proxy.risky_business(arg) end); if tangoerr then ...
pcall = 
  function(f,...)
    -- changes behaviour of throw to 'error' tables in case of tange errors
    throwtable = true
    local result = {gpcall(f,...)}
    -- changes behaviour of throw to 'error' strings
    throwtable = false
    if result[1] == true then
      return unpack(result)
    else 
      local err = result[2] 
      if type(err) == 'table' and err.tangoerr and err.code then
        return false,err.desc,err
      end
      return false,err
    end
  end
