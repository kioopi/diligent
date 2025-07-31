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

-- Initialize LGI components
local function init_lgi()
  local lgi = require("lgi")
  local GLib = lgi.require("GLib")
  local Gio = lgi.require("Gio")

  return lgi, GLib, Gio
end

-- Get D-Bus connection (cached)
local connection = nil
local function get_dbus_connection()
  if not connection then
    local _, _, Gio = init_lgi()
    connection = Gio.bus_get_sync(Gio.BusType.SESSION, nil)
  end
  return connection
end

-- Execute Lua code in AwesomeWM via D-Bus
function dbus_comm.execute_in_awesome(lua_code, timeout_ms)
  timeout_ms = timeout_ms or 5000

  local success, err_or_result = pcall(function()
    local _, GLib, Gio = init_lgi()
    local conn = get_dbus_connection()

    if not conn then
      error("Failed to connect to D-Bus session bus")
    end

    local variant = conn:call_sync(
      "org.awesomewm.awful", -- destination
      "/", -- object path
      "org.awesomewm.awful.Remote", -- interface
      "Eval", -- method
      GLib.Variant("(s)", { lua_code }), -- arguments
      nil, -- reply type
      Gio.DBusCallFlags.NONE, -- flags
      timeout_ms, -- timeout
      nil -- cancellable
    )

    if variant then
      local result_value = variant:get_child_value(0)

      -- Try each type in order, silently catching errors
      local success_inner, value

      -- Try string first (most common)
      success_inner, value = pcall(function()
        return result_value:get_string()
      end)
      if success_inner then
        return value
      end

      -- Try double (numbers)
      success_inner, value = pcall(function()
        local num = result_value:get_double()
        -- Format as integer if it's a whole number
        if num == math.floor(num) then
          return tostring(math.floor(num))
        else
          return tostring(num)
        end
      end)
      if success_inner then
        return value
      end

      -- Try int32
      success_inner, value = pcall(function()
        return tostring(result_value:get_int32())
      end)
      if success_inner then
        return value
      end

      -- Try boolean
      success_inner, value = pcall(function()
        return tostring(result_value:get_boolean())
      end)
      if success_inner then
        return value
      end

      return "unknown_type"
    else
      error("No response from AwesomeWM")
    end
  end)

  if success then
    return true, err_or_result
  else
    return false, "D-Bus error: " .. tostring(err_or_result)
  end
end

-- Send a command to AwesomeWM via D-Bus (compatible with cli_communication.lua interface)
function dbus_comm.send_command(command, payload)
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

  return dbus_comm.execute_in_awesome(lua_code)
end

-- Check if AwesomeWM is available via D-Bus
function dbus_comm.check_awesome_available()
  local success, result =
    dbus_comm.execute_in_awesome('return "available"', 1000)
  local is_available = success and result == "available"
  return is_available
end

-- Send ping command and wait for response from AwesomeWM
function dbus_comm.send_ping(payload)
  -- execute_fn parameter is ignored (for compatibility)
  -- timeout_seconds is ignored (D-Bus has its own timeout)

  -- Create Lua code that handles ping directly and returns JSON response
  local lua_code = string.format(
    [[
    local dkjson = require('dkjson')

    -- Create ping response directly (matching diligent.lua format)
    local response = {
      status = "success",
      message = "pong",
      timestamp = os.date("!%%Y-%%m-%%dT%%H:%%M:%%SZ"),
      received_timestamp = %q
    }

    return dkjson.encode(response)
  ]],
    payload.timestamp or ""
  )

  -- Execute via D-Bus and get immediate response
  return dbus_comm.execute_in_awesome(lua_code)
end

-- Parse JSON response from AwesomeWM (same as cli_communication.lua)
function dbus_comm.parse_response(response)
  local json_utils = require("json_utils")

  return json_utils.decode(response)
end

return dbus_comm
