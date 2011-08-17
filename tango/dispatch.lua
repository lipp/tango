local type = type
local error = error
local unpack = unpack

module('tango.dispatch')

--- Dispatches the specified request.
-- @param request A table which holds as first element the method name with dots as table separators (e.g. os.getenv) and es second parameter the arguments wrapped in a table.
-- @param root A (nested) table which holds all the methods, which can be called. To allow global access, pass _G.
-- @param pcall The pcall to use. Some event environments require "special" pcalls, like copcall for the copas framework.
-- @return A table which holds the wrapped pcall result.
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
         return {false,'tango server path is not a function:'..method_name}
      end        
      return {pcall(method,unpack(request,2))}
   end    

return dispatch
