-- private helpers
local type = type
local error = error
local unpack = unpack

--- A generic remote procedure call dispatcher.
module('tango.dispatch')

local dispatch = 
   function(request,root,pcall)
      local method = root
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
         return {false,'tango server path no function:'..method_name}
      end        
      return {pcall(method,unpack(request,2))}
   end    

return dispatch
