#!/usr/bin/lua
local run_client_test = 
   function(server_backend,client_backend)
     os.execute('lua test_client.lua '..server_backend..' '..client_backend)
   end

run_client_test('copas_socket','socket')
run_client_test('ev_socket','socket')
run_client_test('zmq','zmq')



