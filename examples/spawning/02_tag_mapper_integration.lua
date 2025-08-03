#!/usr/bin/env lua
--[[
Experiment 2.1: Tag Mapper Integration

This experiment tests integration between awful.spawn() and our existing tag mapper.
We want to understand:
1. How to use tag mapper with D-Bus communication
2. Whether tag mapper dry-run capabilities work in AwesomeWM context
3. How to handle tag creation and resolution errors
4. Performance characteristics of tag resolution + spawn

Usage: lua examples/spawning/02_tag_mapper_integration.lua
--]]

-- Add project paths
package.path = package.path .. ";lua/?.lua"
local dbus_comm = require("dbus_communication")

print("=== Experiment 2.1: Tag Mapper Integration ===")
print()

-- Helper function to execute Lua code in AwesomeWM
local function exec_in_awesome(code)
  local success, result = dbus_comm.execute_in_awesome(code, 10000)
  return success, result
end

-- Test 1: Check if tag mapper modules are available
print("Test 1: Tag Mapper Module Availability")
print("--------------------------------------")

local success, result = exec_in_awesome([[
  -- Try to require tag mapper modules
  local modules_available = {}
  local modules_to_test = {
    "tag_mapper.core",
    "tag_mapper.interfaces.awesome_interface", 
    "tag_mapper.integration"
  }
  
  for _, module_name in ipairs(modules_to_test) do
    local success, module = pcall(require, module_name)
    modules_available[module_name] = success
  end
  
  -- Format results
  local results = {}
  for module, available in pairs(modules_available) do
    table.insert(results, module .. ": " .. (available and "✓" or "✗"))
  end
  
  return table.concat(results, "\n")
]])

if success then
  print("Module availability:")
  print(result)
else
  print("✗ Failed to check modules:", result)
end
print()

-- Test 2: Setup basic tag mapper functionality
print("Test 2: Setup Basic Tag Mapper Functions")
print("-----------------------------------------")

success, result = exec_in_awesome([[
  -- Since tag mapper modules aren't available, create simplified versions
  -- that match the tag mapper interface but use basic AwesomeWM APIs
  
  local tag_mapper = {}
  
  -- Core tag resolution function (simplified from tag_mapper.core)
  function tag_mapper.resolve_tag_spec(tag_spec, screen)
    local awful = require("awful")
    local tags = screen.tags
    local current_tag = screen.selected_tag
    
    if tag_spec == 0 then
      -- Current tag
      return current_tag
    elseif type(tag_spec) == "number" then
      if tag_spec > 0 then
        -- Relative positive
        local target_index = current_tag.index + tag_spec
        if target_index <= #tags then
          return tags[target_index]
        else
          return nil, "Target index " .. target_index .. " exceeds available tags (" .. #tags .. ")"
        end
      else
        -- Relative negative  
        local target_index = current_tag.index + tag_spec  -- tag_spec is negative
        if target_index >= 1 then
          return tags[target_index]
        else
          return nil, "Target index " .. target_index .. " is less than 1"
        end
      end
    elseif type(tag_spec) == "string" then
      if tag_spec:match("^%d+$") then
        -- Absolute index
        local target_index = tonumber(tag_spec)
        if target_index >= 1 and target_index <= #tags then
          return tags[target_index]
        else
          return nil, "Tag index " .. target_index .. " not found (available: 1-" .. #tags .. ")"
        end
      else
        -- Named tag
        for _, tag in ipairs(tags) do
          if tag.name == tag_spec then
            return tag
          end
        end
        return nil, "Named tag '" .. tag_spec .. "' not found"
      end
    else
      return nil, "Invalid tag specification type: " .. type(tag_spec)
    end
  end
  
  -- Create named tag function (simplified from awesome_interface)
  function tag_mapper.create_named_tag(name, screen)
    local awful = require("awful")
    local new_tag = awful.tag.add(name, {
      screen = screen,
      layout = awful.layout.layouts[1]
    })
    return new_tag
  end
  
  -- Dry-run function (simplified version)
  function tag_mapper.dry_run_tag_resolution(tag_spec, screen)
    local tag, error_msg = tag_mapper.resolve_tag_spec(tag_spec, screen)
    if tag then
      return true, {
        action = "use_existing",
        tag_name = tag.name or ("tag_" .. tag.index),
        tag_index = tag.index,
        screen_index = screen.index
      }
    elseif type(tag_spec) == "string" and not tag_spec:match("^%d+$") then
      -- Named tag that doesn't exist - would be created
      return true, {
        action = "create_new",
        tag_name = tag_spec,
        tag_index = #screen.tags + 1,
        screen_index = screen.index
      }
    else
      return false, error_msg
    end
  end
  
  -- Store in global for other tests
  _G.test_tag_mapper = tag_mapper
  
  return "✓ Tag mapper functions set up successfully"
]])

if success then
  print("✓", result)
else
  print("✗ Setup failed:", result)
  os.exit(1)
end
print()

-- Test 3: Tag resolution with different specifications
print("Test 3: Tag Resolution Testing")
print("------------------------------")

