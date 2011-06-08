-- private helpers
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
local type_notification = 2
local type_call = 1


module('tango')

--- A generic (remote) method call.
-- Wraps the method_name and the variable arguments into a table, 
-- serializes and transmit it. Afterwards waits for reponse, unserializes
-- and unwraps it.
-- @return The unwraped response.
call = 
  function(transport,method_name,...)
    transport.send(serialize{method_name,type_call,...})
    local response = unserialize(transport.receive())
    if response[1] == true then
      return unpack(response,2)
    else
      error(response[2])
    end
  end

--- A generic notification.
-- Wraps the method_name and the variable arguments into a table, 
-- serializes and transmit it.
notify = 
  function(transport,method_name,...)
    transport.send(serialize{method_name,type_notification,...})
  end

--- A call proxy.
-- Call proxies send a request table object and receive a table object in reponse.
-- @param path The remote table address delimited by dots, e.g. os.exit string.format etc.
-- @param send The method to send the serialized request table
-- @param receive The method to receive the serialized resonse table
proxy = 
  function(transport,call,method_name)
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
          function(self,sub_method_name)
            -- look up if proxy already exists
            local prox = rawget(self,sub_method_name)
            if not prox then 
              local new_method_name
              if not method_base then
                new_method_name = sub_method_name
              else
                new_method_name = method_name..'.'..sub_method_name
              end
              -- create new call proxy
              prox = proxy(transport,call,new_method_name)
              -- store for subsequent access
              rawset(self,sub_method_name,prox)
            end                            
            return prox
          end,        
        --- Actually calls the remote method on the proxy using upvalue 'call'.
        -- @param self the proxy
        -- @param ... variable argument list
        __call=
          function(self,...)
            return call(transport,method_name,...)
          end
      })
  end

dispatch = 
  function(request_str,method_tab,pcall)
    local unserialize = unserialize
    local serialize = serialize            
    local request = unserialize(request_str)
    local method = method_tab
    local method_name = request[1]
    local request_type = request[2]
    for method_part in method_name:gmatch('[%w_]+') do
      if type(method) == 'table' and method[method_part] then
        method = method[method_part]
      else
        return serialize{
          false,
          'tango server path invalid:'..method_name
        }
      end  
    end        
    if type(method) ~= 'function' then
      return serialize{
        false,
        'tango server path does not resolve to function:'..method_name
      }
    end        
    if request_type == type_call then
      return serialize{pcall(method,unpack(request,3))}
    elseif request_type == type_notification then
      pcall(method,unpack(request,3))
    end
  end    
