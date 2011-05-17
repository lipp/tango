require'tango'

-- connects to server (on default port 12345)
local client = tango.client('localhost',12345,{calltimeout=1})

-- echo test
local tab = {number=444,name='horst',bool=true}
local tab2 = client.echo(tab)
assert(tab.number==tab2.number and tab.name==tab2.name and tab.bool==tab2.bool)

-- add test
assert(client.add(1,2)==3)

-- string error test
local status,msg = pcall(function()client.strerror('test')end)
assert(status==false and msg:find('test'))

-- multiple return values
local a,b,c = 1.234,true,{el=11}
local a2,b2,c2 = client.multi(a,b,c)
assert(a==a2 and b==b2 and c.el==c2.el)

-- timeout
local status,msg = pcall(function()client.sleep(2)end)
assert(status==false and msg:find('timeout'))

-- timeout with tango.pcall
local status,msg,tangoerr = tango.pcall(function()client.sleep(2) end) 
assert(status==false and tangoerr.source=='socket' and tangoerr.value=='timeout')

local client = tango.client('localhost',12345) 
-- pcall
local status,msg,tangoerr = pcall(function()client.strerror('test')end)
assert(status==false and msg:find('test') and tangoerr==nil)

-- add test
assert(client.add(1,2)==3)

local errtab = {code=117}
local status,errtab2 = pcall(function()client.customerror(errtab)end)
assert(status==false and errtab2.code==errtab.code)
