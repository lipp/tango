local type = type
local error = error
local unpack = unpack
local tostring = tostring

module('tango.dispatcher')

local new = 
  function(functab,pcall)        
    local d = {
      functab = functab,
      pcall = pcall,
      dispatch = 
        function(self,request)    
          local method = self.functab
          local method_name = request[1]
          local response = nil
          for method_part in method_name:gmatch('[%w_]+') do
            if type(method) == 'table' and method[method_part] then
              method = method[method_part]
            else
              return {false,'tango server path invalid:'..method_name}
            end  
          end        
          if type(method) ~= 'function' then
            return {false,'tango server path is not a function:'..method_name}
          end        
          return {self.pcall(method,unpack(request,2))}
        end    
      }

    d.refs = {}
    d.functab.tango = functab.tango or {}
   
    d.functab.tango.ref_create = 
      function(create_method,...)
        local result = d:dispatch({create_method,...})
        if result[1] == true then
          local obj = result[2]
          if type(obj) == 'table' or type(obj) == 'userdata' then
            local id = tostring(obj)
            d.refs[id] = obj
            return id
          else
            error('tango.ref proxy did not create table nor userdata')
          end
        else
          error(result[2])
        end
      end
    
    d.functab.tango.ref_call = 
      function(refid,method_name,...)
        local obj = d.refs[refid]
        if obj then
          return obj[method_name](obj,...)
        else
          error('tango.ref invalid id' .. refid)
        end          
      end
    
    return d
  end

return {new=new}
