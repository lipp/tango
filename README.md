About
------------

tango is small, rather simple and customizable rpc package for Lua. 
It does not imply any certain io / event model. Instead tango provides
different backends for common io / event modules. The table
serialization can be customized as well.


Backends included
--------------------

* copas  
* [lua-zmq](https://github.com/Neopallium/lua-zmq)
* [lua-ev](https://github.com/brimworks/lua-ev)


Hello server (with copas backend)      
------------------------------------

      require'tango.copas'
      greet = function(...)
                print(...)
              end         
      tango.copas.serve()

Hello client (with copas backend)
------------------------------------

      require'tango.copas'
      local proxy = tango.copas.client('localhost')
      proxy.greet('Hello','Horst')

Serialization
------------
tango provides a default (lua-only) table serialization.

Anyhow, the table serialization is neither exceedingly fast nor
compact in output, but can be customized by overwriting
tango.serialize and tango.unserialize appropriate. E.g. with
lua-marshal methods table.marshal and table.unmarshal respectively
(from the [lua-marshal](https://github.com/richardhundt/lua-marshal))

      require'tango'
      require'marshal'

      tango.serialize = table.marshal  
      tango.unserialize = table.unmarshal  

