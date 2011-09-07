package = 'tango-zmq'
version = '0.2-1'
source = {
   url = 'git://github.com/lipp/tango.git',
   tag = '0.2-1'
}
description = {
   summary = 'Remote procedure calls (RPC) for Lua.',
   homepage = 'http://github.com/lipp/tango',
   license = 'MIT/X11'
}
dependencies = {
   'lua >= 5.1',
   'lua-zmq >= 1.0'
}
build = {
   type = 'builtin',
   modules = {
      ['tango'] = 'tango.lua',
      ['tango.proxy'] = 'tango/proxy.lua',
      ['tango.dispatcher'] = 'tango/dispatcher.lua',
      ['tango.config'] = 'tango/config.lua',
      ['tango.utils.serialization'] = 'tango/utils/serialization.lua',
      ['tango.client.zmq'] = 'tango/client/zmq.lua',
      ['tango.server.zmq'] = 'tango/server/zmq.lua'
   }
}
