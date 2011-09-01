local type = type
local error = error
local unpack = unpack

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
    return d
  end

return {new=new}
