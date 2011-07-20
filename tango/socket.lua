local socket = require'socket'
-- private helpers
local tonumber = tonumber
local tostring = tostring
local error = error
local tango = require'tango'

--- Contains methods to send and receive arbitrary (binary) messages and a standard socket client.
-- It requires LuaSocket.
module('tango.socket')

--- Sends a message (string) with arbitrary (binary) content.
-- Receive this message with @see receive_message.
send_message = 
  function(socket,message,on_error)
    -- send length of the string as ascii line
    local sent,err = socket:send(tostring(#message)..'\n')
    if not sent then                                                            
      if on_error then
        return on_error(err)
      end
      error(err)
    end
    -- send the actual message data
    sent,err = socket:send(message)
    if not sent then
      if on_error then
        return on_error(err)
      end
      error(err)
    end
  end

--- Receives a message (string) with arbitrary (binary) content.
receive_message = 
  function(socket,on_error)
    local responselen,err = socket:receive('*l')                         
    if not responselen then
      if on_error then
        return on_error(err)
      end
      error(err)
    end                         
    -- convert ascii len to number of bytes
    responselen = tonumber(responselen)
    if not responselen then
      local err = 'length as ascii number string expected'
      if on_error then
        return on_error(err)
      end
      error(err)
    end                       
    -- receive the actual response table dataa
    local response,err = socket:receive(responselen)
    if not response then
      if on_error then
        return on_error(err)
      end
      error(err)
    end            
    return response
  end

--- Returns a call proxy to the specified client.
-- Invoke remote functions on the returned variable.
-- @usage c = tango.connect('localhost'); c.greet('horst')
-- it is also possible to functions inside tables, like
-- @usage c.utils.greetall()
-- @return a proxy to the server global table
-- @param adr A string, which represents the server address, may be server name e.g. www.horst.de
-- @param port A number, which specifies the port on which the server listens (default 12345)
-- @param timeout A number in milliseconds, which define timeouts for all socket operations (default 5000)
-- involved using the proxy (connect,send,receive)
-- @param call A function which performs the actual call. Can be either tango.call or tango.notify (default tango.call).
client = 
  function(adr,port,timeout,call)
    local sock = socket.tcp()
    sock:settimeout(timeout or 5000)
    sock:setoption('tcp-nodelay',true)
    local connected,err = sock:connect(adr or 'localhost',port or 12345)
    if not connected then
      return error(err)
    end

    local close_and_throw = 
      function(err)
        sock:shutdown()
        sock:close()
        error(err)
      end

    local transport = {
      socket = sock,
      send_message = 
        function(data)
          send_message(sock,data,close_and_throw)
        end,
      receive_message = 
        function()
          return receive_message(sock,close_and_throw)
        end
    }
    return tango.proxy(transport,call or tango.call)
  end
