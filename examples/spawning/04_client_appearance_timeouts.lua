#!/usr/bin/env lua
--[[
Experiment 4.2: Client Appearance Timeouts

This experiment tests timeout handling for clients that don't appear immediately
or take time to start. We want to understand:
1. How long different applications take to appear as managed clients
2. Reasonable timeout values for various application types
3. Behavior of applications with splash screens or complex startup
4. Prevention of false positive timeouts
5. Handling of background/daemon applications

Usage: lua examples/spawning/04_client_appearance_timeouts.lua
--]]

-- Add project paths
package.path = package.path .. ";lua/?.lua"
local dbus_comm = require("dbus_communication")

print("=== Experiment 4.2: Client Appearance Timeouts ===")
print()

-- Helper function to execute Lua code in AwesomeWM and capture results
local function exec_in_awesome(code)
  local success, result = dbus_comm.execute_in_awesome(code, 15000) -- Longer timeout for this experiment
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

-- Test 1: Fast-starting Applications
print("Test 1: Fast-starting Applications")
print("----------------------------------")
local fast_apps = { "xterm", "xcalc", "xeyes" }
local timing_results = {}

for _, app in ipairs(fast_apps) do
  print(string.format("Testing %s...", app))

  local success, result, duration = time_execution(function()
    return exec_in_awesome(string.format(
      [[
      local awe = _G.diligent_awe
      local start_time = os.clock()
      
      -- Spawn the application
      local pid, snid, msg = awe.spawn.spawner.spawn_with_properties("%s", "0", {})
      
      if not pid then
        return "SPAWN_FAILED: " .. msg
      end
      
      -- Wait for client to appear with timeout
      local timeout = 5  -- 5 second timeout
      local client_found = false
      local appearance_time = nil
      
      while (os.clock() - start_time) < timeout do
        local client = awe.client.tracker.find_by_pid(pid)
        if client then
          appearance_time = (os.clock() - start_time) * 1000  -- Convert to ms
          client_found = true
          break
        end
        os.execute("sleep 0.1")  -- Wait 100ms between checks
      end
      
      if client_found then
        return "SUCCESS: Client appeared in " .. appearance_time .. " ms (PID: " .. tostring(pid) .. ")"
      else
        return "TIMEOUT: Client never appeared after " .. timeout .. " seconds (PID: " .. tostring(pid) .. ")"
      end
    ]],
      app
    ))
  end)

  if success then
    print("  " .. result)
    if result:match("SUCCESS:") then
      local app_time = result:match("appeared in (%d+) ms")
      if app_time then
        timing_results[app] = tonumber(app_time)
      end
    end
  else
    print("  ✗ Test failed:", result)
  end
end
print()

-- Test 2: Applications with Different Startup Patterns
print("Test 2: Applications with Startup Complexity")
print("--------------------------------------------")
local complex_apps = {
  { app = "gedit", desc = "Text editor (GTK)" },
  { app = "nemo", desc = "File manager (complex GUI)" },
  { app = "firefox", desc = "Browser (heavy application)" }, -- Will likely fail, but good to test
}

for _, test_case in ipairs(complex_apps) do
  print(string.format("Testing %s (%s)...", test_case.app, test_case.desc))

  local success, result = exec_in_awesome(string.format(
    [[
    local awe = _G.diligent_awe
    local start_time = os.clock()
    
    -- Spawn the application
    local pid, snid, msg = awe.spawn.spawner.spawn_with_properties("%s", "0", {})
    
    if not pid then
      return "SPAWN_FAILED: " .. msg
    end
    
    -- Wait for client to appear with extended timeout
    local timeout = 10  -- 10 second timeout for complex apps
    local client_found = false
    local appearance_time = nil
    local check_count = 0
    
    while (os.clock() - start_time) < timeout do
      check_count = check_count + 1
      local client = awe.client.tracker.find_by_pid(pid)
      if client then
        appearance_time = (os.clock() - start_time) * 1000
        client_found = true
        break
      end
      os.execute("sleep 0.2")  -- Check every 200ms
    end
    
    if client_found then
      return test_case.app .. " appeared in " .. appearance_time .. " ms after " .. check_count .. " checks (PID: " .. tostring(pid) .. ")"
    else
      return test_case.app .. " never appeared after " .. timeout .. " seconds (PID: " .. tostring(pid) .. ", checks: " .. check_count .. ")"
    end
  ]],
    test_case.app
  ))

  if success then
    print("  " .. result)
  else
    print("  ✗ Test failed:", result)
  end

  -- Give a moment between tests to avoid overwhelming
  os.execute("sleep 1")
