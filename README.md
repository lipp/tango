About
=======

tango is a small, simple and customizable RPC (remote procedure call)
module for Lua.

Its main features are:

* a generic transparent
  [proxy](https://github.com/lipp/tango/tree/0.2.1/tango/proxy.lua)
  for call invocations
* support of remote objects (tables with functions, userdata etc, see tango.ref)
* a generic [dispatch](https://github.com/lipp/tango/tree/0.2.1/tango/dispatch.lua) routine for servers
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
require'tango.server.copas_socket'
greet = function(...)
          print(...)
        end         
tango.server.copas_socket.loop{
  port = 12345
}
```

The client code calling the remote server function `greet`
      
```lua
require'tango.client.socket'
local proxy = tango.client.socket.connect{
   address = 'localhost',
   port = 12345
}
proxy.greet('Hello','Horst')
```

Access anything?
----------------

Since the server exposes the global table `_G` per default, the client may even
directly call `print`,let the server sleep a bit remotely
(`os.execute`) or calc some stuff (`math.sqrt`).

```lua
proxy.print('I','call','print','myself')         
proxy.os.execute('sleep 1')
proxy.math.sqrt(4)
```

One can limit the server exposed functions by specifying a `functab`
like this (to expose only methods of he math table/module):

```lua
require'tango.server.copas_socket'
tango.server.copas_socket.loop{
  port = 12345,
  functab = math
}
```

As the global table `_G` is not available any more, the client can
only call methods from the math module:

```lua
proxy.sqrt(4)
```

Remote Variables
-----------------

Sometimes you need to get some data from the server, as
enumaration-like-constants for instance. Instead of creating a mess of
remote getters and setters, just treat the value of interest as a
function...

Let's read the remote table friends from the server

```lua
local client = require'tango.client.socket'.connect()
local friends = client.friends()
```

To change the servers state, just pass the new value as
argument:

```lua
local client = require'tango.client.socket'.connect()
local friends = client.friends()
table.insert(friends,'Horst')
client.friends(friends)
```

If you are worried about security concerns, just do not allow
read and/or write access:

```lua
require'tango.server.copas_socket'
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
local p = io.popen('ls')
local line = p:read('*l')
...
p:close()
```

To allow such construct remotely via tango, one has to use the
`tango.ref`:

```lua
local client = require'tango.client.socket'.connect()
local p = tango.ref(client.io.popen,'ls')
local line = p:read('*l')
...
p:close()
tango.unref(p)
```

This may seem a bit awkward, but it is certainly less hassle, then
writing non-object-oriented counterparts on the server side.


Tests
=====

You can run test by the following sh call in the project root directory

      ./test.lua

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
local cjson = require'cjson'
local connect = require'tango.client.socket'.connect
local client = connect{
   serialize = cjson.encode,
   unserialize = cjson.decode
}
```

Copas socket server with customized serialization:

```lua
local cjson = require'cjson'
local server = require'tango.server.copas_socket'
server.loop{
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
corresponding [rockspecs](https://github.com/lipp/tango/tree/0.2/rockspecs) for details.


Installation
-------------
With LuaRocks > 2.0.4.1:

     $ sudo luarocks install https://raw.github.com/lipp/tango/0.2.1/rockspecs/tango-complete-0.2-1.rockspec

The complete package requires lua-zmq and lua-ev. If you don't plan to
use one of them just stick to the copas variant:
  
     $ sudo luarocks install https://raw.github.com/lipp/tango/0.2.1/rockspecs/tango-copas-0.2-1.rockspec

Note: luarocks require luasec for doing https requests.

     $ sudo luarocks install luasec
