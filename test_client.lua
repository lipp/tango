require'tango'

-- connects to server (on default port 12345)
local client = tango.client('localhost',12345,{calltimeout=1})

print('echo test')
local tab = {number=444,name='horst',bool=true}
local tab2 = client.echo(tab)
assert(tab.number==tab2.number and tab.name==tab2.name and tab.bool==tab2.bool)

print('add test')
assert(client.add(1,2)==3)

print('string error test')
local status,msg = pcall(function()client.strerror('test')end)
assert(status==false and msg:find('test'))

print('multiple return values')
local a,b,c = 1.234,true,{el=11}
local a2,b2,c2 = client.multi(a,b,c)
assert(a==a2 and b==b2 and c.el==c2.el)

print('timeout test')
local status,msg = pcall(function()client.sleep(2)end)
assert(status==false and msg:find('timeout'))

print('timeout with tango.pcall')
local status,msg,tangoerr = tango.pcall(function()client.sleep(2) end) 
assert(status==false and tangoerr.type=='timeout' and tangoerr.code==tango.calltimeout_error and tangoerr.path=='sleep')

-- connection errors and timeouts require a 'reconnect'
local client = tango.client('localhost',12345) 
print('pcall test')
local status,msg,tangoerr = pcall(function()client.strerror('test')end)
assert(status==false and msg:find('test') and tangoerr==nil)

print('add test')
assert(client.add(1,2)==3)

print('custom error test')
local errtab = {code=117}
local status,errtab2 = pcall(function()client.customerror(errtab)end)
assert(status==false and errtab2.code==errtab.code)

print('nested method name test')
assert(client.nested.method.name()==true)

print('not existing proxy paths')
local status,msg = pcall(function()client.notexisting()end)
assert(status==false and msg:find('notexisting') and msg:find('path'))

print('not existing proxy path with tango.pcall')
local status,msg,tangoerr = tango.pcall(function()client.notexisting() end) 
assert(status==false and tangoerr.type=='server' and 
       tangoerr.code==tango.path_error and tangoerr.path=='notexisting')
