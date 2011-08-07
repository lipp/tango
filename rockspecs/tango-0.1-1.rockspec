package = 'tango'
version = '0.1-1'
source = {
   url = 'git://github.com/lipp/tango.git',
   branch = 'multi-backend'
}
description = {
   summary = 'Remote procedure calls for Lua.',
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
      ['tango'] = 'tango.lua',
      ['tango.serialization'] = 'tango/serialization.lua',
      ['tango.copas'] = 'tango/copas.lua',
      ['tango.zmq'] = 'tango/zmq.lua',
      ['tango.ev'] = 'tango/ev.lua',
      ['tango.socket'] = 'tango/socket.lua'      
   }
}
