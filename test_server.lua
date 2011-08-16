local backend = arg[1]

add = function(a,b)
         return a+b
      end

echo = function(...)
          return ...
       end

strerror = function(err)
              error(err)
           end

customerror = function(err)
               error(err)
            end

nested = {
  method = {
    name = function()return true end
  }
}

local backend = require('tango.server.'..backend)
backend.loop()
