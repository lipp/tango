About
=======

tango is a small, simple and customizable RPC (remote procedure call)
module for Lua.

Its main features are:

* a generic transparent
  [proxy](https://github.com/lipp/tango/tree/master/tango/proxy.lua)
  for call invocations
* support of remote objects (tables with functions, userdata etc, see tango.ref)
* a generic [dispatch](https://github.com/lipp/tango/tree/master/tango/dispatch.lua) routine for servers
* several server implementations for different protocols, message formats and event/io
frameworks, further called backends
* several client implementations for different protocols and message formats


Backends included
---------------------

* copas  
* [lua-zmq](https://github.com/Neopallium/lua-zmq)
* [lua-ev](https://github.com/brimworks/lua-ev)

Tutorial (copas_socket server +  socket client)
============================

Greetings!
----------

The greet server code 

```lua
-- load tango module
local tango = require'tango'
-- define a nice greeting function
greet = function(...)
          print(...)
        end 
-- start listening for client connections        
tango.server.copas_socket.loop{
  port = 12345
}
```

The client code calling the remote server function `greet`
      
```lua
-- load tango module
local tango = require'tango'
-- connect to server
local con = tango.client.socket.connect{
   address = 'localhost',
   port = 12345
}
-- call the remote greeting function
con.greet('Hello','Horst')
```

Access anything?
----------------

Since the server exposes the global table `_G` per default, the client may even
directly call `print`,let the server sleep a bit remotely
(`os.execute`) or calc some stuff (`math.sqrt`).

```lua
-- variable argument count is supported
con.print('I','call','print','myself')
-- any function or variable in the server's _G can be accessed by default        
con.os.execute('sleep 1')
con.math.sqrt(4)
```

One can limit the server exposed functions by specifying a `functab`
like this (to expose only methods of he math table/module):

```lua
local tango = require'tango'
-- just pass a table to the functab to limit the access to this table
tango.server.copas_socket.loop{
  port = 12345,
  functab = math
}
```

As the global table `_G` is not available any more, the client can
only call methods from the math module:

```lua
con.sqrt(4)
```

Remote Variables
-----------------

Sometimes you need to get some data from the server, as
enumaration-like-constants for instance. Instead of creating a mess of
remote getters and setters, just treat the value of interest as a
function...

Let's read the remote table friends from the server

```lua
local tango = require'tango'
-- connect to server as usual
local con = tango.client.socket.connect()
-- friends is a remote table but could be of any other type
local friends = con.friends()
```

To change the servers state, just pass the new value as
argument:

```lua
local tango = require'tango'
local con = tango.client.socket.connect()
-- read the remote variable
local friends = con.friends()
-- modify it 
table.insert(friends,'Horst')
-- and write back the new value
client.friends(friends)
```

If you are worried about security concerns, just do not allow
read and/or write access:

```lua
local tango = require'tango'
-- write_access and read_access can be set independently
-- accessing variables from the client side will now cause errors.
tango.server.copas_socket.loop{
  write_access = false,
  read_access = false
}
```

Using classes/tables/objects remotely (tango.ref)
-----------------------------------------

Even if Lua does not come with a class model, semi-object-oriented
programming is broadly used via the semicolon operator, e.g.:

```lua
-- assume you open a pipe locally
local p = io.popen('ls')
-- and read some stuff from it, ... note the : operator
local line = p:read('*l')
...
p:close()
```

To allow such construct remotely via tango, one has to use the
`tango.ref`:

```lua
local con = tango.client.socket.connect()
-- pass in the remote function and all arguments required (optionally)
local p = tango.ref(con.io.popen,'ls')
-- now proceed as if p was a local object
local line = p:read('*l')
...
p:close()
-- unref it locally to let the server release it
tango.unref(p)
```

This may seem a bit awkward, but it is certainly less hassle, then
writing non-object-oriented counterparts on the server side.


Tests
=====

You can run test by the following sh call in the *project root*
directory:

      ./test.lua

tango does not need to be installed.

Client/Server compatibilities
-----------------------------

<table border="1">               
        <tr>
                <th></th><th>tango.client.socket</th><th>tango.client.zmq</th>
        </tr>
        <tr>
                <th>tango.server.copas_socket</th><th>X</th><th></th>
        </tr>
        <tr>
                <th>tango.server.ev_socket</th><th>X</th><th></th>
        </tr>
        <tr>
                <th>tango.server.zmq</th><th></th><th>X</th>
        </tr>
</table>


Serialization
-------------
tango provides a default (lua-only) table serialization which should
meet most common use cases.

Anyhow, the table serialization is neither exceedingly fast nor
compact in output or memory consumption. If this is a problem for your application, you can
customize the serialization by assigning your serialize/unserialize
methods to the clients and servers respectively.

Socket client with customized serialization:

```lua
local tango = require'tango'
local cjson = require'cjson'
-- set serialization on the client side
local con = tango.client.socket.connect{
   serialize = cjson.encode,
   unserialize = cjson.decode
}
```

Copas socket server with customized serialization:

```lua
local tango = require'tango'
local cjson = require'cjson'
-- set serialization on the server side
tango.server.copas_socket.loop{
   serialize = cjson.encode,
   unserialize = cjson.decode
}
```

Some alternatives are:

* [lua-marshal](https://github.com/richardhundt/lua-marshal)
* [lua-cjson](http://www.kyne.com.au/~mark/software/lua-cjson.php)
* [luabins](https://github.com/agladysh/luabins)
* [luatexts](https://github.com/agladysh/luatexts)

Requirements
------------

The requirements depend on the desired i/o backend, see the
corresponding [rockspecs](https://github.com/lipp/tango/tree/master/rockspecs) for details.


Installation
-------------
With LuaRocks:
Directly from the its repository:

     $ sudo luarocks install tango-copas
    
or tango-complete, which requires lua-zmq and lua-ev (and the
corresponding C-libs:

     $ sudo luarocks install tango-complete

or a specific rock from 

     $ sudo luarocks install https://raw.github.com/lipp/tango/master/rockspecs/SPECIFIC_ROCKSPEC

Note: [luarocks](http://www.luarocks.org) must be >= 2.0.4.1 and requires luasec for doing https requests!

     $ sudo apt-get install libssl-dev
     $ sudo luarocks install luasec
