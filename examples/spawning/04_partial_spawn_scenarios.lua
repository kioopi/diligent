#!/usr/bin/env lua
--[[
Experiment 4.3: Partial Spawn Scenarios

This experiment tests mixed success/failure scenarios when spawning multiple
applications. We want to understand:
1. How to handle projects with mix of valid/invalid commands
2. Recovery strategies for partial failures
3. State consistency after partial failures
4. Dependency handling when prerequisite apps fail
5. User feedback for mixed outcomes

Usage: lua examples/spawning/04_partial_spawn_scenarios.lua
--]]

-- Add project paths
package.path = package.path .. ";lua/?.lua"
local dbus_comm = require("dbus_communication")

print("=== Experiment 4.3: Partial Spawn Scenarios ===")
print()

-- Helper function to execute Lua code in AwesomeWM and capture results
local function exec_in_awesome(code)
  local success, result = dbus_comm.execute_in_awesome(code, 8000)
  return success, result
end

-- Initialize awesome_client_manager
print("Initializing awesome_client_manager...")
local success, result = exec_in_awesome([[
  local success, acm = pcall(require, "awesome_client_manager")
  if not success then
    return "ERROR: Failed to load awesome_client_manager: " .. tostring(acm)
  end
  _G.diligent_client_manager = acm
  return "SUCCESS: Client manager loaded"
]])

if not success or result:match("^ERROR:") then
  print("✗ Failed to initialize client manager:", result)
  os.exit(1)
end

print("✓ Client manager initialized")
print()

