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

Client/Server compatibilities:

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

        local cjson = require'cjson'
        local connect = require'tango.client.socket'.connect
        local client = connect{
              serialize=cjson.encode,
              unserialize=cjson.decode}

Copas socket server with customized serialization:

        local cjson = require'cjson'
        local server = require'tango.server.copas_socket'
        server.loop{
              serialize=cjson.encode,
              unserialize=cjson.decode}

Some alternatives are:

* [lua-marshal](https://github.com/richardhundt/lua-marshal)
* [lua-cjson](http://www.kyne.com.au/~mark/software/lua-cjson.php)

Requirements
------------

The requirements depend on the desired i/o backend, see the
corresponding rockspecs for details

  * ...


Installation
-------------
With LuaRocks > 2.0.4.1:

     $ sudo luarocks install https://raw.github.com/lipp/tango/multi-backend/rockspecs/tango-0.1-1.rockspec

Note: luarocks require luasec for doing https requests.

     $ sudo luarocks install luasec
