-- private helpers
local rawget = rawget
local rawset = rawset
local type = type
local error = error
local unpack = unpack
local setmetatable = setmetatable

--- A generic remote procedure call proxy.
module('tango.proxy')

-- define outside function definition to allow use as upvalue
local new 
new = 
   function(send_request,recv_response,method_name)
      return setmetatable(
         {},
         {
            __index= 
               function(self,sub_method_name)
                  -- look up if proxy already exists
                  local proxy = rawget(self,sub_method_name)
                  if not proxy then 
                     local new_method_name
                     if not method_name then
                        new_method_name = sub_method_name
                     else
                        new_method_name = method_name..'.'..sub_method_name
                     end
                     -- create new call proxy
                     proxy = new(send_request,recv_response,new_method_name)
                     -- store for subsequent access
                     rawset(self,sub_method_name,proxy)
                  end                            
                  return proxy
               end,        
            __call=
               function(self,...)
                  send_request({method_name,...})
                  local response = recv_response()
                  if response[1] == true then
                     return unpack(response,2)
                  else
                     error(response[2])
                  end
               end
         })
   end

return {new=new}

