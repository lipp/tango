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

customerr = function(err)
               error(err)
            end

multi = function(...)
           return unpack{...}
        end

sleep = function(sec)
           os.execute('sleep '..sec)
        end

nested = {method = {name = function()return true end}}


-- starts the server on default port 12345
tango.serve()