local test_specs = {
  { spec = 0, desc = "Current tag" },
  { spec = 2, desc = "Current + 2" },
  { spec = -1, desc = "Current - 1" },
  { spec = "3", desc = "Absolute tag 3" },
  { spec = "test_tag", desc = "Named tag 'test_tag'" },
  { spec = 99, desc = "Invalid relative (+99)" },
  { spec = "999", desc = "Invalid absolute (999)" },
}

for _, test in ipairs(test_specs) do
  print(string.format("Testing: %s (%s)", tostring(test.spec), test.desc))

  local lua_code = [[
    local awful = require("awful")
    local screen = awful.screen.focused()
    local tag_spec = ]] .. (type(test.spec) == "string" and '"' .. test.spec .. '"' or tostring(
    test.spec
  )) .. [[
    local success, result = _G.test_tag_mapper.dry_run_tag_resolution(tag_spec, screen)
    
    if success then
      local info = result
      return "✓ " .. info.action .. ": " .. info.tag_name .. 
             " (index: " .. info.tag_index .. ", screen: " .. info.screen_index .. ")"
    else
      return "✗ " .. result
    end
  ]]

  success, result = exec_in_awesome(lua_code)

  if success then
    print("  " .. result)
  else
    print("  ✗ Test failed:", result)
  end
end
print()

-- Test 4: Integration with spawn - resolve then spawn
print("Test 4: Integrated Tag Resolution + Spawn")
print("-----------------------------------------")

local spawn_tests = {
  { app = "xterm", tag_spec = 0, desc = "Current tag" },
  { app = "xterm", tag_spec = "integration_test", desc = "New named tag" },
}

for _, test in ipairs(spawn_tests) do
  print(
    string.format(
      "Spawning %s to %s (%s)",
      test.app,
      tostring(test.tag_spec),
      test.desc
    )
  )

  local lua_code = [[
    local awful = require("awful")
    local screen = awful.screen.focused()
    local tag_spec = ]] .. (type(test.tag_spec) == "string" and '"' .. test.tag_spec .. '"' or tostring(
    test.tag_spec
  )) .. [[
    local app = "]] .. test.app .. [["
    
    -- Step 1: Resolve tag
    local tag, error_msg = _G.test_tag_mapper.resolve_tag_spec(tag_spec, screen)
    
    if not tag then
      -- Try to create if it's a named tag
      if type(tag_spec) == "string" and not tag_spec:match("^%d+$") then
        tag = _G.test_tag_mapper.create_named_tag(tag_spec, screen)
      end
    end
    
    if not tag then
      return "ERROR: Tag resolution failed: " .. (error_msg or "Unknown error")
    end
    
    -- Step 2: Spawn with resolved tag
    local pid, snid = awful.spawn(app, {tag = tag})
    
    if type(pid) == "string" then
      return "ERROR: Spawn failed: " .. pid
    else
      return "SUCCESS: PID=" .. pid .. ", SNID=" .. (snid or "nil") .. 
             ", Tag=" .. (tag.name or "unnamed") .. "(" .. tag.index .. ")"
    end
  ]]

  success, result = exec_in_awesome(lua_code)

  if success then
    print("  " .. result)
  else
    print("  ✗ Integration test failed:", result)
  end
end
print()

-- Test 5: Performance measurement
print("Test 5: Performance Measurement")
print("-------------------------------")

success, result = exec_in_awesome([[
  local awful = require("awful")
  local screen = awful.screen.focused()
  local start_time = os.clock()
  
  -- Measure tag resolution performance
  local resolution_count = 0
  local spawn_count = 0
  
  -- Test multiple tag resolutions
  for i = 1, 10 do
    local tag, error_msg = _G.test_tag_mapper.resolve_tag_spec(0, screen)  -- Current tag
    if tag then
      resolution_count = resolution_count + 1
    end
  end
  
  local resolution_time = os.clock() - start_time
  
  -- Test spawn + resolution (using echo to avoid window clutter)
  start_time = os.clock()
  for i = 1, 3 do
    local tag, error_msg = _G.test_tag_mapper.resolve_tag_spec(0, screen)
    if tag then
      local pid, snid = awful.spawn("echo 'performance_test_" .. i .. "'", {tag = tag})
      if type(pid) == "number" then
        spawn_count = spawn_count + 1
      end
    end
  end
  
  local spawn_time = os.clock() - start_time
  
  return string.format("Resolutions: %d/10 in %.3fs (%.3fs each)\nSpawns: %d/3 in %.3fs (%.3fs each)",
    resolution_count, resolution_time, resolution_time/10,
    spawn_count, spawn_time, spawn_time/3)
]])

if success then
  print("Performance results:")
  print(result)
else
  print("✗ Performance test failed:", result)
end
print()

print("=== Experiment 2.1 Complete ===")
print()
print("Summary:")
print("- Test tag mapper integration patterns")
print("- Verify dry-run capabilities work in AwesomeWM context")
print("- Measure performance of tag resolution + spawn operations")
print("- Validate error handling for various tag specifications")
print("- Explore integration patterns for production implementation")
print()
