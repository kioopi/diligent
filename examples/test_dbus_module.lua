#!/usr/bin/env lua5.3
--[[
Test the new dbus_communication.lua module
--]]

local dbus_comm = require("dbus_communication")

print("Testing dbus_communication module...")
print()

-- Test 1: Check AwesomeWM availability
print("1. Testing AwesomeWM availability...")
local available = dbus_comm.check_awesome_available()
print("   Available:", available)
print()

if not available then
  print("AwesomeWM not available via D-Bus. Make sure AwesomeWM is running.")
  os.exit(1)
end

-- Test 2: Execute simple command
print("2. Testing simple command execution...")
local success, result = dbus_comm.execute_in_awesome('return "test successful"')
print("   Success:", success)
print("   Result:", result)
print()

-- Test 3: Send signal
print("3. Testing signal sending...")
local signal_success, signal_result =
  dbus_comm.emit_command("test", { message = "hello from dbus" })
print("   Success:", signal_success)
print("   Result:", signal_result)
print()

-- Test 4: Ping test (if diligent is loaded)
print("4. Testing ping (requires diligent loaded in AwesomeWM)...")
local ping_payload = {
  timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  source = "dbus-test",
}

local ping_success, ping_response = dbus_comm.send_ping(ping_payload, nil, 3)
print("   Success:", ping_success)
if ping_success then
  print("   Response:", ping_response)

  -- Parse response
  local parse_success, data = dbus_comm.parse_response(ping_response)
  if parse_success then
    print("   Parsed status:", data.status)
    print("   Parsed message:", data.message)
  end
else
  print("   Error:", ping_response)
  print("   (This is expected if diligent module is not loaded in AwesomeWM)")
end

print()
print("✓ D-Bus module testing complete")
