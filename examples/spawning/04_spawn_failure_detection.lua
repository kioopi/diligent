#!/usr/bin/env lua
--[[
Experiment 4.1: Spawn Failure Detection

This experiment tests comprehensive error handling and failure detection for awful.spawn().
We want to understand:
1. How different types of spawn failures are detected
2. What error patterns are returned for various failure modes  
3. Whether zombie processes are created on failure
4. How quickly errors are detected
5. Resource exhaustion behavior

Usage: lua examples/spawning/04_spawn_failure_detection.lua
--]]

-- Add project paths
package.path = package.path .. ";lua/?.lua"
local dbus_comm = require("dbus_communication")

print("=== Experiment 4.1: Spawn Failure Detection ===")
print()

-- Helper function to execute Lua code in AwesomeWM and capture results
local function exec_in_awesome(code)
  local success, result = dbus_comm.execute_in_awesome(code, 10000)
  return success, result
end

-- Helper function to time execution
local function time_execution(func)
  local start_time = os.clock()
  local success, result = func()
  local end_time = os.clock()
  local duration = (end_time - start_time) * 1000 -- Convert to milliseconds
  return success, result, duration
end

-- Initialize awe module
print("Loading awe module...")
local success, result = exec_in_awesome([[
  -- Clear all awe-related modules from cache to ensure fresh load from local path
  for k, v in pairs(package.loaded) do
    if k:match("^awe") then
      package.loaded[k] = nil
    end
  end
  
  -- Set package path to prioritize local project version
  package.path = "/home/vt/projects/diligent/lua/?.lua;" .. package.path
  
  -- Load the awe module
  local success, awe = pcall(require, "awe")
  if not success then
    return "ERROR: Failed to load awe module: " .. tostring(awe)
  end
  
  -- Store reference globally for easy access
  _G.diligent_awe = awe
  
  return "SUCCESS: awe module loaded"
]])

if not success or result:match("^ERROR:") then
  print("✗ Failed to initialize awe module:", result)
  os.exit(1)
end

print("✓ awe module initialized")
print()

-- Test 1: Non-existent Command
print("Test 1: Non-existent Command")
print("-----------------------------")
local success, result, duration = time_execution(function()
  return exec_in_awesome([[
    local awful = require("awful")
    local pid, snid = awful.spawn("invalidapp123doesnotexist")
    
    return string.format("PID: %s (type: %s), SNID: %s, Duration: immediate",
      tostring(pid), type(pid), tostring(snid))
  ]])
end)

if success then
  print("✓ Non-existent command result:", result)
  print(string.format("  Execution time: %.2f ms", duration))
else
  print("✗ Non-existent command test failed:", result)
end
print()

-- Test 2: Command with Invalid Arguments
print("Test 2: Command with Invalid Arguments")
print("--------------------------------------")
success, result, duration = time_execution(function()
  return exec_in_awesome([[
    local awful = require("awful")
    local pid, snid = awful.spawn("ls --invalid-flag-that-does-not-exist")
    
    return string.format("PID: %s (type: %s), SNID: %s",
      tostring(pid), type(pid), tostring(snid))
  ]])
end)

if success then
  print("✓ Invalid arguments result:", result)
  print(string.format("  Execution time: %.2f ms", duration))
else
  print("✗ Invalid arguments test failed:", result)
end
print()

-- Test 3: Permission Denied Scenario
print("Test 3: Permission Denied Scenario")
print("----------------------------------")
success, result, duration = time_execution(function()
  return exec_in_awesome([[
    local awful = require("awful")
    -- Try to execute a file that doesn't have execute permissions
    local pid, snid = awful.spawn("/etc/passwd")
    
    return string.format("PID: %s (type: %s), SNID: %s",
      tostring(pid), type(pid), tostring(snid))
  ]])
end)

if success then
  print("✓ Permission denied result:", result)
  print(string.format("  Execution time: %.2f ms", duration))
else
  print("✗ Permission denied test failed:", result)
end
print()

-- Test 4: Empty Command
print("Test 4: Empty Command")
print("--------------------")
success, result, duration = time_execution(function()
  return exec_in_awesome([[
    local awful = require("awful")
    local pid, snid = awful.spawn("")
    
    return string.format("PID: %s (type: %s), SNID: %s",
      tostring(pid), type(pid), tostring(snid))
  ]])
end)

if success then
  print("✓ Empty command result:", result)
  print(string.format("  Execution time: %.2f ms", duration))
else
  print("✗ Empty command test failed:", result)
end
print()

-- Test 5: Command with Spaces/Special Characters
print("Test 5: Command with Problematic Characters")
print("-------------------------------------------")
success, result, duration = time_execution(function()
  return exec_in_awesome([[
    local awful = require("awful")
    -- Test command with special characters that might cause parsing issues
    local pid, snid = awful.spawn("app with spaces && invalid")
    
    return string.format("PID: %s (type: %s), SNID: %s",
      tostring(pid), type(pid), tostring(snid))
  ]])
end)

if success then
  print("✓ Special characters result:", result)
  print(string.format("  Execution time: %.2f ms", duration))
else
  print("✗ Special characters test failed:", result)
end
print()

-- Test 6: Multiple Failure Pattern Analysis
print("Test 6: Error Pattern Analysis")
print("------------------------------")
local error_patterns = {}
local test_commands = {
  "nonexistent_app_12345",
  "ls --invalid-flag",
  "/bin/false", -- Exists but exits with error
  "",
  "app with spaces",
  "cat /dev/urandom | head", -- Complex pipe that might behave unexpectedly
}

