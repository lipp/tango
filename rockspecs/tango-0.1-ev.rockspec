package = 'tango'
version = '0.1-ev'
source = {
   url = 'git://github.com/lipp/tango.git',
   branch = 'multi-backend'
}
description = {
   summary = 'Remote procedure calls for Lua (ev backend).',
   homepage = 'http://github.com/lipp/tango',
   license = 'MIT/X11'
}
dependencies = {
   'lua >= 5.1',
   'luasocket >= 2.0.2',
   'lua-ev >= 1.2'
}
build = {
   type = 'builtin',
   modules = {
      ['tango'] = 'tango.lua',
      ['tango.serialization'] = 'tango/serialization.lua',
      ['tango.ev'] = 'tango/ev.lua',
      ['tango.socket'] = 'tango/socket.lua'      
   }
}
