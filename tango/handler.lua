-- private helpers
local type = type
--local print = print
local sgmatch = string.gmatch
local unpack = unpack
local print = print
local serialization = require'tango.serialization'
local serialize = serialization.serialize
local unserialize = serialization.unserialize

-- to access outer function in the proxy remote call (__call)
local globals = _G

--- A simple and transparent remote procedure module inspired by LuaRPC.
-- It requires LuaSocket and Copas.
-- Tango relies on a customizable table serialization. 
module('tango.handler')

local path_error =
  function(path)                           
    return {type = 'server',
            code = path_error,
            desc = 'tango server could not resolve path:'..path,
            path = path}
  end    

local nofunction_error =
  function(path)                           
    return {code = nofunction_error,
            desc = 'tango server path does not resolve to function:'..path,
            path = path}
  end


call = 
  function(request,func_tab,pcall)
    local unserialize = unserialize
    local serialize = serialize            
    local request_tab = unserialize(request)
    local func = func_tab
    local path = request_tab[1]
    local response_tab = nil
    for path_part in sgmatch(path,'[%w_]+') do
      if type(func) == 'table' and func[path_part] then
        func = func[path_part]
      else
        return serialize{false,nil,path_error(path)}
      end  
    end        
    if type(func) ~= 'function' then
      return serialize{false,nil,nofunction_error(path)}
    end        
    local response_tab = {pcall(
                            function()
                              return func(unpack(request_tab[2]))
                            end)}                                       
    return serialize(response_tab)
  end    

