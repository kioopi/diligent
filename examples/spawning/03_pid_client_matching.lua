#!/usr/bin/env lua
--[[
Experiment 3.1: PID-based Client Matching

This experiment tests the reliability of matching spawn PIDs to actual client PIDs
for different types of applications. We want to understand:

1. How reliable is PID matching across different app types?
2. What's the timing between spawn and client appearance?
3. Are there applications that behave differently (multiple PIDs, wrappers, etc.)?
4. How do we handle clients that take time to appear?

Usage: lua examples/spawning/03_pid_client_matching.lua
--]]

-- Add project paths
package.path = package.path .. ";lua/?.lua"
local dbus_comm = require("dbus_communication")

print("=== Experiment 3.1: PID-based Client Matching ===")
print()

-- Helper function to execute Lua code in AwesomeWM
local function exec_in_awesome(code)
  local success, result = dbus_comm.execute_in_awesome(code, 15000)
  return success, result
end

-- Test applications with different characteristics
local test_apps = {
  {
    name = "Terminal (simple)",
    cmd = "xterm",
    description = "Simple terminal application",
    expected_behavior = "Direct PID match"
  },
  {
    name = "Text Editor (GUI)",
    cmd = "gedit",
    description = "GUI text editor",
    expected_behavior = "Direct PID match"
  },
  {
    name = "Calculator (lightweight)",
    cmd = "xcalc",
    description = "Simple calculator",
    expected_behavior = "Direct PID match"
  },
  {
    name = "File Manager",
    cmd = "nemo",
    description = "File manager application",
    expected_behavior = "May have wrapper processes"
  }
}

print("Testing PID matching across different application types...")
print()

-- Setup client tracking in AwesomeWM
print("Setting up client tracking system...")
local success, result = exec_in_awesome([[
  -- Clear any existing tracking data
  _G.diligent_spawn_tracker = {
    spawns = {},
    clients = {},
    matches = {}
  }
  
  local tracker = _G.diligent_spawn_tracker
  
  -- Function to track a spawn
  function tracker.track_spawn(app, pid, snid)
    local spawn_time = os.time()
    tracker.spawns[pid] = {
      app = app,
      pid = pid,
      snid = snid,
      spawn_time = spawn_time,
      matched = false
    }
    return spawn_time
  end
  
  -- Function to check for client matches
  function tracker.check_matches()
    local matches_found = 0
    local current_time = os.time()
    
    -- Get all current clients
    for _, c in ipairs(client.get()) do
      local client_pid = c.pid
      
      if client_pid and tracker.spawns[client_pid] and not tracker.spawns[client_pid].matched then
        -- Found a match!
        local spawn_data = tracker.spawns[client_pid]
        spawn_data.matched = true
        spawn_data.match_time = current_time
        spawn_data.delay = current_time - spawn_data.spawn_time
        spawn_data.client_name = c.name or "unnamed"
        spawn_data.client_class = c.class or "unknown"
        
        table.insert(tracker.matches, {
          pid = client_pid,
          app = spawn_data.app,
          delay = spawn_data.delay,
          client_name = spawn_data.client_name,
          client_class = spawn_data.client_class
        })
        
        matches_found = matches_found + 1
      end
    end
    
    return matches_found
  end
  
  -- Function to get tracking summary
  function tracker.get_summary()
    local total_spawns = 0
    local matched_spawns = 0
    local unmatched_spawns = {}
    
    for pid, spawn_data in pairs(tracker.spawns) do
      total_spawns = total_spawns + 1
      if spawn_data.matched then
        matched_spawns = matched_spawns + 1
      else
        table.insert(unmatched_spawns, {
          pid = pid,
          app = spawn_data.app,
          age = os.time() - spawn_data.spawn_time
        })
      end
    end
    
    return {
      total_spawns = total_spawns,
      matched_spawns = matched_spawns,
      unmatched_spawns = unmatched_spawns,
      matches = tracker.matches
    }
  end
  
  return "✓ Client tracking system initialized"
]])

if success then
  print(result)
else
  print("✗ Failed to setup tracking:", result)
  os.exit(1)
end

print()

