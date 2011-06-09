About
------------

tango is small, rather simple and customizable rpc package for Lua. 
It comes with protocol / event backends for:
* copas  
* [lua-zmq(3)](https://github.com/Neopallium/lua-zmq)
* [lua-ev(3)](https://github.com/brimworks/lua-ev)

Features
------------
* simple
* transparent
* easy to adopt to different io/event models
* lua-only
* customizable serialization

Usage 
-----------
Hello server (with copas backend):      

      require'tango.copas'
      greet = function(...)
                print(...)
              end         
      tango.copas.serve()

Hello client (with copas backend):
      require'tango.copas'
      local proxy = tango.copas.client('localhost')
      proxy.greet('Hello','Horst')

Serialization
------------
tango provides a default (lua-only) table serialization.

Anyhow, table serialization can be customized by overwriting
tango.serialize and tango.unserialize appropriate, e.g. with
lua-marshal methods table.marshal and table.unmarshal respectively
(from the [marshal(3)](https://github.com/richardhundt/lua-marshal))

      require'tango'
      require'marshal'

      tango.serialize = table.marshal  
      tango.unserialize = table.unmarshal  