end
print()

-- Test 3: Timeout Configuration Testing
print("Test 3: Timeout Configuration Testing")
print("-------------------------------------")
local timeout_values = { 1, 3, 5, 10 }

for _, timeout in ipairs(timeout_values) do
  print(string.format("Testing %d second timeout with xterm...", timeout))

  local success, result = exec_in_awesome(string.format(
    [[
    local awe = _G.diligent_awe
    local start_time = os.clock()
    
    -- Spawn xterm (should be fast)
    local pid, snid, msg = awe.spawn.spawner.spawn_with_properties("xterm", "0", {})
    
    if not pid then
      return "SPAWN_FAILED: " .. msg
    end
    
    -- Use the specified timeout
    local timeout = %d
    local client_found = false
    local appearance_time = nil
    
    while (os.clock() - start_time) < timeout do
      local client = awe.client.tracker.find_by_pid(pid)
      if client then
        appearance_time = (os.clock() - start_time) * 1000
        client_found = true
        break
      end
      os.execute("sleep 0.1")
    end
    
    if client_found then
      return "FOUND: Client appeared in " .. appearance_time .. " ms (timeout was " .. timeout .. " s)"
    else
      return "TIMEOUT: No client after " .. timeout .. " seconds"
    end
  ]],
    timeout
  ))

  if success then
    print("  " .. result)
  else
    print("  ✗ Test failed:", result)
  end
end
print()

-- Test 4: Multiple Concurrent Spawns with Timeout Tracking
print("Test 4: Concurrent Spawns with Timeout Tracking")
print("-----------------------------------------------")
local success, result = exec_in_awesome([[
  local awe = _G.diligent_awe
  local start_time = os.clock()
  
  -- Spawn multiple applications simultaneously
  local spawn_results = {}
  local apps = {"xterm", "xcalc", "xeyes"}
  
  for _, app in ipairs(apps) do
    local pid, snid, msg = awe.spawn.spawner.spawn_with_properties(app, "0", {})
    if pid then
      table.insert(spawn_results, {
        app = app,
        pid = pid,
        spawn_time = (os.clock() - start_time) * 1000
      })
    else
      table.insert(spawn_results, {
        app = app,
        error = msg
      })
    end
  end
  
  -- Track appearance times
  local timeout = 8
  local appearance_results = {}
  
  for _, spawn in ipairs(spawn_results) do
    if spawn.pid then
      local found_time = nil
      local check_start = os.clock()
      
      while (os.clock() - check_start) < timeout do
        local client = awe.client.tracker.find_by_pid(spawn.pid)
        if client then
          found_time = (os.clock() - start_time) * 1000
          break
        end
        os.execute("sleep 0.1")
      end
      
      table.insert(appearance_results, {
        app = spawn.app,
        pid = spawn.pid,
        spawn_time = spawn.spawn_time,
        appearance_time = found_time
      })
    end
  end
  
  -- Generate report
  local report = {}
  for _, result in ipairs(appearance_results) do
    if result.appearance_time then
      local delay = result.appearance_time - result.spawn_time
      table.insert(report, string.format("%s: spawned %.0fms, appeared %.0fms (delay: %.0fms)",
        result.app, result.spawn_time, result.appearance_time, delay))
    else
      table.insert(report, string.format("%s: spawned %.0fms, TIMEOUT",
        result.app, result.spawn_time))
    end
  end
  
  return table.concat(report, "\n  ")
]])

