local type = type
local error = error
local unpack = unpack
local tostring = tostring
local print = print

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
            if type(method) == 'table' then
              method = method[method_part]
            else
              return {false,'tango server error ' .. '"' .. method_name .. '": no such method'}
            end  
          end        
          if type(method) ~= 'function' then
            return {false,'tango server error ' .. '"' .. method_name .. '": no such method'}
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

    d.functab.tango.ref_release = 
      function(refid)
        d.refs[refid] = nil
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

    d.functab.tango.get = 
      function(variable_name)
        local variable = d.functab
        for variable_part in variable_name:gmatch('[%w_]+') do
          variable = variable[variable_part]
        end        
        return variable
      end    

    d.functab.tango.set = 
      function(variable_name,value)
        local tab = d.functab
        local iterator = variable_name:gmatch('[%w_]+')
        local name_part
        local next_name_part = iterator()
        local last_tab
        repeat
          name_part = next_name_part
          last_tab = tab
          tab = tab[name_part]
          next_name_part = iterator()          
        until not next_name_part
        last_tab[name_part] = value
      end    
    
    return d
  end

return {new=new}
