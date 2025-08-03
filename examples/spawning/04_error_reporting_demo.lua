#!/usr/bin/env lua
--[[
Error Reporting Framework Demo

This script demonstrates the error reporting and classification capabilities
added to the awesome_client_manager module.

Usage: lua examples/spawning/04_error_reporting_demo.lua
--]]

-- Add project paths
package.path = package.path .. ";lua/?.lua"
local dbus_comm = require("dbus_communication")

print("=== Error Reporting Framework Demo ===")
print()

-- Helper function to execute Lua code in AwesomeWM and capture results
local function exec_in_awesome(code)
  local success, result = dbus_comm.execute_in_awesome(code, 5000)
  return success, result
end

-- Test the error reporting framework
print("Testing Error Reporting Framework...")

local success, result = exec_in_awesome([[
  -- Load the awesome_client_manager module
  local success, acm = pcall(require, "awesome_client_manager")
  if not success then
    return "ERROR: Failed to load awesome_client_manager: " .. tostring(acm)
  end
  
  -- Test error classification
  local test_errors = {
    "Failed to execute child process \"nonexistentapp\" (No such file or directory)",
    "Failed to execute child process \"/etc/passwd\" (Permission denied)",
    "Error: No command to execute",
    "Tag resolution failed: invalid tag spec",
    "Some unknown error message"
  }
  
  local classification_results = {}
  for i, error_msg in ipairs(test_errors) do
    local error_type, user_message = acm.classify_error(error_msg)
    table.insert(classification_results, string.format(
      "Test %d: %s -> %s (%s)", 
      i, error_type, user_message, error_msg:sub(1, 40) .. "..."
    ))
  end
  
  -- Test error report creation
  local error_report = acm.create_error_report(
    "nonexistentapp", 
    "0", 
    "Failed to execute child process \"nonexistentapp\" (No such file or directory)",
    {config = {floating = true}}
  )
  
  -- Test spawn with error reporting
  local spawn_results = {}
  local test_apps = {"invalidapp1", "invalidapp2", "xterm"}
  
  for _, app in ipairs(test_apps) do
    local result = acm.spawn_with_error_reporting(app, "0", {})
    table.insert(spawn_results, result)
  end
  
  -- Create summary
  local summary = acm.create_spawn_summary(spawn_results)
  
  -- Format results for display
  local report = {}
  table.insert(report, "=== CLASSIFICATION TESTS ===")
  for _, result in ipairs(classification_results) do
    table.insert(report, result)
  end
  
  table.insert(report, "")
  table.insert(report, "=== ERROR REPORT SAMPLE ===")
  table.insert(report, "App: " .. error_report.app_name)
  table.insert(report, "Error Type: " .. error_report.error_type)  
  table.insert(report, "User Message: " .. error_report.user_message)
  table.insert(report, "Suggestions: " .. #error_report.suggestions .. " provided")
  
  table.insert(report, "")
  table.insert(report, "=== SPAWN SUMMARY ===")
  table.insert(report, string.format("Total: %d, Success: %d, Failed: %d (%.1f%% success rate)",
    summary.total_attempts, summary.successful, summary.failed, summary.success_rate * 100))
  
  table.insert(report, "Error types found:")
  for error_type, count in pairs(summary.error_types) do
    table.insert(report, "  " .. error_type .. ": " .. count)
  end
  
  if #summary.recommendations > 0 then
    table.insert(report, "Recommendations:")
    for _, rec in ipairs(summary.recommendations) do
      table.insert(report, "  - " .. rec)
    end
  end
  
  -- Test user-friendly formatting
  table.insert(report, "")
  table.insert(report, "=== USER-FRIENDLY ERROR FORMAT ===")
  for _, result in ipairs(spawn_results) do
    if not result.success then
      local formatted = acm.format_error_for_user(result.error_report)
      table.insert(report, formatted)
      table.insert(report, "")
    end
  end
  
  return table.concat(report, "\n")
]])

if success then
  print("✓ Error reporting framework test:")
  print(result)
else
  print("✗ Error reporting test failed:", result)
end

print()
print("=== Demo Complete ===")
print()
print("The error reporting framework provides:")
print("1. Automatic error classification")
print("2. User-friendly error messages") 
print("3. Actionable suggestions")
print("4. Aggregate reporting")
print("5. Production-ready error handling")