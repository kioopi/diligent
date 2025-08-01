--[[
D-Bus Core Communication Module

This module provides low-level D-Bus communication primitives for communicating
with AwesomeWM via the org.awesomewm.awful.Remote interface.

Responsibilities:
- Initialize LGI (Lua GObject Introspection) components
- Manage D-Bus session bus connections (with caching)
- Parse D-Bus variant responses into Lua values
- Execute Lua code remotely in AwesomeWM via D-Bus calls
- Handle D-Bus communication errors gracefully

This module is focused purely on the D-Bus protocol layer and does not
handle higher-level command semantics or JSON encoding/decoding.
--]]

local dbus_core = {}

-- Cached D-Bus connection
local connection = nil

-- Initialize LGI components
function dbus_core.init_lgi()
  local lgi = require("lgi")
  local GLib = lgi.require("GLib")
  local Gio = lgi.require("Gio")

  return lgi, GLib, Gio
end

-- Get D-Bus connection (cached)
function dbus_core.get_dbus_connection()
  if not connection then
    local _, _, Gio = dbus_core.init_lgi()
    connection = Gio.bus_get_sync(Gio.BusType.SESSION, nil)
  end
  return connection
end

-- Reset connection cache (for testing purposes)
function dbus_core._reset_connection_cache()
  connection = nil
end

-- Helper functions for parsing different variant types
local function try_parse_as_string(result_value)
  local success, value = pcall(function()
    return result_value:get_string()
  end)
  return success, value
end

local function try_parse_as_number(result_value)
  local success, value = pcall(function()
    local num = result_value:get_double()
    -- Format as integer if it's a whole number
    if num == math.floor(num) then
      return tostring(math.floor(num))
    else
      return tostring(num)
    end
  end)
  return success, value
end

local function try_parse_as_integer(result_value)
  local success, value = pcall(function()
    return tostring(result_value:get_int32())
  end)
  return success, value
end

local function try_parse_as_boolean(result_value)
  local success, value = pcall(function()
    return tostring(result_value:get_boolean())
  end)
  return success, value
end

-- Parse D-Bus variant response into a string representation
function dbus_core.parse_variant_value(result_value)
  if not result_value then
    return "no return value"
  end

  -- Try each type in order, returning the first successful parse

  -- Try string first (most common)
  local success, value = try_parse_as_string(result_value)
  if success then
    return value
  end

  -- Try double (numbers)
  success, value = try_parse_as_number(result_value)
  if success then
    return value
  end

  -- Try int32
  success, value = try_parse_as_integer(result_value)
  if success then
    return value
  end

  -- Try boolean
  success, value = try_parse_as_boolean(result_value)
  if success then
    return value
  end

  return "unknown_type"
end

-- Execute Lua code in AwesomeWM via D-Bus
function dbus_core.execute_lua_code(lua_code, timeout_ms)
  timeout_ms = timeout_ms or 5000

  local success, err_or_result = pcall(function()
    local _, GLib, Gio = dbus_core.init_lgi()
    local conn = dbus_core.get_dbus_connection()

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
      return dbus_core.parse_variant_value(result_value)
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

return dbus_core
