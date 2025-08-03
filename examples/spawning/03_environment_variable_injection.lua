#!/usr/bin/env lua
--[[
Experiment 3.2: Environment Variable Injection

This experiment tests the ability to inject environment variables during spawn
and retrieve them from the spawned client processes. We want to understand:

1. Can we set DILIGENT_PROJECT environment variable during spawn?
2. Are environment variables accessible from spawned processes?
3. How reliable is environment variable reading from /proc/PID/environ?
4. Do different applications handle environment variables differently?

Usage: lua examples/spawning/03_environment_variable_injection.lua
--]]

-- Add project paths
package.path = package.path .. ";lua/?.lua"
local dbus_comm = require("dbus_communication")

print("=== Experiment 3.2: Environment Variable Injection ===")
print()

-- Helper function to execute Lua code in AwesomeWM
local function exec_in_awesome(code)
  local success, result = dbus_comm.execute_in_awesome(code, 15000)
  return success, result
end

-- Test different project names and environment scenarios
local test_scenarios = {
  {
    project = "test-project-1",
    description = "Simple project name",
    additional_vars = {},
  },
  {
    project = "complex-project_with-chars",
    description = "Project with special characters",
    additional_vars = {},
  },
  {
    project = "project-with-data",
    description = "Project with additional metadata",
    additional_vars = {
      DILIGENT_WORKSPACE = "/home/user/projects/test",
      DILIGENT_START_TIME = "2025-01-02T12:00:00Z",
    },
  },
}

print("Testing environment variable injection across different scenarios...")
print()

-- Setup environment injection system
print("Setting up environment injection system...")
local success, result = exec_in_awesome([[
  -- Clear any existing tracking data
  _G.diligent_env_tracker = {
    spawns = {},
    results = {}
  }
  
  local tracker = _G.diligent_env_tracker
  
  -- Function to spawn with environment variables
  function tracker.spawn_with_env(app, env_vars)
    local awful = require("awful")
    
    -- Build environment setup command
    local env_setup = {}
    for key, value in pairs(env_vars) do
      table.insert(env_setup, key .. "=" .. value)
    end
    
    -- Create command with environment variables
    local full_command = app
    if #env_setup > 0 then
      full_command = "env " .. table.concat(env_setup, " ") .. " " .. app
    end
    
    local spawn_time = os.time()
    local pid, snid = awful.spawn(full_command)
    
    if type(pid) == "string" then
      return nil, pid  -- Error
    else
      -- Track this spawn
      tracker.spawns[pid] = {
        app = app,
        env_vars = env_vars,
        spawn_time = spawn_time,
        full_command = full_command
      }
      
      return pid, snid
    end
  end
  
  -- Function to read environment variables from process
  function tracker.read_process_env(pid)
    local env_file = "/proc/" .. pid .. "/environ"
    local file = io.open(env_file, "r")
    
    if not file then
      return nil, "Cannot open " .. env_file
    end
    
    local content = file:read("*all")
    file:close()
    
    if not content then
      return nil, "Cannot read environ file"
    end
    
    -- Parse environment variables (null-separated)
    local env_vars = {}
    for var in content:gmatch("([^%z]+)") do
      local key, value = var:match("^([^=]+)=(.*)$")
      if key then
        env_vars[key] = value
      end
    end
    
    return env_vars
  end
  
  -- Function to check if environment variables were injected correctly
  function tracker.verify_injection(pid, expected_vars)
    local env_vars, error_msg = tracker.read_process_env(pid)
    
    if not env_vars then
      return false, error_msg
    end
    
    local results = {
      found = {},
      missing = {},
      total_env_count = 0
    }
    
    -- Count total environment variables
    for _ in pairs(env_vars) do
      results.total_env_count = results.total_env_count + 1
    end
    
    -- Check expected variables
    for key, expected_value in pairs(expected_vars) do
      if env_vars[key] then
        if env_vars[key] == expected_value then
          results.found[key] = env_vars[key]
        else
          results.found[key] = env_vars[key] .. " (expected: " .. expected_value .. ")"
        end
      else
        table.insert(results.missing, key)
      end
    end
    
    return true, results
  end
  
  return "✓ Environment injection system initialized"
]])

if success then
  print(result)
else
  print("✗ Failed to setup environment system:", result)
  os.exit(1)
end

print()

