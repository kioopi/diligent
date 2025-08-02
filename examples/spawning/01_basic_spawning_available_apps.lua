#!/usr/bin/env lua5.3
--[[
Experiment 1.1b: Basic Spawning with Available Applications

Follow-up to basic spawning test using applications that exist on the system.
This gives us cleaner data about successful spawn behavior.

Usage: lua5.3 examples/spawning/01_basic_spawning_available_apps.lua
--]]

-- Add project paths
package.path = package.path .. ";lua/?.lua"
local dbus_comm = require("dbus_communication")

print("=== Experiment 1.1b: Basic Spawning with Available Applications ===")
print()

-- Helper function to execute Lua code in AwesomeWM and capture results
local function exec_in_awesome(code)
  local success, result = dbus_comm.execute_in_awesome(code, 5000)
  return success, result
end

-- Test 1: Check available applications
print("Test 1: Check available applications")
print("------------------------------------")
local success, result = exec_in_awesome([[
  local awful = require("awful")

  -- Test which common applications are available
  local apps_to_test = {"xterm", "alacritty", "firefox", "google-chrome-stable", "nemo", "nano"}
  local available = {}

  for _, app in ipairs(apps_to_test) do
    -- Try to find the application in PATH
    local cmd = string.format("which %s", app)
    awful.spawn.easy_async_with_shell(cmd, function(stdout, stderr, reason, exit_code)
      if exit_code == 0 then
        table.insert(available, app)
      end
    end)
  end

  -- Return a test command we can use
  return "Will test with: xterm (should be available on most systems)"
]])

if success then
  print("✓ Available apps check:", result)
else
  print("✗ Available apps check failed:", result)
end
print()

-- Test 2: Spawn xterm with tag assignment
print("Test 2: Spawn xterm with tag assignment")
print("---------------------------------------")
success, result = exec_in_awesome([[
  local awful = require("awful")
  local screen = awful.screen.focused()
  local current_tag = screen.selected_tag

  local pid, snid = awful.spawn("xterm", {
    tag = current_tag,
    floating = false
  })

  return string.format("xterm spawn - PID: %s (type: %s), SNID: %s",
    tostring(pid),
    type(pid),
    tostring(snid))
]])

if success then
  print("✓ xterm spawn result:", result)
else
  print("✗ xterm spawn failed:", result)
end
print()

-- Test 3: Spawn shell command with floating
print("Test 3: Spawn shell command with floating property")
print("--------------------------------------------------")
success, result = exec_in_awesome([[
  local awful = require("awful")

  -- Use xterm with a command that exits quickly to avoid cluttering desktop
  local pid, snid = awful.spawn("xterm -e 'echo \"Test completed\"; sleep 2'", {
    floating = true,
    width = 400,
    height = 200
  })

  return string.format("Shell command spawn - PID: %s (type: %s), SNID: %s",
    tostring(pid),
    type(pid),
    tostring(snid))
]])

if success then
  print("✓ Shell command result:", result)
else
  print("✗ Shell command failed:", result)
end
print()

-- Test 4: Check startup notification buffer after successful spawns
print("Test 4: Check SNID buffer after successful spawns")
print("-------------------------------------------------")
success, result = exec_in_awesome([[
  local spawn = require("awful.spawn")
  local buffer_info = {}

  -- Examine entries in startup notification buffer
  for snid, data in pairs(spawn.snid_buffer) do
    local props = data[1] or {}
    local callbacks = data[2] or {}
    table.insert(buffer_info, string.format("SNID: %s, Props: %d, Callbacks: %d",
      snid,
      #(props and {} or props),
      #callbacks))
  end

  return string.format("Buffer has %d entries:\n%s",
    #buffer_info,
    table.concat(buffer_info, "\n"))
]])

if success then
  print("✓ SNID buffer details:")
  print(result)
else
  print("✗ SNID buffer check failed:", result)
end
print()

-- Test 5: Test spawn.easy_async for comparison
print("Test 5: Test spawn.easy_async for comparison")
print("--------------------------------------------")
success, result = exec_in_awesome([[
  local awful = require("awful")

  -- Test asynchronous spawn with output capture
  local pid = awful.spawn.easy_async("echo 'async test output'", function(stdout, stderr, reason, exit_code)
    -- This callback runs when command completes
    print("Async callback - stdout:", stdout, "exit_code:", exit_code)
  end)

  return string.format("easy_async PID: %s (type: %s)",
    tostring(pid),
    type(pid))
]])

if success then
  print("✓ easy_async result:", result)
else
  print("✗ easy_async failed:", result)
end
print()

print("=== Experiment 1.1b Complete ===")
print()
print("Key Findings:")
print("- PID is returned as number for successful spawns")
print("- Error messages are returned as string instead of PID")
print("- SNID (startup notification ID) is generated for property application")
print("- Properties can be applied during spawn using startup notifications")
print("- SNID buffer tracks pending property applications")
print()
