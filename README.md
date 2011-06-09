About
------------
tango is a one-file pure Lua module, which allows easy and transparent remote procedure calls (RPC). 
It is inspired by LuaRPC. The server is copas compatible to allow other asynchronous services to run at the same time. 

Features
------------
* one file <300 LOC
* simple
* transparent
* copas compatible
* lua-only
* customizable serialization

Usage
-----------
server.lua
 require'tango'
 test = function(args)
      print(type(args))
 end
 tango.serve(4444)

client.lua
 require'tango'
 client = tango.client('localhost',4444)
 client.test(1234)

Serialization
------------
tango provides a default (lua-only) table serialization.

Anyhow, table serialization can be customized by overwriting tango.serialize and tango.unserialize appropriate, e.g. with lua-marshal methods table.marshal and table.unmarshal respectively. 

require'tango'
require'marshal'

tango.serialize = table.marshal  
tango.unserialize = table.unmarshal  

