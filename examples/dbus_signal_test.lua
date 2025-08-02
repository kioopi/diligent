#!/usr/bin/env lua5.3
--[[
D-Bus Signal Communication Test

This example demonstrates sending signals to AwesomeWM via D-Bus
and verifying they are received properly.

Usage: lua5.3 examples/dbus_signal_test.lua
--]]

local lgi = require("lgi")
local GLib = lgi.require("GLib")
local Gio = lgi.require("Gio")

print("Testing D-Bus signal communication...")

local success, result = pcall(function()
  local connection = Gio.bus_get_sync(Gio.BusType.SESSION, nil)

  -- Test emitting a signal to AwesomeWM
  local test_file = "/tmp/dbus_signal_test_" .. os.time()
  local lua_code = string.format(
    [[
    -- Set up signal handler
    awesome.connect_signal('diligent::dbus_test', function(data)
      local f = io.open('%s', 'w')
      f:write('D-Bus signal received: ' .. data)
      f:close()
    end)
    
    -- Emit the signal
    awesome.emit_signal('diligent::dbus_test', 'Hello via D-Bus signal!')
    
    return 'Signal sent'
  ]],
    test_file
  )

  local variant = connection:call_sync(
    "org.awesomewm.awful",
    "/",
    "org.awesomewm.awful.Remote",
    "Eval",
    GLib.Variant("(s)", { lua_code }),
    nil,
    Gio.DBusCallFlags.NONE,
    5000,
    nil
  )

  if variant then
    local response = variant:get_child_value(0):get_string()
    print("AwesomeWM response:", response)

    -- Wait a moment for file to be created
    os.execute("sleep 0.5")

    -- Check if signal was received
    local file = io.open(test_file, "r")
    if file then
      local content = file:read("*a")
      file:close()
      os.remove(test_file)
      print("Signal result:", content)
      return true
    else
      print("Signal test file not created")
      return false
    end
  else
    print("No response from AwesomeWM")
    return false
  end
end)

if success then
  print("✓ D-Bus signal test: SUCCESS")
  os.exit(0)
else
  print("✗ D-Bus signal test: FAILED -", result)
  os.exit(1)
end
