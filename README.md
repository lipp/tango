About
=======

tango is small, simple and customizable RPC (remote procedure call)
module for Lua.

Its main features are:

* a generic transparent [proxy](https://github.com/lipp/tango/blob/multi-backend/tango/proxy.lua) for call invocations
* a generic [dispatch](https://github.com/lipp/tango/blob/multi-backend/tango/dispatch.lua) routine for servers
* several server implementations for different protocols, message formats and event/io
frameworks, further called backends
* several client implementations for different protocols and message formats


Backends included
---------------------

* copas  
* [lua-zmq](https://github.com/Neopallium/lua-zmq)
* [lua-ev](https://github.com/brimworks/lua-ev)

Example (with copas backend)
--------------------------------
The greet server code 

      require'tango.server.copas_socket'
      greet = function(...)
                print(...)
              end         
      tango.server.copas_socket.loop()


The client code calling the remote server function 'greet'

      require'tango.client.socket'
      local proxy = tango.client.socket('localhost')
      proxy.greet('Hello','Horst')

Since the server exposes the global table _G per default, the client may even
directly call print and let the server sleep a bit remotely.

      proxy.print('I','call','print','myself')         
      proxy.os.execute('sleep 1')

Tests
------

You can run test by the following sh call in the project root directory

      ./test.lua


Serialization
-------------
tango provides a default (lua-only) table serialization which works.

Anyhow, the table serialization is neither exceedingly fast nor
compact in output. If this is a problem for your application, you can
customize the serialization by overwriting ... TODO

([lua-marshal](https://github.com/richardhundt/lua-marshal))

Requirements
------------

Either of the supported event/io backends. If your backend is
currently not supported, just write your own :)

The most common socket/io combination might be luasocket+copas.

To install use apt

      $ sudo apt-get install liblua5.1-socket2
      $ sudo apt-get install liblua5.1-copas0


or LuaRocks

      $ sudo luarocks install luasocket
      $ sudo luarocks install copas

Installation
-------------
With LuaRocks > 2.0.4.1:

     $ sudo luarocks install https://raw.github.com/lipp/tango/multi-backend/tango-0.1-0.rockspec

Note: luarocks require lua-sec for doing https requests.
Install with apt

     $ sudo apt-get install liblua5.1-sec1

or LuaRocks

     $ sudo luarocks install luasec
