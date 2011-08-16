local socket = require'socket'
local ev = require'ev'
local default_loop = ev.Loop.default
local send_message = require'tango.utils.socket_message'.send
local receive_message = require'tango.utils.socket_message'.receive
local serialize = require'tango.utils.serialization'.serialize
local unserialize = require'tango.utils.serialization'.unserialize
local dispatch = require'tango.dispatch'
local pcall = pcall
local print = print

-- to access outer function in the proxy remote call (__call)
local globals = _G

--- A copas compatible transport backend for tango.
-- It requires LuaSocket and Copas.
module('tango.server.ev_socket')

new = 
  function(port,functab)  
    local server = socket.bind("*", port or 12345)
    return ev.IO.new(
      function(loop)        
        local client = server:accept()
        local response_str
        local send_response = ev.IO.new(
          function(loop, send_response)
             local ok,err = pcall(
                function()
                   send_response:stop(loop)                  
                   send_message(client,response_str)
                end)
             if not ok then
                print(err)
             end
          end,
          client:getfd(),
          ev.WRITE)
        
        ev.IO.new(
          function(loop, receive_request)
            receive_request:stop(loop)
            local ok,err = pcall(
               function()
                  local request_str = receive_message(client)
                  local request = unserialize(request_str)
                  local response = dispatch(request,functab or globals,pcall)
                  response_str = serialize(response)
                  send_response:start(loop)              
                  receive_request:start(loop)   
               end)
            if not ok then
               print(err)
            end
          end,
          client:getfd(),
          ev.READ):start(loop)
      end,
      server:getfd(),
      ev.READ)
  end

loop = function(port,functab)
          new(port,functab):start(default_loop)
          default_loop:loop()
       end



