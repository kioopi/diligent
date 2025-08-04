--[[
Error Formatting Module

This module provides user-friendly error formatting functionality,
converting structured error reports into readable output for
different contexts (CLI, logs, etc.).

Features:
- User-friendly error message formatting
- Multi-format output support (CLI, JSON, etc.)
- Graceful handling of incomplete error data
- Dependency injection support
--]]

local formatter_factory = {}

-- Format error report for user display
local function format_error_for_user(error_report)
  if not error_report then
    return "Unknown error occurred"
  end

  local lines = {}
  table.insert(
    lines,
    "✗ Failed to spawn " .. (error_report.app_name or "application")
  )

  if error_report.user_message then
    table.insert(lines, "  Error: " .. error_report.user_message)
  end

  if error_report.suggestions and #error_report.suggestions > 0 then
    table.insert(lines, "  Suggestions:")
    for _, suggestion in ipairs(error_report.suggestions) do
      table.insert(lines, "    • " .. suggestion)
    end
  end

  return table.concat(lines, "\n")
end

-- Create formatter instance with dependency injection
function formatter_factory.create(interface)
  interface = interface or require("awe").interfaces.awesome_interface

  return {
    format_error_for_user = format_error_for_user,
  }
end

return formatter_factory
