package = 'tango-complete'
version = '0.1.1-1'
source = {
   url = 'git://github.com/lipp/tango.git',
   branch = '0.1.1'
}
description = {
   summary = 'Remote procedure calls (RPC) for Lua.',
   homepage = 'http://github.com/lipp/tango',
   license = 'MIT/X11'
}
dependencies = {
   'lua >= 5.1',
   'luasocket >= 2.0.2',
   'copas >= 1.1.6',
   'lua-ev',
   'lua-zmq >= 1.0'
}
build = {
   type = 'builtin',
   modules = {
      ['tango.proxy'] = 'tango/proxy.lua',
      ['tango.dispatch'] = 'tango/dispatch.lua',
      ['tango.utils.serialization'] = 'tango/utils/serialization.lua',
      ['tango.utils.socket_message'] = 'tango/utils/socket_message.lua',
      ['tango.client.socket'] = 'tango/client/socket.lua',
      ['tango.client.zmq'] = 'tango/client/zmq.lua',
      ['tango.server.copas_socket'] = 'tango/server/copas_socket.lua',
      ['tango.server.ev_socket'] = 'tango/server/ev_socket.lua',
      ['tango.server.zmq'] = 'tango/server/zmq.lua'
   }
}
