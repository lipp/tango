local rawget = rawget
local rawset = rawset
local type = type
local error = error
local unpack = unpack
local setmetatable = setmetatable

--- A generic remote procedure call proxy.
module('tango.proxy')

-- define outside function definition to allow use as upvalue

--local remote_call = 
--  function(

new = 
  function(send_request,recv_response,method_name)
    return setmetatable(
      {
        method_name = method_name,
        send_request = send_request,
        recv_response = recv_response
      },
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

ref = 
  function(proxy,...)
    local create_method = rawget(proxy,'method_name')
    local send_request = rawget(proxy,'send_request')
    local recv_response = rawget(proxy,'recv_response')
    local proxy = new(send_request,recv_response)
    return setmetatable(
      {
        id = proxy.tango.ref_create(create_method,...),
      },
      {
        __index = 
          function(self,method_name)
            return setmetatable(
              {                
              },
              {
                __call =
                  function(_,_,...)
                    return proxy.tango.ref_call(rawget(self,'id'),method_name,...)
                  end
              })
          end
      })                      
  end

return {new=new,ref=ref}

