#!/usr/bin/env lua5.3
--[[
D-Bus Basic Communication Test

This example demonstrates basic D-Bus communication with AwesomeWM
using LGI (Lua GObject Introspection).

Usage: lua5.3 examples/dbus_basic_test.lua
--]]

local lgi = require("lgi")
local GLib = lgi.require("GLib")
local Gio = lgi.require("Gio")

print("Testing basic D-Bus communication to AwesomeWM...")

local success, result = pcall(function()
  -- Connect to session bus
  local connection = Gio.bus_get_sync(Gio.BusType.SESSION, nil)
  print("Connected to session bus:", connection ~= nil)

  -- Test calling AwesomeWM via D-Bus
  local lua_code = 'return "Hello from D-Bus!"'
  local variant = connection:call_sync(
    "org.awesomewm.awful", -- destination
    "/", -- object path
    "org.awesomewm.awful.Remote", -- interface
    "Eval", -- method
    GLib.Variant("(s)", { lua_code }), -- arguments
    nil, -- reply type
    Gio.DBusCallFlags.NONE, -- flags
    5000, -- timeout (5 seconds)
    nil -- cancellable
  )

  if variant then
    local result_value = variant:get_child_value(0)
    local result_str = result_value:get_string()
    print("AwesomeWM response:", result_str)
    return true
  else
    print("No response from AwesomeWM")
    return false
  end
end)

if success then
  print("✓ D-Bus communication test: SUCCESS")
  os.exit(0)
else
  print("✗ D-Bus communication test: FAILED -", result)
  os.exit(1)
end