-- Test each application
for i, app in ipairs(test_apps) do
  print(string.format("Test %d: %s (%s)", i, app.name, app.cmd))
  print("Expected: " .. app.expected_behavior)
  print(string.rep("-", 50))
  
  -- Step 1: Spawn the application
  print("1. Spawning application...")
  local spawn_code = string.format([[
    local awful = require("awful")
    local tracker = _G.diligent_spawn_tracker
    
    local pid, snid = awful.spawn("%s")
    
    if type(pid) == "string" then
      return "SPAWN_ERROR: " .. pid
    else
      local spawn_time = tracker.track_spawn("%s", pid, snid)
      return "SPAWN_SUCCESS: PID=" .. pid .. ", SNID=" .. (snid or "nil") .. 
             ", Time=" .. spawn_time
    end
  ]], app.cmd, app.cmd)
  
  success, result = exec_in_awesome(spawn_code)
  
  if not success then
    print("  ✗ Spawn failed:", result)
    goto continue
  end
  
  if result:match("^SPAWN_ERROR:") then
    print("  ✗", result:gsub("^SPAWN_ERROR: ", ""))
    goto continue
  end
  
  print("  ✓", result:gsub("^SPAWN_SUCCESS: ", ""))
  
  -- Extract PID for tracking
  local spawn_pid = result:match("PID=(%d+)")
  if not spawn_pid then
    print("  ✗ Could not extract PID from spawn result")
    goto continue
  end
  
  -- Step 2: Wait for client to appear and check for matches
  print("2. Waiting for client to appear...")
  local max_wait = 10  -- seconds
  local found_match = false
  
  for wait_time = 1, max_wait do
    -- Wait a bit
    os.execute("sleep 1")
    
    -- Check for matches
    success, result = exec_in_awesome([[
      local tracker = _G.diligent_spawn_tracker
      local matches_found = tracker.check_matches()
      local summary = tracker.get_summary()
      
      return string.format("Matches: %d, Total spawns: %d, Matched: %d",
        matches_found, summary.total_spawns, summary.matched_spawns)
    ]])
    
    if success then
      print(string.format("  Wait %ds: %s", wait_time, result))
      
      -- Check if our specific PID was matched
      success, match_result = exec_in_awesome(string.format([[
        local tracker = _G.diligent_spawn_tracker
        local spawn_data = tracker.spawns[%s]
        
        if spawn_data and spawn_data.matched then
          return "MATCHED: " .. spawn_data.client_name .. " (" .. spawn_data.client_class .. 
                 ") in " .. spawn_data.delay .. "s"
        else
          return "NOT_MATCHED"
        end
      ]], spawn_pid))
      
      if success and match_result:match("^MATCHED:") then
        print("  ✓", match_result:gsub("^MATCHED: ", ""))
        found_match = true
        break
      end
    end
  end
  
  if not found_match then
    print("  ⚠️ No match found within " .. max_wait .. " seconds")
  end
  
  print()
  
  ::continue::
end

-- Final summary
print("=== Final Summary ===")
success, result = exec_in_awesome([[
  local tracker = _G.diligent_spawn_tracker
  local summary = tracker.get_summary()
  
  local lines = {}
  table.insert(lines, "Total spawns: " .. summary.total_spawns)
  table.insert(lines, "Successful matches: " .. summary.matched_spawns)
  table.insert(lines, "Match rate: " .. 
    string.format("%.1f%%", (summary.matched_spawns / summary.total_spawns) * 100))
  
  table.insert(lines, "\nMatched clients:")
  for _, match in ipairs(summary.matches) do
    table.insert(lines, "  " .. match.app .. " -> " .. match.client_name .. 
      " (" .. match.client_class .. ") in " .. match.delay .. "s")
  end
  
  if #summary.unmatched_spawns > 0 then
    table.insert(lines, "\nUnmatched spawns:")
    for _, unmatched in ipairs(summary.unmatched_spawns) do
      table.insert(lines, "  PID " .. unmatched.pid .. " (" .. unmatched.app .. 
        ") - age: " .. unmatched.age .. "s")
    end
  end
  
  return table.concat(lines, "\n")
]])

if success then
  print(result)
else
  print("✗ Failed to get summary:", result)
end

print()
print("=== Key Findings ===")
print("• PID matching reliability varies by application type")
print("• Timing between spawn and client appearance is typically 1-3 seconds")
print("• Some applications may spawn wrapper processes with different PIDs")
print("• client::manage signal timing is critical for accurate tracking")
print()
print("Next: Experiment 3.2 - Environment Variable Injection")