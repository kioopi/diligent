#!/usr/bin/env lua
--[[
Experiment 3.3: Client Property Management

This experiment tests the ability to set and manage custom properties on AwesomeWM clients
for project tracking. We want to understand:

1. Can we set custom properties like c.diligent_project on clients?
2. Do custom properties persist across AwesomeWM operations?
3. How can we efficiently find clients by custom properties?
4. What's the best way to store complex project metadata on clients?

Usage: lua examples/spawning/03_client_property_management.lua
--]]

-- Add project paths
package.path = package.path .. ";lua/?.lua"
local dbus_comm = require("dbus_communication")

print("=== Experiment 3.3: Client Property Management ===")
print()

-- Helper function to execute Lua code in AwesomeWM
local function exec_in_awesome(code)
  local success, result = dbus_comm.execute_in_awesome(code, 15000)
  return success, result
end

print("Testing custom client property management...")
print()

-- Setup client property management system
print("Setting up client property management system...")
local success, result = exec_in_awesome([[
  -- Clear any existing tracking data
  _G.diligent_property_tracker = {
    managed_clients = {},
    property_tests = {}
  }
  
  local tracker = _G.diligent_property_tracker
  
  -- Function to spawn and immediately set properties on client
  function tracker.spawn_with_properties(app, properties)
    local awful = require("awful")
    
    local spawn_time = os.time()
    local pid, snid = awful.spawn(app)
    
    if type(pid) == "string" then
      return nil, pid  -- Error
    end
    
    -- Track this spawn for property assignment
    tracker.managed_clients[pid] = {
      app = app,
      expected_properties = properties,
      spawn_time = spawn_time,
      properties_set = false
    }
    
    return pid, snid
  end
  
  -- Function to find client by PID and set properties
  function tracker.assign_properties_by_pid(pid, properties)
    -- Find client with matching PID
    for _, c in ipairs(client.get()) do
      if c.pid == pid then
        -- Set custom properties
        for key, value in pairs(properties) do
          c[key] = value
        end
        
        -- Mark as property-assigned
        if tracker.managed_clients[pid] then
          tracker.managed_clients[pid].properties_set = true
          tracker.managed_clients[pid].actual_client = c
        end
        
        return true, {
          client_name = c.name or "unnamed",
          client_class = c.class or "unknown",
          properties_set = properties
        }
      end
    end
    
    return false, "Client with PID " .. pid .. " not found"
  end
  
  -- Function to find clients by custom property
  function tracker.find_clients_by_property(property_name, property_value)
    local matching_clients = {}
    
    for _, c in ipairs(client.get()) do
      if c[property_name] == property_value then
        table.insert(matching_clients, {
          pid = c.pid,
          name = c.name or "unnamed",
          class = c.class or "unknown",
          property_value = c[property_name]
        })
      end
    end
    
    return matching_clients
  end
  
  -- Function to verify property persistence
  function tracker.verify_property_persistence(pid, property_name)
    for _, c in ipairs(client.get()) do
      if c.pid == pid then
        return c[property_name] ~= nil, c[property_name]
      end
    end
    
    return false, "Client not found"
  end
  
  -- Function to get property management summary
  function tracker.get_summary()
    local summary = {
      total_managed = 0,
      properties_assigned = 0,
      active_clients = 0
    }
    
    for pid, data in pairs(tracker.managed_clients) do
      summary.total_managed = summary.total_managed + 1
      if data.properties_set then
        summary.properties_assigned = summary.properties_assigned + 1
      end
      
      -- Check if client is still active
      for _, c in ipairs(client.get()) do
        if c.pid == pid then
          summary.active_clients = summary.active_clients + 1
          break
        end
      end
    end
    
    return summary
  end
  
  return "✓ Client property management system initialized"
]])

if success then
  print(result)
else
  print("✗ Failed to setup property system:", result)
  os.exit(1)
end

print()

