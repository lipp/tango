-- sample server
require'tango'

add = function(a,b)
         return a+b
      end

echo = function(arg)
          return arg
       end

strerror = function(err)
              error(err)
           end

customerror = function(err)
               error(err)
            end

multi = function(...)
           return unpack{...}
        end

msleep = function(msec)           
           local sleepcmd = 'sleep 0.'..string.format('%03d',msec)
           print(sleepcmd)
           io.popen(sleepcmd):read()           
        end

nested = {method = {name = function()return true end}}


-- starts the server on default port 12345
tango.serve()
