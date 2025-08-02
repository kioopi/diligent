#!/usr/bin/env lua5.3
--[[
D-Bus Diligent Communication Test

This example demonstrates the full diligent ping/pong communication
using D-Bus instead of awesome-client.

Usage: lua5.3 examples/dbus_diligent_test.lua
--]]

local lgi = require("lgi")
local GLib = lgi.require("GLib")
local Gio = lgi.require("Gio")

-- Add diligent path if needed
package.path = package.path .. ";/home/vt/.luarocks/share/lua/5.3/?.lua"
local json_utils = require("json_utils")

print("Testing diligent ping via D-Bus...")

local success, result = pcall(function()
  local connection = Gio.bus_get_sync(Gio.BusType.SESSION, nil)

  -- Create ping payload
  local payload = {
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    source = "dbus-test",
    response_file = "/tmp/dbus_diligent_test_" .. os.time(),
  }

  -- Create Lua code to emit diligent ping signal
  local encode_success, payload_json = json_utils.encode(payload)
  if not encode_success then
    error("Failed to encode payload: " .. payload_json)
  end

  local lua_code = string.format(
    [[
    local payload_json = '%s'
    awesome.emit_signal('diligent::ping', payload_json)
    return 'Ping signal sent'
  ]],
    payload_json:gsub("'", "\\'")
  )

  print("Sending ping signal via D-Bus...")
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
    print("Signal sent response:", response)

    -- Wait for response file
    local timeout = 5
    local start_time = os.time()

    while os.time() - start_time < timeout do
      local file = io.open(payload.response_file, "r")
      if file then
        local content = file:read("*a")
        file:close()
        os.remove(payload.response_file)

        print("Response received:", content)

        -- Parse JSON response
        local decode_success, response_data = json_utils.decode(content)
        if not decode_success then
          print("✗ Failed to decode response:", response_data)
          return false
        end
        if
          response_data
          and response_data.status == "success"
          and response_data.message == "pong"
        then
          print("✓ Ping/Pong successful!")
          return true
        else
          print("✗ Invalid response format")
          return false
        end
      end
      os.execute("sleep 0.1")
    end

    print("✗ Timeout waiting for response")
    return false
  else
    print("✗ No response from AwesomeWM")
    return false
  end
end)

if success then
  print("✓ D-Bus diligent ping test: SUCCESS")
  os.exit(0)
else
  print("✗ D-Bus diligent ping test: FAILED -", result)
  os.exit(1)
end
