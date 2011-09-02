#!/usr/bin/lua
local spawn_server = 
   function(backend)
      local cmd = [[
            lua test_server.lua >test_server.log %s &
            echo $!            
      ]]
      cmd = cmd:format(backend)
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
   function(backend)
      os.execute('lua test_client.lua '..backend)
   end


local run_test = 
   function(server_backend, client_backend)
      print('==============================')
      print('running tests with:')
      print('server backend:',server_backend)
      print('client backend:',client_backend)
      print('------------------------------')
      local pid = spawn_server(server_backend)
      run_client_test(client_backend)
      kill_server(pid)
      print()
   end

run_test('copas_socket','socket')
run_test('ev_socket','socket')
run_test('zmq','zmq')


