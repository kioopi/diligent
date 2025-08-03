#!/usr/bin/env lua5.3
--[[
Experiment 1.1: Basic Spawning with Properties

This experiment tests the fundamental awful.spawn() behavior with property application.
We want to understand:
1. How to spawn clients with tag assignment
2. Whether startup notifications work reliably
3. Basic property application (floating, placement, etc.)
4. Return value patterns (PID, SNID)

Usage: lua5.3 examples/spawning/01_basic_spawning.lua
--]]

-- Add project paths
package.path = package.path .. ";lua/?.lua"
local dbus_comm = require("dbus_communication")

print("=== Experiment 1.1: Basic Spawning with Properties ===")
print()

-- Helper function to execute Lua code in AwesomeWM and capture results
local function exec_in_awesome(code)
  local success, result = dbus_comm.execute_in_awesome(code, 5000)
  return success, result
end

-- Test 1: Basic spawn without properties
print("Test 1: Basic spawn without properties")
print("--------------------------------------")
local success, result = exec_in_awesome([[
  local awful = require("awful")
  local pid, snid = awful.spawn("echo 'hello from basic spawn'")
  return string.format("PID: %s, SNID: %s", tostring(pid), tostring(snid))
]])

if success then
  print("✓ Basic spawn result:", result)
else
  print("✗ Basic spawn failed:", result)
end
print()

-- Test 2: Get current tag information
print("Test 2: Get current tag information")
print("-----------------------------------")
success, result = exec_in_awesome([[
  local awful = require("awful")
  local screen = awful.screen.focused()
  local tag = screen.selected_tag
  return string.format("Screen: %s, Current tag: %s (index: %d)",
    tostring(screen.index),
    tostring(tag.name or "unnamed"),
    tag.index)
]])

if success then
  print("✓ Current tag info:", result)
else
  print("✗ Failed to get tag info:", result)
end
print()

-- Test 3: Spawn with tag assignment (current tag)
print("Test 3: Spawn with tag assignment to current tag")
print("------------------------------------------------")
success, result = exec_in_awesome([[
  local awful = require("awful")
  local screen = awful.screen.focused()
  local current_tag = screen.selected_tag

  local pid, snid = awful.spawn("nemo", {
    tag = current_tag,
    floating = false
  })

  return string.format("Spawn to current tag - PID: %s, SNID: %s, Tag: %s",
    tostring(pid),
    tostring(snid),
    tostring(current_tag.name or current_tag.index))
]])

if success then
  print("✓ Tag assignment result:", result)
else
  print("✗ Tag assignment failed:", result)
end
print()

-- Test 4: Spawn with floating property
print("Test 4: Spawn with floating property")
print("------------------------------------")
success, result = exec_in_awesome([[
  local awful = require("awful")
  local pid, snid = awful.spawn("xcalc", {
    floating = true,
    placement = awful.placement.top_left
  })

  return string.format("Floating spawn - PID: %s, SNID: %s",
    tostring(pid),
    tostring(snid))
]])

if success then
  print("✓ Floating spawn result:", result)
else
  print("✗ Floating spawn failed:", result)
end
print()

-- Test 5: Spawn to specific tag by index
print("Test 5: Spawn to specific tag by index")
print("--------------------------------------")
success, result = exec_in_awesome([[
  local awful = require("awful")
  local screen = awful.screen.focused()
  local tags = screen.tags

  -- Try to spawn to tag 2 if it exists
  if #tags >= 2 then
    local target_tag = tags[2]
    local pid, snid = awful.spawn("gedit", {
      tag = target_tag
    })
    return string.format("Spawn to tag 2 - PID: %s, SNID: %s, Tag: %s",
      tostring(pid),
      tostring(snid),
      tostring(target_tag.name or target_tag.index))
  else
    return "Cannot test - screen has less than 2 tags"
  end
]])

if success then
  print("✓ Specific tag spawn result:", result)
else
  print("✗ Specific tag spawn failed:", result)
end
print()

-- Test 6: Error handling - invalid command
print("Test 6: Error handling - invalid command")
print("----------------------------------------")
success, result = exec_in_awesome([[
  local awful = require("awful")
  local pid, snid = awful.spawn("this_command_does_not_exist_12345")

  return string.format("Invalid command - PID: %s (type: %s), SNID: %s",
    tostring(pid),
    type(pid),
    tostring(snid))
]])

if success then
  print("✓ Error handling result:", result)
else
  print("✗ Error handling test failed:", result)
end
print()

-- Test 7: Check startup notification buffer
print("Test 7: Check startup notification buffer")
print("-----------------------------------------")
success, result = exec_in_awesome([[
  local spawn = require("awful.spawn")
  local buffer_count = 0

  -- Count entries in startup notification buffer
  for snid, data in pairs(spawn.snid_buffer) do
    buffer_count = buffer_count + 1
  end

  return string.format("SNID buffer contains %d entries", buffer_count)
]])

if success then
  print("✓ SNID buffer check:", result)
else
  print("✗ SNID buffer check failed:", result)
end
print()

print("=== Experiment 1.1 Complete ===")
print()
print("Summary:")
print("- Test basic spawn patterns and return values")
print("- Verify tag assignment works with properties")
print("- Check floating and placement properties")
print("- Validate error handling for invalid commands")
print("- Examine startup notification infrastructure")
print()
print("Next: Review results and update exploration document")