-- Test 1: Mixed Valid/Invalid Commands
print("Test 1: Mixed Valid/Invalid Commands")
print("------------------------------------")
local success, result = exec_in_awesome([[
  local acm = _G.diligent_client_manager
  
  -- Define test project with mix of valid/invalid commands
  local test_apps = {
    {name = "xcalc", valid = true, desc = "Calculator (should work)"},
    {name = "invalidapp123", valid = false, desc = "Non-existent app (should fail)"},
    {name = "xterm", valid = true, desc = "Terminal (should work)"},
    {name = "anotherapp456", valid = false, desc = "Another invalid app (should fail)"},
    {name = "xeyes", valid = true, desc = "Eyes (should work)"}
  }
  
  local results = {}
  local successful_spawns = 0
  local failed_spawns = 0
  
  -- Attempt to spawn each application
  for i, app in ipairs(test_apps) do
    local start_time = os.clock()
    local pid, snid, msg = acm.spawn_simple(app.name, "0")
    local spawn_time = (os.clock() - start_time) * 1000
    
    local status = "UNKNOWN"
    if pid then
      status = "SUCCESS"
      successful_spawns = successful_spawns + 1
    else
      status = "FAILED"
      failed_spawns = failed_spawns + 1
    end
    
    table.insert(results, {
      index = i,
      name = app.name,
      desc = app.desc,
      expected = app.valid and "SUCCESS" or "FAILED",
      actual = status,
      message = msg or "No message",
      spawn_time = spawn_time,
      pid = pid
    })
  end
  
  -- Generate report
  local report_lines = {}
  table.insert(report_lines, "SPAWN RESULTS:")
  
  for _, result in ipairs(results) do
    local match_indicator = (result.expected == result.actual) and "✓" or "✗"
    local line = string.format("%s %d. %s (%s) - Expected: %s, Got: %s (%.1fms)",
      match_indicator, result.index, result.name, result.desc,
      result.expected, result.actual, result.spawn_time)
    table.insert(report_lines, line)
    
    if result.actual == "FAILED" then
      table.insert(report_lines, "   Error: " .. result.message)
    end
  end
  
  table.insert(report_lines, "")
  table.insert(report_lines, string.format("SUMMARY: %d successful, %d failed out of %d total",
    successful_spawns, failed_spawns, #test_apps))
  
  return table.concat(report_lines, "\n")
]])

if success then
  print(result)
else
  print("✗ Mixed spawn test failed:", result)
end
print()

-- Test 2: Dependency Chain Simulation
print("Test 2: Dependency Chain Simulation")
print("-----------------------------------")
local success, result = exec_in_awesome([[
  local acm = _G.diligent_client_manager
  
  -- Simulate dependency chain: editor depends on file manager, terminal depends on nothing
  local dependency_chain = {
    {name = "xterm", deps = {}, desc = "Terminal (no deps)"},
    {name = "invalidfilemanager", deps = {}, desc = "File manager (should fail)"},
    {name = "gedit", deps = {"invalidfilemanager"}, desc = "Editor (depends on file manager)"}
  }
  
  local spawn_results = {}
  local dependency_failures = {}
  
  -- Process each application with dependency checking
  for _, app in ipairs(dependency_chain) do
    local can_spawn = true
    local dependency_issues = {}
    
    -- Check dependencies
    for _, dep_name in ipairs(app.deps) do
      local dep_spawned = false
      for _, prev_result in ipairs(spawn_results) do
        if prev_result.name == dep_name and prev_result.success then
          dep_spawned = true
          break
        end
      end
      
      if not dep_spawned then
        can_spawn = false
        table.insert(dependency_issues, dep_name)
      end
    end
    
    local result = {
      name = app.name,
      desc = app.desc,
      deps = app.deps,
      dependency_issues = dependency_issues
    }
    
    if not can_spawn then
      result.status = "SKIPPED"
      result.reason = "Missing dependencies: " .. table.concat(dependency_issues, ", ")
      result.success = false
    else
      -- Attempt spawn
      local pid, snid, msg = acm.spawn_simple(app.name, "0")
      if pid then
        result.status = "SUCCESS"
        result.success = true
        result.pid = pid
      else
        result.status = "FAILED"
        result.success = false
        result.reason = msg
      end
    end
    
    table.insert(spawn_results, result)
  end
  
  -- Generate dependency report
  local dep_report = {}
  table.insert(dep_report, "DEPENDENCY CHAIN RESULTS:")
  
  for i, result in ipairs(spawn_results) do
    local deps_str = #result.deps > 0 and "deps: " .. table.concat(result.deps, ",") or "no deps"
    table.insert(dep_report, string.format("%d. %s (%s) [%s]", i, result.name, deps_str, result.desc))
    table.insert(dep_report, "   Status: " .. result.status)
    if result.reason then
      table.insert(dep_report, "   Reason: " .. result.reason)
    end
  end
  
  return table.concat(dep_report, "\n")
]])

if success then
  print(result)
else
  print("✗ Dependency test failed:", result)
end
print()

-- Test 3: Recovery and Cleanup Strategies
print("Test 3: Recovery and Cleanup Strategies")
print("---------------------------------------")
local success, result = exec_in_awesome([[
  local acm = _G.diligent_client_manager
  
  -- Test recovery strategies for partial failures
  local project_apps = {
    "xterm",        -- Should work
    "invalidapp1",  -- Should fail
    "xcalc",        -- Should work
    "invalidapp2",  -- Should fail
    "xeyes"         -- Should work
  }
  
  local spawn_attempts = {}
  local successful_pids = {}
  local failed_commands = {}
  
  -- Phase 1: Initial spawn attempts
  for i, app in ipairs(project_apps) do
    local pid, snid, msg = acm.spawn_simple(app, "0")
    
    table.insert(spawn_attempts, {
      index = i,
      app = app,
      pid = pid,
      success = pid ~= nil,
      message = msg
    })
    
    if pid then
      table.insert(successful_pids, pid)
    else
      table.insert(failed_commands, app)
    end
  end
  
  -- Phase 2: Wait for successful clients to appear
  local client_verification = {}
  for _, pid in ipairs(successful_pids) do
    local timeout = 3
    local start_time = os.clock()
    local client_found = false
    
    while (os.clock() - start_time) < timeout do
      local client = acm.find_by_pid(pid)
      if client then
        client_found = true
        break
      end
      os.execute("sleep 0.2")
    end
    
    table.insert(client_verification, {
      pid = pid,
      appeared = client_found
    })
  end
  
  -- Phase 3: Generate recovery report
  local recovery_report = {}
  table.insert(recovery_report, "RECOVERY ANALYSIS:")
  table.insert(recovery_report, "")
  
  table.insert(recovery_report, "Initial spawn attempts:")
  for _, attempt in ipairs(spawn_attempts) do
    local status = attempt.success and "SUCCESS" or "FAILED"
    table.insert(recovery_report, string.format("  %d. %s - %s", attempt.index, attempt.app, status))
    if not attempt.success then
      table.insert(recovery_report, "     Error: " .. attempt.message)
    end
  end
  
  table.insert(recovery_report, "")
  table.insert(recovery_report, "Client verification:")
  for _, verification in ipairs(client_verification) do
    local status = verification.appeared and "APPEARED" or "MISSING"
    table.insert(recovery_report, string.format("  PID %s - %s", verification.pid, status))
  end
  
  table.insert(recovery_report, "")
  table.insert(recovery_report, "Recovery recommendations:")
  if #failed_commands > 0 then
    table.insert(recovery_report, "  - Failed commands: " .. table.concat(failed_commands, ", "))
    table.insert(recovery_report, "  - Consider: retry mechanism, user notification, graceful degradation")
  end
  
  local appeared_count = 0
  for _, v in ipairs(client_verification) do
    if v.appeared then appeared_count = appeared_count + 1 end
  end
  
  table.insert(recovery_report, string.format("  - Project status: %d/%d clients operational", 
    appeared_count, #successful_pids))
  
  return table.concat(recovery_report, "\n")
]])

if success then
  print(result)
else
  print("✗ Recovery test failed:", result)
end
print()

-- Test 4: State Consistency Validation
print("Test 4: State Consistency Validation")
print("------------------------------------")
local success, result = exec_in_awesome([[
  local acm = _G.diligent_client_manager
  
  -- Test state consistency after mixed success/failure
  local test_scenario = {
    project_name = "test_partial_project",
    expected_apps = {"xterm", "xcalc", "xeyes"},
    failed_apps = {"invalidapp1", "invalidapp2"}
  }
  
  local project_state = {
    name = test_scenario.project_name,
    attempted_spawns = {},
    successful_clients = {},
    failed_attempts = {},
    consistency_issues = {}
  }
  
  -- Record all spawn attempts
  local all_attempts = {}
  for _, app in ipairs(test_scenario.expected_apps) do
    table.insert(all_attempts, {app = app, should_succeed = true})
  end
  for _, app in ipairs(test_scenario.failed_apps) do
    table.insert(all_attempts, {app = app, should_succeed = false})
  end
  
  -- Execute spawns and track state
  for _, attempt in ipairs(all_attempts) do
    local pid, snid, msg = acm.spawn_simple(attempt.app, "0")
    
    local spawn_record = {
      app = attempt.app,
      expected_success = attempt.should_succeed,
      actual_success = pid ~= nil,
      pid = pid,
      message = msg,
      timestamp = os.time()
    }
    
    table.insert(project_state.attempted_spawns, spawn_record)
    
    if pid then
      table.insert(project_state.successful_clients, {
        app = attempt.app,
        pid = pid
      })
    else
      table.insert(project_state.failed_attempts, {
        app = attempt.app,
        error = msg
      })
    end
  end
  
  -- Validate state consistency
  local expected_successes = #test_scenario.expected_apps
  local actual_successes = #project_state.successful_clients
  local expected_failures = #test_scenario.failed_apps
  local actual_failures = #project_state.failed_attempts
  
  if actual_successes ~= expected_successes then
    table.insert(project_state.consistency_issues, 
      string.format("Expected %d successes, got %d", expected_successes, actual_successes))
  end
  
  if actual_failures ~= expected_failures then
    table.insert(project_state.consistency_issues, 
      string.format("Expected %d failures, got %d", expected_failures, actual_failures))
  end
  
  -- Generate state report
  local state_report = {}
  table.insert(state_report, "STATE CONSISTENCY REPORT:")
  table.insert(state_report, "Project: " .. project_state.name)
  table.insert(state_report, "")
  
  table.insert(state_report, "Successful clients:")
  for _, client in ipairs(project_state.successful_clients) do
    table.insert(state_report, string.format("  - %s (PID: %s)", client.app, client.pid))
  end
  
  table.insert(state_report, "")
  table.insert(state_report, "Failed attempts:")
  for _, failure in ipairs(project_state.failed_attempts) do
    table.insert(state_report, string.format("  - %s: %s", failure.app, failure.error))
  end
  
  table.insert(state_report, "")
  if #project_state.consistency_issues == 0 then
    table.insert(state_report, "✓ State is consistent with expectations")
  else
    table.insert(state_report, "✗ Consistency issues found:")
    for _, issue in ipairs(project_state.consistency_issues) do
      table.insert(state_report, "  - " .. issue)
    end
  end
  
  return table.concat(state_report, "\n")
]])

if success then
  print(result)
else
  print("✗ State consistency test failed:", result)
end
print()

print("=== Experiment 4.3 Complete ===")
print()
print("Summary of Findings:")
print("- Mixed success/failure handling patterns")
print("- Dependency chain management strategies")
print("- Recovery and cleanup approaches")
print("- State consistency validation methods")
print("- Production resilience patterns")
print()

print("Key Insights:")
print("1. Partial failures are manageable with proper error tracking")
print("2. Dependency checking prevents cascading failures")
print("3. State consistency requires careful bookkeeping")
print("4. Recovery strategies enable graceful degradation")
print("5. User feedback critical for mixed-outcome scenarios")
print()

print("Next Steps:")
print("1. Implement error aggregation and reporting")
print("2. Design retry mechanisms for transient failures")
print("3. Create dependency resolution system")
print("4. Develop user notification strategies")
print("5. Integrate with project state management")
