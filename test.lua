#!/usr/bin/lua
local spawn_server = 
   function(backend,access_str)
      local cmd = [[
            lua test_server.lua >test_server.log %s %s &
            echo $!            
      ]]
      cmd = cmd:format(backend,access_str)
      local process = io.popen(cmd)
      local pid = process:read()
      if backend ~= 'zmq' then
         os.execute('sleep 0.2')
      end
      return pid
   end

local kill_server =
   function(pid)
      os.execute('kill '..pid)
   end

local run_client_test = 
   function(backend,access_str)
      os.execute('lua test_client.lua '..backend..' '..access_str)
   end


local run_test = 
   function(server_backend, client_backend)
      print('==============================')
      print('running tests with:')
      print('server backend:',server_backend)
      print('client backend:',client_backend)
      print('------------------------------')
      for _,access in ipairs{'rw','r','w'} do 
        print('access: ',access)
        local pid = spawn_server(server_backend,access)
        run_client_test(client_backend,access)
        kill_server(pid)
      end
      print()
   end

run_test('copas_socket','socket')
run_test('ev_socket','socket')
run_test('zmq','zmq')


