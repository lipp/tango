local socket = require'socket'
local ev = require"ev"
local default_loop = ev.Loop.default
local core = require'tango'

-- private helpers
local tonumber = tonumber
local tostring = tostring
local pcall = pcall
local error = error
local print = print

-- to access outer function in the proxy remote call (__call)
local globals = _G

--- A copas compatible transport backend for tango.
-- It requires LuaSocket and Copas.
module('tango.ev')

--- Sends a string with arbitrary (binary) content.
local send = 
  function(socket,str)
    -- send length of the string as ascii line
    local sent,err = socket:send(tostring(#str)..'\n')
    if not sent then                                                      
      socket:shutdown()
      socket:close()
      error(err)
    end
    -- send the actual string data
    sent,err = socket:send(str)
    if not sent then
      socket:shutdown()
      socket:close()
      error(err)
    end
  end

--- Receives a string with arbitrary (binary) content.
local receive = 
  function(socket)
    local responselen,err = socket:receive('*l')                         
    if not responselen then
      socket:shutdown()
      socket:close()
      error(err)
    end                         
    -- convert ascii len to number of bytes
    responselen = tonumber(responselen)
    if not responselen then
      socket:shutdown()
      socket:close()
      error('length as ascii number string not ok')
    end                       
    -- receive the actual response table dataa
    local response,err = socket:receive(responselen)
    if not response then
      socket:shutdown()
      socket:close()
      error(err)
    end            
    return response
  end

server = 
  function(port,functab)  
    local server = socket.bind("*", port or 12345)
    return ev.IO.new(
      function(loop)        
        local client = server:accept()
        print(client:getpeername())
        local response
        local send_response = ev.IO.new(
          function(loop, send_response)
            send_response:stop(loop)                  
            send(client,response)
          end,
          client:getfd(),
          ev.WRITE)
        
        ev.IO.new(
          function(loop, receive_request)
            receive_request:stop(loop)
            local request = receive(client)
            response = core.dispatch(request,functab or globals,pcall)
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
          loop(port,functab):start(default_loop)
          default_loop:loop()
        end



