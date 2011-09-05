package = 'tango-ev'
version = '0.1-1'
source = {
   url = 'git://github.com/lipp/tango.git',
   branch = 'develop'
}
description = {
   summary = 'Remote procedure calls (RPC) for Lua.',
   homepage = 'http://github.com/lipp/tango',
   license = 'MIT/X11'
}
dependencies = {
   'lua >= 5.1',
   'luasocket >= 2.0.2',
   'lua-ev'
}
build = {
   type = 'builtin',
   modules = {
      ['tango'] = 'tango.lua',
      ['tango.proxy'] = 'tango/proxy.lua',
      ['tango.dispatcher'] = 'tango/dispatcher.lua',
      ['tango.utils.serialization'] = 'tango/utils/serialization.lua',
      ['tango.utils.socket_message'] = 'tango/utils/socket_message.lua',
      ['tango.client.socket'] = 'tango/client/socket.lua',
      ['tango.server.ev_socket'] = 'tango/server/ev_socket.lua'
   }
}
