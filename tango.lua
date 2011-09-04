local rawget = rawget
local rawset = rawset
local setmetatable = setmetatable
local print = print
local new = require'tango.proxy'.new

module('tango.ref')

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

return {
  ref = ref,
  unref = unref
}