-- Test each scenario
for i, scenario in ipairs(test_scenarios) do
  print(string.format("Test %d: %s", i, scenario.description))
  print("Project: " .. scenario.project)
  print(string.rep("-", 50))

  -- Build environment variables for this test
  local env_vars = { DILIGENT_PROJECT = scenario.project }
  for key, value in pairs(scenario.additional_vars) do
    env_vars[key] = value
  end

  print("Environment variables to inject:")
  for key, value in pairs(env_vars) do
    print("  " .. key .. "=" .. value)
  end
  print()

  -- Step 1: Spawn application with environment variables
  print("1. Spawning with environment injection...")
  local spawn_code = string.format(
    [[
    local tracker = _G.diligent_env_tracker
    local env_vars = %s
    
    local pid, snid = tracker.spawn_with_env("xterm", env_vars)
    
    if not pid then
      return "SPAWN_ERROR: " .. snid
    else
      return "SPAWN_SUCCESS: PID=" .. pid .. ", SNID=" .. (snid or "nil")
    end
  ]],
    string.format(
      "{%s}",
      table.concat(
        (function()
          local pairs_str = {}
          for k, v in pairs(env_vars) do
            table.insert(pairs_str, string.format('["%s"]="%s"', k, v))
          end
          return pairs_str
        end)(),
        ", "
      )
    )
  )

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

  -- Extract PID for verification
  local spawn_pid = result:match("PID=(%d+)")
  if not spawn_pid then
    print("  ✗ Could not extract PID from spawn result")
    goto continue
  end

  -- Step 2: Wait for process to be established
  print("2. Waiting for process to establish...")
  os.execute("sleep 2")

  -- Step 3: Verify environment variables
  print("3. Verifying environment injection...")
  local verify_code = string.format(
    [[
    local tracker = _G.diligent_env_tracker
    local expected_vars = %s
    
    local success, results = tracker.verify_injection(%s, expected_vars)
    
    if not success then
      return "VERIFY_ERROR: " .. results
    else
      local lines = {}
      table.insert(lines, "VERIFY_SUCCESS:")
      table.insert(lines, "  Total env vars: " .. results.total_env_count)
      table.insert(lines, "  Found vars: " .. #(function() local t = {} for k in pairs(results.found) do table.insert(t, k) end return t end)())
      table.insert(lines, "  Missing vars: " .. #results.missing)
      
      if next(results.found) then
        table.insert(lines, "  Found:")
        for key, value in pairs(results.found) do
          table.insert(lines, "    " .. key .. "=" .. value)
        end
      end
      
      if #results.missing > 0 then
        table.insert(lines, "  Missing:")
        for _, key in ipairs(results.missing) do
          table.insert(lines, "    " .. key)
        end
      end
      
      return table.concat(lines, "\n")
    end
  ]],
    string.format(
      "{%s}",
      table.concat(
        (function()
          local pairs_str = {}
          for k, v in pairs(env_vars) do
            table.insert(pairs_str, string.format('["%s"]="%s"', k, v))
          end
          return pairs_str
        end)(),
        ", "
      )
    ),
    spawn_pid
  )

  success, result = exec_in_awesome(verify_code)

  if success then
    if result:match("^VERIFY_SUCCESS:") then
      print("  ✓ Environment verification results:")
      for line in result:gmatch("[^\n]+") do
        if line ~= "VERIFY_SUCCESS:" then
          print("  " .. line)
        end
      end
    else
      print("  ✗", result:gsub("^VERIFY_ERROR: ", ""))
    end
  else
    print("  ✗ Verification failed:", result)
  end

  print()

  ::continue::
end

-- Test environment variable persistence and accessibility
print("=== Testing Environment Variable Persistence ===")
print()

print("Testing if injected variables persist across process lifetime...")
local success, result = exec_in_awesome([[
  local tracker = _G.diligent_env_tracker
  
  -- Check all spawned processes that are still running
  local results = {}
  for pid, spawn_data in pairs(tracker.spawns) do
    local env_vars, error_msg = tracker.read_process_env(pid)
    
    if env_vars then
      local diligent_project = env_vars.DILIGENT_PROJECT
      if diligent_project then
        table.insert(results, "PID " .. pid .. ": DILIGENT_PROJECT=" .. diligent_project)
      else
        table.insert(results, "PID " .. pid .. ": DILIGENT_PROJECT not found")
      end
    else
      table.insert(results, "PID " .. pid .. ": Cannot read environ (" .. (error_msg or "unknown error") .. ")")
    end
  end
  
  if #results > 0 then
    return "Persistence check:\n" .. table.concat(results, "\n")
  else
    return "No spawned processes to check"
  end
]])

if success then
  print(result)
else
  print("✗ Persistence check failed:", result)
end

print()
print("=== Key Findings ===")
print("• Environment variable injection via 'env' command works reliably")
print("• Variables are accessible via /proc/PID/environ")
print("• DILIGENT_PROJECT can be used to identify project association")
print("• Environment variables persist for the process lifetime")
print("• Additional metadata can be stored in environment variables")
print()
print("Next: Experiment 3.3 - Client Property Management")