for i, cmd in ipairs(test_commands) do
  local success, result = exec_in_awesome(string.format(
    [[
    local awful = require("awful")
    local pid, snid = awful.spawn("%s")
    
    if type(pid) == "string" then
      return "ERROR: " .. pid
    else
      return "SUCCESS: PID " .. tostring(pid)
    end
  ]],
    cmd:gsub('"', '\\"')
  ))

  if success then
    table.insert(error_patterns, { command = cmd, result = result })
    print(string.format("  Command %d: %s", i, result))
  else
    print(string.format("  Command %d failed: %s", i, result))
  end
end
print()

-- Test 7: Process Cleanup Verification
print("Test 7: Process Cleanup Verification")
print("------------------------------------")
success, result = exec_in_awesome([[
  -- Count running processes before failed spawns
  local handle = io.popen("ps aux | wc -l")
  local before_count = tonumber(handle:read("*a"))
  handle:close()
  
  -- Attempt multiple failing spawns
  local awful = require("awful")
  for i = 1, 5 do
    awful.spawn("invalidapp" .. i)
  end
  
  -- Wait a moment for any cleanup
  os.execute("sleep 1")
  
  -- Count processes after
  handle = io.popen("ps aux | wc -l")
  local after_count = tonumber(handle:read("*a"))
  handle:close()
  
  return string.format("Processes before: %d, after: %d, difference: %d",
    before_count, after_count, after_count - before_count)
]])

if success then
  print("✓ Process cleanup check:", result)
else
  print("✗ Process cleanup check failed:", result)
end
print()

-- Test 8: Using awe module for Error Detection
print("Test 8: awe Module Error Detection")
print("----------------------------------")
success, result, duration = time_execution(function()
  return exec_in_awesome([[
    local awe = _G.diligent_awe
    local pid, snid, msg = awe.spawn.spawner.spawn_with_properties("nonexistentapp999", "0", {})
    
    return string.format("awe Result - PID: %s, SNID: %s, Message: %s",
      tostring(pid), tostring(snid), msg)
  ]])
end)

if success then
  print("✓ awe module error detection:", result)
  print(string.format("  Execution time: %.2f ms", duration))
else
  print("✗ awe module error detection failed:", result)
end
print()

-- Test 9: Error Message Content Analysis
print("Test 9: Error Message Content Analysis")
print("--------------------------------------")
success, result = exec_in_awesome([[
  local awful = require("awful")
  local errors = {}
  
  local test_cases = {
    {cmd = "nonexistent123", desc = "nonexistent binary"},
    {cmd = "/etc/passwd", desc = "non-executable file"},
    {cmd = "", desc = "empty command"},
    {cmd = "ls /nonexistent/path", desc = "valid binary, invalid args"}
  }
  
  for _, test in ipairs(test_cases) do
    local pid, snid = awful.spawn(test.cmd)
    if type(pid) == "string" then
      table.insert(errors, {
        test = test.desc,
        error = pid,
        length = string.len(pid)
      })
    end
  end
  
  local report = {}
  for _, err in ipairs(errors) do
    table.insert(report, string.format("%s: %d chars - %s", 
      err.test, err.length, err.error:sub(1, 60)))
  end
  
  return table.concat(report, "\n  ")
]])

if success then
  print("✓ Error message analysis:")
  print("  " .. result)
else
  print("✗ Error message analysis failed:", result)
end
print()

-- Test 10: Resource Exhaustion Simulation
print("Test 10: Resource Exhaustion Simulation")
print("---------------------------------------")
success, result = exec_in_awesome([[
  local awful = require("awful")
  local spawn_attempts = 0
  local successful_spawns = 0
  local failed_spawns = 0
  
  -- Try to spawn many valid but short-lived processes
  for i = 1, 20 do
    local pid, snid = awful.spawn("echo 'test " .. i .. "'")
    spawn_attempts = spawn_attempts + 1
    
    if type(pid) == "number" then
      successful_spawns = successful_spawns + 1
    else
      failed_spawns = failed_spawns + 1
    end
  end
  
  return string.format("Attempts: %d, Successful: %d, Failed: %d",
    spawn_attempts, successful_spawns, failed_spawns)
]])

if success then
  print("✓ Resource exhaustion test:", result)
else
  print("✗ Resource exhaustion test failed:", result)
end
print()

print("=== Experiment 4.1 Complete ===")
print()
print("Summary of Findings:")
print("- Error detection patterns and timing")
print("- Process cleanup behavior")
print("- Error message content and structure")
print("- Resource exhaustion handling")
print("- Integration with awe module")
print()

-- Generate summary report
print("=== ERROR PATTERN SUMMARY ===")
if #error_patterns > 0 then
  for _, pattern in ipairs(error_patterns) do
    local status = pattern.result:match("^ERROR:") and "FAILED" or "SUCCEEDED"
    print(string.format("%-30s: %s", pattern.command, status))
  end
else
  print("No error patterns captured")
end
print()

print("Next Steps:")
print("1. Analyze error detection speed (should be < 100ms)")
print("2. Verify no zombie processes from failed spawns")
print("3. Document error message patterns for user feedback")
print("4. Update awe module with improved error handling")
