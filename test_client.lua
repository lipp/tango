-- sample client 
require'tango'

-- connects to server (on default port 12345)
local client = tango.client('localhost')

-- call print_table on the server side with
-- some table content
client.print_table{number=444,name='horst'}

-- call print_table on the server side with
-- wrong argument type (non table)
ok,err = pcall(function()client.print_table(1)end)

-- and assert error
assert(ok==false and err:find('type_error'))