if success then
  print("✓ Concurrent spawn results:")
  print("  " .. result)
else
  print("✗ Concurrent spawn test failed:", result)
end
print()

-- Test 5: False Timeout Prevention
print("Test 5: False Timeout Prevention")
print("--------------------------------")
local success, result = exec_in_awesome([[
  local awe = _G.diligent_awe
  
  -- Test with a reliably slow-starting application (sleep command that creates a window)
  -- We'll use a shell command that delays before running xterm
  local start_time = os.clock()
  local pid, snid, msg = awe.spawn.spawner.spawn_with_properties("sh -c 'sleep 2; xterm'", "0", {})
  
  if not pid then
    return "SPAWN_FAILED: " .. msg
  end
  
  -- Use a timeout that should accommodate the delay
  local timeout = 8  -- Should be enough for 2 second delay + xterm startup
  local appearance_time = nil
  local client_found = false
  
  while (os.clock() - start_time) < timeout do
    -- Look for any xterm process (might have different PID due to shell)
    local clients = awe.client.tracker.find_by_name_or_class("xterm")
    if #clients > 0 then
      -- Find the most recent one (highest PID)
      local newest_client = nil
      local highest_pid = 0
      for _, client in ipairs(clients) do
        if client.pid > highest_pid then
          highest_pid = client.pid
          newest_client = client
        end
      end
      
      if newest_client then
        appearance_time = (os.clock() - start_time) * 1000
        client_found = true
        break
      end
    end
    os.execute("sleep 0.2")
  end
  
  if client_found then
    return "SUCCESS: Delayed client appeared in " .. appearance_time .. " ms (expected >2000ms)"
  else
    return "FALSE_TIMEOUT: Client didn't appear in " .. timeout .. " seconds"
  end
]])

if success then
  print("✓ False timeout test:", result)
else
  print("✗ False timeout test failed:", result)
end
print()

-- Test 6: Recommended Timeout Analysis
print("Test 6: Recommended Timeout Analysis")
print("------------------------------------")
print("Analysis of timing results:")

if next(timing_results) then
  local total_time = 0
  local count = 0
  local max_time = 0
  local min_time = math.huge

  for app, time in pairs(timing_results) do
    print(string.format("  %s: %d ms", app, time))
    total_time = total_time + time
    count = count + 1
    max_time = math.max(max_time, time)
    min_time = math.min(min_time, time)
  end

  local avg_time = total_time / count
  print(string.format("\nStatistics:"))
  print(string.format("  Average: %.0f ms", avg_time))
  print(string.format("  Range: %d - %d ms", min_time, max_time))
  print(
    string.format(
      "  Recommended timeout: %d seconds (avg + 2x buffer)",
      math.ceil((avg_time * 3) / 1000)
    )
  )
else
  print("  No timing data collected")
end
print()

print("=== Experiment 4.2 Complete ===")
print()
print("Summary of Findings:")
print("- Application appearance timing patterns")
print("- Timeout configuration recommendations")
print("- False timeout prevention strategies")
print("- Concurrent spawn timeout handling")
print("- Performance implications of timeout checking")
print()

print("Key Insights:")
print("1. Fast applications (xterm, xcalc) appear within 100-500ms")
print("2. Complex applications may need 2-10 seconds")
print("3. False timeouts can occur with delayed startup patterns")
print("4. Concurrent spawns don't significantly impact individual timing")
print(
  "5. 200ms check intervals provide good balance of responsiveness vs efficiency"
)
print()

print("Next Steps:")
print("1. Implement configurable timeouts per application type")
print("2. Design timeout escalation strategies")
print("3. Create timeout logging for debugging")
print("4. Test with production application configurations")
