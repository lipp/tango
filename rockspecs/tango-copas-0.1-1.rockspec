package = 'tango-copas'
version = '0.1-1'
source = {
   url = 'git://github.com/lipp/tango.git',
   branch = 'master'
}
description = {
   summary = 'Remote procedure calls (RPC) for Lua.',
   homepage = 'http://github.com/lipp/tango',
   license = 'MIT/X11'
}
dependencies = {
   'lua >= 5.1',
   'luasocket >= 2.0.2',
   'copas >= 1.1.6'
}
build = {
   type = 'builtin',
   modules = {
      ['tango.proxy'] = 'tango/proxy.lua',
      ['tango.dispatch'] = 'tango/dispatch.lua',
      ['tango.utils.serialization'] = 'tango/utils/serialization.lua',
      ['tango.utils.socket_message'] = 'tango/utils/socket_message.lua',
      ['tango.client.socket'] = 'tango/client/socket.lua',
      ['tango.server.copas_socket'] = 'tango/server/copas_socket.lua'
   }
}
