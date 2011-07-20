-- sample server
require'tango'

local backend = arg[1] or 'copas'

serve = require('tango.'..backend).serve

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

msleep = function(msec)           
           local sleepcmd = 'sleep 0.'..string.format('%03d',msec)
           print(sleepcmd)
           io.popen(sleepcmd):read()           
        end

nested = {
  method = {
    name = function()return true end
  }
}


-- starts the server on some default 'socket'
serve()
