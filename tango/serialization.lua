-- private helpers
local tinsert = table.insert
local tconcat = table.concat
local tremove = table.remove
local smatch = string.match
local sgmatch = string.gmatch
local sgsub = string.gsub
local ipairs = ipairs
local pairs = pairs
local type = type
local tostring = tostring
local tonumber = tonumber
local loadstring = loadstring
local print = print

--- The default tango serialization module.
-- Neither fast nor compact, but Lua only.
-- It is based on the table serialization at http://lua/users.org/wiki/TableUtils
module('tango.serialization')

-- private helper for serialize
-- converts a value to a string, used by @see tango.serialize
-- copied from 
local valtostr = 
  function(v)
    local vtype = type(v)
    if 'string' == vtype then
      v = sgsub(v,"\n","\\n")
      if smatch(sgsub(v,"[^'\"]",""),'^"+$') then
        return "'"..v.."'"
      end
      return '"'..sgsub(v,'"','\\"')..'"'
    else
      return 'table' == vtype and serialize(v) or tostring(v)
    end
  end

-- private helper for serialize
-- converts a key to a string, used by @see tango.serialize
-- copied from http://lua/users.org/wiki/TableUtils
local keytostr = 
  function(k)
    if 'string' == type(k) and smatch(k,"^[_%a][_%a%d]*$") then
      return k
    else
      return '['..valtostr(k)..']'
    end
  end

--- Default table serializer.
-- Implementation copied from http://lua/users.org/wiki/TableUtils.
-- May be overwritten for custom serialization (function must take a table and return a string).
-- @param tbl the table to be serialized
-- @return the serialized table as string
-- @usage tango.serialize = table.marshal (using lua-marshal as serializer)
serialize = 
  function(tbl)
    local result,done = {},{}
    for k,v in ipairs(tbl) do
      tinsert(result,valtostr(v))
      done[k] = true
    end
    for k,v in pairs(tbl) do
      if not done[k] then
        tinsert(result,keytostr(k)..'='..valtostr(v))
      end
    end
    return '{'..tconcat(result,',')..'}'
  end

--- Default table unserializer.
-- May be overwritten with custom serialization.
-- Unserializer must take a string as argument and return a table.
-- @param strtbl the serialized table as string
-- @return the unserialized table
-- @usage tango.unserialize = table.unmarshal (using lua-marshal as serializer)
unserialize = 
  function(strtab)
    -- assuming strtab contains a stringified table
    return loadstring('return '..strtab)()
  end

