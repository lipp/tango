local rawget = rawget
local rawset = rawset
local type = type
local error = error
local unpack = unpack
local setmetatable = setmetatable
local print = print

module('tango.proxy')

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

local rproxies = {}

local root = 
  function(proxy)
    local method_name = rawget(proxy,'method_name')
    local send_request = rawget(proxy,'send_request')
    local rproxy
    if not rproxies[send_request] then
      local recv_response = rawget(proxy,'recv_response')
      rproxy = new(send_request,recv_response)
      rproxies[send_request] = rproxy
    end
    return rproxies[send_request],method_name
  end

ref = 
  function(proxy,...)
    local rproxy,create_method = root(proxy)
    return setmetatable(
      {
        id = rproxy.tango.ref_create(create_method,...),
        proxy = rproxy
      },
      {
        __index = 
          function(self,method_name)
            return setmetatable(
              {                
              },
              {
                __call =
                  function(_,ref,...)
                    local proxy = rawget(ref,'proxy')
                    return proxy.tango.ref_call(rawget(self,'id'),method_name,...)
                  end
              })
          end
      })                      
  end

unref = 
  function(ref)
    local proxy = rawget(ref,'proxy')
    local id = rawget(ref,'id')
    proxy.tango.ref_release(id)
  end

var = 
  function(proxy,value)
    local rproxy,variable_name = root(proxy)
    return rproxy.tango.var(variable_name,value)
  end

return {
  new = new,
  ref = ref,
  unref = unref,
  get = get,
  set = set  
}