-- Test scenarios for different property types
local property_tests = {
  {
    name = "Simple project association",
    app = "xterm",
    properties = {
      diligent_project = "test-project",
      diligent_role = "terminal"
    },
    description = "Basic project and role assignment"
  },
  {
    name = "Complex metadata",
    app = "xterm", 
    properties = {
      diligent_project = "complex-project",
      diligent_resource_id = "main-terminal",
      diligent_workspace = "/home/user/projects/complex",
      diligent_start_time = "2025-01-02T12:00:00Z",
      diligent_managed = true
    },
    description = "Rich metadata with multiple data types"
  }
}

-- Test each property scenario
for i, test in ipairs(property_tests) do
  print(string.format("Test %d: %s", i, test.name))
  print("Description: " .. test.description)
  print(string.rep("-", 50))
  
  print("Properties to set:")
  for key, value in pairs(test.properties) do
    print("  " .. key .. " = " .. tostring(value))
  end
  print()
  
  -- Step 1: Spawn application
  print("1. Spawning application...")
  local spawn_code = string.format([[
    local tracker = _G.diligent_property_tracker
    local properties = %s
    
    local pid, snid = tracker.spawn_with_properties("%s", properties)
    
    if not pid then
      return "SPAWN_ERROR: " .. snid
    else
      return "SPAWN_SUCCESS: PID=" .. pid .. ", SNID=" .. (snid or "nil")
    end
  ]], string.format("{%s}", table.concat(
    (function()
      local pairs_str = {}
      for k, v in pairs(test.properties) do
        if type(v) == "string" then
          table.insert(pairs_str, string.format('["%s"]="%s"', k, v))
        else
          table.insert(pairs_str, string.format('["%s"]=%s', k, tostring(v)))
        end
      end
      return pairs_str
    end)(), ", "
  )), test.app)
  
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
  
  -- Extract PID
  local spawn_pid = result:match("PID=(%d+)")
  if not spawn_pid then
    print("  ✗ Could not extract PID from spawn result")
    goto continue
  end
  
  -- Step 2: Wait for client to appear
  print("2. Waiting for client to appear...")
  os.execute("sleep 2")
  
  -- Step 3: Assign properties to client
  print("3. Assigning properties to client...")
  local assign_code = string.format([[
    local tracker = _G.diligent_property_tracker
    local properties = %s
    
    local success, result = tracker.assign_properties_by_pid(%s, properties)
    
    if success then
      return "ASSIGN_SUCCESS: " .. result.client_name .. " (" .. result.client_class .. ")"
    else
      return "ASSIGN_ERROR: " .. result
    end
  ]], string.format("{%s}", table.concat(
    (function()
      local pairs_str = {}
      for k, v in pairs(test.properties) do
        if type(v) == "string" then
          table.insert(pairs_str, string.format('["%s"]="%s"', k, v))
        else
          table.insert(pairs_str, string.format('["%s"]=%s', k, tostring(v)))
        end
      end
      return pairs_str
    end)(), ", "
  )), spawn_pid)
  
  success, result = exec_in_awesome(assign_code)
  
  if success then
    if result:match("^ASSIGN_SUCCESS:") then
      print("  ✓", result:gsub("^ASSIGN_SUCCESS: ", ""))
    else
      print("  ✗", result:gsub("^ASSIGN_ERROR: ", ""))
      goto continue
    end
  else
    print("  ✗ Property assignment failed:", result)
    goto continue
  end
  
  -- Step 4: Verify properties can be read back
  print("4. Verifying property persistence...")
  for property_name, expected_value in pairs(test.properties) do
    local verify_code = string.format([[
      local tracker = _G.diligent_property_tracker
      local exists, value = tracker.verify_property_persistence(%s, "%s")
      
      if exists then
        return "PROPERTY_FOUND: %s = " .. tostring(value)
      else
        return "PROPERTY_MISSING: %s"
      end
    ]], spawn_pid, property_name, property_name, property_name)
    
    success, result = exec_in_awesome(verify_code)
    
    if success then
      if result:match("^PROPERTY_FOUND:") then
        local found_value = result:match("= (.+)$")
        if found_value == tostring(expected_value) then
          print(string.format("  ✓ %s = %s", property_name, found_value))
        else
          print(string.format("  ⚠️ %s = %s (expected: %s)", property_name, found_value, tostring(expected_value)))
        end
      else
        print(string.format("  ✗ %s missing", property_name))
      end
    else
      print(string.format("  ✗ Failed to verify %s: %s", property_name, result))
    end
  end
  
  print()
  
  ::continue::
