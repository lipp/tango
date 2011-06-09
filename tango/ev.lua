local socket = require'socket'
local ev = require"ev"
local default_loop = ev.Loop.default
local send_message = require'tango.socket'.send_message
local receive_message = require'tango.socket'.receive_message
local default_client = require'tango.socket'.client
local dispatch = require'tango'.dispatch
local pcall = pcall
local print = print

-- to access outer function in the proxy remote call (__call)
local globals = _G

--- A copas compatible transport backend for tango.
-- It requires LuaSocket and Copas.
module('tango.ev')

client = default_client

server = 
  function(port,functab)  
    local server = socket.bind("*", port or 12345)
    return ev.IO.new(
      function(loop)        
        local client = server:accept()
        local response
        local send_response = ev.IO.new(
          function(loop, send_response)
            send_response:stop(loop)                  
            send_message(client,response)
          end,
          client:getfd(),
          ev.WRITE)
        
        ev.IO.new(
          function(loop, receive_request)
            receive_request:stop(loop)
            local request = receive_message(client)
            response = dispatch(request,functab or globals,pcall)
            if response then
              send_response:start(loop)
            end            
            receive_request:start(loop)          
          end,
          client:getfd(),
          ev.READ):start(loop)
      end,
      server:getfd(),
      ev.READ)
  end

serve = function(port,functab)
          server(port,functab):start(default_loop)
          default_loop:loop()
        end



