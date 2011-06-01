require'tango'

local connect = function()
                  return tango.client('localhost',12345,{calltimeout=0.01})
                end

local test = function(txt,f)
               io.write(txt..' ... ')
               local ret = f()
               if ret and ret ~= false  then
                 io.write('ok\n')
               else
                 io.write('failed\n')
               end
             end

local client = connect()

test('echo test',
     function()
       local tab = {number=444,name='horst',bool=true}
       local tab2 = client.echo(tab)
       return tab.number==tab2.number and tab.name==tab2.name and tab.bool==tab2.bool
     end)

test('add test',
     function()
       return client.add(1,2)==3
     end)

test('string error test',
     function()
       local status,msg = pcall(function()client.strerror('testmessage')end)
       return status==false and msg:find('testmessage')
     end)

test('multiple return values',
     function()
       local a,b,c = 1.234,true,{el=11}
       local a2,b2,c2 = client.multi(a,b,c)
       return a==a2 and b==b2 and c.el==c2.el
     end)

test('timeout test',
     function()
       local status,msg = pcall(function()client.msleep(100)end)
       return status==false and msg:find('timeout')
     end)

-- 'resync' with server (server maybe still sleeping!!!)
io.popen('sleep 0.1'):read()
-- connection errors and timeouts require a 'reconnect'
local client = connect()

test('timeout with tango.pcall',
     function()
       local status,msg,tangoerr = tango.pcall(function()client.msleep(100) end)        
       return status==false and tangoerr and tangoerr.code==tango.calltimeout_error and tangoerr.path=='msleep'
     end)

-- 'resync' with server (server maybe still sleeping!!!)
io.popen('sleep 0.1'):read()
-- connection errors and timeouts require a 'reconnect'
local client = connect()

test('pcall test',
     function()
       local status,msg,tangoerr = pcall(function()client.strerror('test')end)
       return status==false and msg:find('test') and tangoerr==nil
     end)

test('add test',
     function()
       return client.add(1,2)==3
     end)

test('custom error test',
     function()
       local errtab = {code=117}
       local status,errtab2 = pcall(function()client.customerror(errtab)end)
       return status==false and errtab2.code==errtab.code
     end)

test('nested method name test',
     function()
       return client.nested.method.name()==true
     end)

test('not existing proxy paths',
     function()
       local status,msg = pcall(function()client.notexisting()end) 
       return status==false and msg:find('notexisting') and msg:find('path')
     end)

test('not existing proxy path with tango.pcall',
     function()
       local status,msg,tangoerr = tango.pcall(function()client.notexisting() end) 
       return status==false and tangoerr.code==tango.path_error and tangoerr.path=='notexisting'
     end)
