--[[
D-Bus Communication Layer for Diligent

This module handles direct D-Bus communication between the Diligent CLI
and the AwesomeWM window manager using LGI (Lua GObject Introspection).

This replaces the shell-based awesome-client approach with direct D-Bus calls,
eliminating shell escaping issues and providing more reliable communication.

Responsibilities:
- Direct D-Bus communication with AwesomeWM via org.awesomewm.awful.Remote
- Execute Lua code in AwesomeWM and return results
- Handle communication errors gracefully
- Provide the same interface as cli_communication.lua for easy replacement

The communication protocol:
- Uses D-Bus method call: org.awesomewm.awful.Remote.Eval
- Sends Lua code as strings
- Receives typed responses back via D-Bus
--]]

local dbus_comm = {}
local dbus_core = require("dbus_core")

-- Execute Lua code in AwesomeWM via D-Bus (compatibility wrapper)
function dbus_comm.execute_in_awesome(lua_code, timeout_ms)
  return dbus_core.execute_lua_code(lua_code, timeout_ms)
end

-- Send a command to AwesomeWM via D-Bus
function dbus_comm.emit_command(command, payload)
  local json_utils = require("json_utils")

  -- Encode payload as JSON
  local status, json_payload = json_utils.encode(payload)
  if not status then
    return false, json_payload
  end

  -- Create Lua code to emit signal
  local lua_code = string.format(
    'awesome.emit_signal("diligent::%s", %s); return "signal sent"',
    command,
    string.format("%q", json_payload)
  )

  return dbus_core.execute_lua_code(lua_code)
end

-- Send a command to AwesomeWM via D-Bus
function dbus_comm.dispatch_command(command, payload)
  local json_utils = require("json_utils")

  -- Encode payload as JSON
  local status, json_payload = json_utils.encode(payload)
  if not status then
    return json_payload
  end

  -- Create Lua code to emit signal
  local lua_code = string.format(
    'return require("diligent").dispatch_json("diligent::%s", %s)',
    command,
    string.format("%q", json_payload)
  )

  local success, json = dbus_core.execute_lua_code(lua_code)

  if not success then
    return false,
      {
        status = "error",
        message = "Failed to execute command in AwesomeWM",
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      }
  end

  local parsed, result_or_error = json_utils.decode(json)

  if not parsed then
    return false,
      {
        status = "error",
        message = "Failed to parse response: " .. tostring(result_or_error),
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      }
  end

  return true, result_or_error
end

-- Check if AwesomeWM is available via D-Bus
function dbus_comm.check_awesome_available()
  local success, result = dbus_core.execute_lua_code('return "available"', 1000)
  local is_available = success and result == "available"
  return is_available
end

-- Parse JSON response from AwesomeWM (same as cli_communication.lua)
function dbus_comm.parse_response(response)
  local json_utils = require("json_utils")

  return json_utils.decode(response)
end

return dbus_comm
