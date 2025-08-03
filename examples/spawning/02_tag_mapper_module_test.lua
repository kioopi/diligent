#!/usr/bin/env lua
--[[
Test: Tag Mapper Module Availability after Rockspec Update

This test checks if adding tag_mapper to the rockspec makes it available 
in the AwesomeWM context when using require() via dbus_communication.

We're testing whether just adding the main module is sufficient, or if 
we need all sub-modules registered.
--]]

-- Add project paths
package.path = package.path .. ";lua/?.lua"
local dbus_comm = require("dbus_communication")

print("=== Test: Tag Mapper Module Availability ===")
print()

-- Helper function to execute Lua code in AwesomeWM
local function exec_in_awesome(code)
  local success, result = dbus_comm.execute_in_awesome(code, 10000)
  return success, result
end

-- Test 1: Try to require the main tag_mapper module
print("Test 1: Require main tag_mapper module")
print("--------------------------------------")

local success, result = exec_in_awesome([[
  local success, tag_mapper = pcall(require, "tag_mapper")
  if success then
    return "✓ tag_mapper module loaded successfully"
  else
    return "✗ Failed to load tag_mapper: " .. tostring(tag_mapper)
  end
]])

if success then
  print(result)
  local tag_mapper_available = result:match("✓")

  if tag_mapper_available then
    print()
    print("🎉 SUCCESS: tag_mapper is available in AwesomeWM!")
    print()

    -- Test 2: Try to use tag_mapper functions
    print("Test 2: Test tag_mapper functionality")
    print("------------------------------------")

    success, result = exec_in_awesome([[
      local tag_mapper = require("tag_mapper")
      
      -- Test get_current_tag function
      local current_tag = tag_mapper.get_current_tag()
      
      -- Test resolve_tag function with current tag (0 offset)
      local success, resolved_tag = tag_mapper.resolve_tag(0, current_tag)
      
      if success then
        return "✓ tag_mapper.resolve_tag() works - Current tag: " .. 
               tostring(current_tag) .. ", Resolved: " .. tostring(resolved_tag.index or resolved_tag.name)
      else
        return "✗ tag_mapper.resolve_tag() failed: " .. tostring(resolved_tag)
      end
    ]])

    if success then
      print(result)
    else
      print("✗ Functionality test failed:", result)
    end
  else
    print()
    print("❌ FAILED: tag_mapper is not available - need to add sub-modules")
  end
else
  print("✗ Test execution failed:", result)
end

print()
print("=== Test Complete ===")
