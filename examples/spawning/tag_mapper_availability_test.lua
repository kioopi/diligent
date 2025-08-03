#!/usr/bin/env lua
--[[
Tag Mapper Module Availability Test

This script tests which tag_mapper modules are available in AwesomeWM context.
Used as baseline test before/after rockspec modifications.

Usage: lua examples/spawning/tag_mapper_availability_test.lua
--]]

-- Add project paths
package.path = package.path .. ";lua/?.lua"
local dbus_comm = require("dbus_communication")

print("=== Tag Mapper Module Availability Test ===")
print()

-- Helper function to execute Lua code in AwesomeWM
local function exec_in_awesome(code)
  local success, result = dbus_comm.execute_in_awesome(code, 10000)
  return success, result
end

-- Check if AwesomeWM is available
if not dbus_comm.check_awesome_available() then
  print(
    "✗ AwesomeWM not available via D-Bus. Make sure AwesomeWM is running."
  )
  os.exit(1)
end

print("✓ AwesomeWM is available via D-Bus")
print()

-- Test 1: Check core diligent modules (should be available)
print("Test 1: Core Diligent Modules (Expected: Available)")
print("---------------------------------------------------")

local core_modules = {
  "diligent",
  "json_utils",
  "cli_printer",
  "dbus_communication",
  "commands.ping",
}

for _, module_name in ipairs(core_modules) do
  local success, result = exec_in_awesome(string.format(
    [[
    local success, module = pcall(require, "%s")
    if success then
      return "AVAILABLE: " .. type(module)
    else
      return "NOT_FOUND: " .. tostring(module)
    end
  ]],
    module_name
  ))

  if success then
    print(string.format("  %-20s %s", module_name .. ":", result))
  else
    print(string.format("  %-20s ERROR: %s", module_name .. ":", result))
  end
end
print()

-- Test 2: Check diligent submodules (some should be available)
print("Test 2: Diligent Submodules")
print("---------------------------")

local diligent_submodules = {
  "diligent.utils",
  "diligent.handlers.ping",
  "diligent.handlers.spawn_test",
  "diligent.handlers.kill_test",
}

for _, module_name in ipairs(diligent_submodules) do
  local success, result = exec_in_awesome(string.format(
    [[
    local success, module = pcall(require, "%s")
    if success then
      return "AVAILABLE: " .. type(module)
    else
      return "NOT_FOUND: " .. tostring(module)
    end
  ]],
    module_name
  ))

  if success then
    print(string.format("  %-25s %s", module_name .. ":", result))
  else
    print(string.format("  %-25s ERROR: %s", module_name .. ":", result))
  end
end
print()

-- Test 3: Check tag_mapper modules (expected: NOT available)
print("Test 3: Tag Mapper Modules (Expected: NOT Available)")
print("-----------------------------------------------------")

local tag_mapper_modules = {
  "tag_mapper.core",
  "tag_mapper.integration",
  "tag_mapper.interfaces.awesome_interface",
  "tag_mapper.interfaces.dry_run_interface",
}

local available_count = 0
local total_count = #tag_mapper_modules

for _, module_name in ipairs(tag_mapper_modules) do
  local success, result = exec_in_awesome(string.format(
    [[
    local success, module = pcall(require, "%s")
    if success then
      return "AVAILABLE: " .. type(module)
    else
      return "NOT_FOUND: " .. tostring(module)
    end
  ]],
    module_name
  ))

  if success then
    if result:match("AVAILABLE:") then
      available_count = available_count + 1
    end
    print(string.format("  %-35s %s", module_name .. ":", result))
  else
    print(string.format("  %-35s ERROR: %s", module_name .. ":", result))
  end
end
print()

-- Test 4: Test tag_mapper functionality if available
print("Test 4: Tag Mapper Functionality Test")
print("-------------------------------------")

if available_count > 0 then
  print(
    string.format(
      "Found %d/%d tag_mapper modules available. Testing functionality...",
      available_count,
      total_count
    )
  )

  local success, result = exec_in_awesome([[
    local success, integration = pcall(require, "tag_mapper.integration")
    if not success then
      return "ERROR: tag_mapper.integration not available: " .. tostring(integration)
    end
    
    local awful = require("awful")
    local screen = awful.screen.focused()
    
    -- Test basic tag resolution
    local resolve_success, tag_or_error = integration.resolve_and_get_tag(0, screen)
    if resolve_success then
      local tag = tag_or_error
      return string.format("SUCCESS: Resolved current tag to '%s' (index: %d)", 
        tag.name or "unnamed", tag.index)
    else
      return "ERROR: Tag resolution failed: " .. tostring(tag_or_error)
    end
  ]])

  if success then
    print("  " .. result)
  else
    print("  ERROR: Functionality test failed: " .. result)
  end
else
  print("No tag_mapper modules available - functionality test skipped")
end
print()

-- Test 5: Module search path analysis
print("Test 5: Module Search Path Analysis")
print("-----------------------------------")

local success, result = exec_in_awesome([[
  -- Show package.path to understand module loading
  local paths = {}
  for path in string.gmatch(package.path, "[^;]+") do
    table.insert(paths, path)
  end
  
  return "Lua module search paths:\n" .. table.concat(paths, "\n")
]])

if success then
  print(result)
else
  print("ERROR: Failed to get search paths: " .. result)
end
print()

-- Summary
print("=== Test Summary ===")
print()
print(
  string.format(
    "Tag Mapper Module Availability: %d/%d modules found",
    available_count,
    total_count
  )
)

if available_count == 0 then
  print("✗ BASELINE: No tag_mapper modules available (expected)")
  print("  Next step: Update rockspec to include tag_mapper modules")
elseif available_count == total_count then
  print("✓ SUCCESS: All tag_mapper modules available!")
  print("  Rockspec modifications were successful")
else
  print("⚠ PARTIAL: Some tag_mapper modules available")
  print(
    string.format(
      "  %d missing modules need to be added to rockspec",
      total_count - available_count
    )
  )
end

print()
print("Use this script after rockspec changes to verify module availability.")
