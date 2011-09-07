package = 'tango-copas'
version = '0.1-1'
source = {
   url = 'git://github.com/lipp/tango.git',
tag='0.1'
--    url = 'http://githubredir.debian.net/github/lipp/tango/0.1.tar.gz',
--url = 'https://github.com/downloads/lipp/tango/tango-0.1.tar.gz'
--   url = 'https://nodeload.github.com/lipp/tango/tarball/0.1',
--   file = '0.1.tar.gz',
--   dir = '0.1'
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
      ['tango'] = 'tango.lua',
      ['tango.proxy'] = 'tango/proxy.lua',
      ['tango.dispatch'] = 'tango/dispatch.lua',
      ['tango.utils.serialization'] = 'tango/utils/serialization.lua',
      ['tango.utils.socket_message'] = 'tango/utils/socket_message.lua',
      ['tango.client.socket'] = 'tango/client/socket.lua',
      ['tango.server.copas_socket'] = 'tango/server/copas_socket.lua'
   }
}
