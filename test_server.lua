local backend = arg[1]

add = function(a,b)
         return a+b
      end

echo = function(...)
          return ...
       end

strerror = function()
              error('testmessage')
           end

customerror = function(err)
               error(err)
            end

nested = {
  method = {
    name = function()return true end
  }
}

local server = require('tango.server.'..backend)
server.loop()
