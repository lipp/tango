local backend = arg[1]

add = 
function(a,b)
         return a+b
      end

echo = 
function(...)
          return ...
       end

strerror = 
function()
              error('testmessage')
           end

customerror = 
function(err)
               error(err)
            end

nested = {
  method = {
    name = function()return true end
  }
}

person = 
  function(name)
    local p = {
      _name = name
    }
    
    function p:name(name)
      if name then
        self._name = name
      else
        return self._name
      end
    end
    
    return p
  end

local server = require('tango.server.'..backend)
server.loop()