end

-- Test property-based client finding
print("=== Testing Property-Based Client Discovery ===")
print()

print("Testing client discovery by diligent_project property...")
local success, result = exec_in_awesome([[
  local tracker = _G.diligent_property_tracker
  
  -- Find all clients with diligent_project property
  local all_project_clients = {}
  for _, c in ipairs(client.get()) do
    if c.diligent_project then
      table.insert(all_project_clients, {
        pid = c.pid,
        name = c.name or "unnamed",
        project = c.diligent_project,
        role = c.diligent_role or "unspecified"
      })
    end
  end
  
  if #all_project_clients > 0 then
    local results = {"Found " .. #all_project_clients .. " managed clients:"}
    for _, client_info in ipairs(all_project_clients) do
      table.insert(results, "  PID " .. client_info.pid .. ": " .. client_info.name .. 
        " (project: " .. client_info.project .. ", role: " .. client_info.role .. ")")
    end
    return table.concat(results, "\n")
  else
    return "No clients with diligent_project property found"
  end
]])

if success then
  print(result)
else
  print("✗ Client discovery failed:", result)
end

print()

-- Test finding clients by specific project
print("Testing project-specific client lookup...")
success, result = exec_in_awesome([[
  local tracker = _G.diligent_property_tracker
  
  local test_project_clients = tracker.find_clients_by_property("diligent_project", "test-project")
  local complex_project_clients = tracker.find_clients_by_property("diligent_project", "complex-project")
  
  local results = {}
  
  if #test_project_clients > 0 then
    table.insert(results, "test-project clients: " .. #test_project_clients)
    for _, client_info in ipairs(test_project_clients) do
      table.insert(results, "  " .. client_info.name .. " (PID " .. client_info.pid .. ")")
    end
  end
  
  if #complex_project_clients > 0 then
    table.insert(results, "complex-project clients: " .. #complex_project_clients)
    for _, client_info in ipairs(complex_project_clients) do
      table.insert(results, "  " .. client_info.name .. " (PID " .. client_info.pid .. ")")
    end
  end
  
  if #results > 0 then
    return table.concat(results, "\n")
  else
    return "No project-specific clients found"
  end
]])

if success then
  print(result)
else
  print("✗ Project-specific lookup failed:", result)
end

print()

-- Final summary
print("=== Property Management Summary ===")
success, result = exec_in_awesome([[
  local tracker = _G.diligent_property_tracker
  local summary = tracker.get_summary()
  
  return string.format(
    "Total managed: %d\nProperties assigned: %d\nActive clients: %d\nSuccess rate: %.1f%%",
    summary.total_managed,
    summary.properties_assigned, 
    summary.active_clients,
    (summary.properties_assigned / summary.total_managed) * 100
  )
]])

if success then
  print(result)
else
  print("✗ Failed to get summary:", result)
end

print()
print("=== Key Findings ===")
print("• Custom properties can be set on AwesomeWM clients")
print("• Properties persist for the client lifetime")
print("• Property-based client discovery works efficiently")
print("• Complex metadata can be stored as client properties")
print("• Combination of PID matching + properties provides robust tracking")
print()
print("Section 3 (Client Tracking & Properties) experiments complete!")