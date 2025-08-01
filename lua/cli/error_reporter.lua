--[[
CLI Error Reporter Module

Handles standardized error reporting with proper exit codes.
Provides consistent error message formatting and Unix-compliant exit codes.
--]]

local error_reporter = {}

-- Import CLI printer for consistent output
local cli_printer = require("cli_printer")

-- Exit code constants (Unix conventions)
error_reporter.EXIT_SUCCESS = 0
error_reporter.EXIT_VALIDATION_ERROR = 1
error_reporter.EXIT_INVALID_ARGS = 1
error_reporter.EXIT_FILE_NOT_FOUND = 2

-- Error type constants
error_reporter.ERROR_VALIDATION = "validation_error"
error_reporter.ERROR_FILE_NOT_FOUND = "file_not_found"
error_reporter.ERROR_PROJECT_NOT_FOUND = "project_not_found"
error_reporter.ERROR_INVALID_ARGS = "invalid_args"

---Check if a value is empty (nil or empty string)
---@param value any Value to check
---@return boolean true if value is nil or empty string
local function is_empty(value)
  return value == nil or (type(value) == "string" and value == "")
end

---Get exit code for error type
---@param error_type string Error type constant
---@return number exit_code Appropriate exit code
function error_reporter.get_exit_code(error_type)
  if
    error_type == error_reporter.ERROR_FILE_NOT_FOUND
    or error_type == error_reporter.ERROR_PROJECT_NOT_FOUND
  then
    return error_reporter.EXIT_FILE_NOT_FOUND
  elseif error_type == error_reporter.ERROR_INVALID_ARGS then
    return error_reporter.EXIT_INVALID_ARGS
  else
    -- Default to validation error for unknown types
    return error_reporter.EXIT_VALIDATION_ERROR
  end
end

---Format error message based on error type
---@param message string|nil Error message
---@param error_type string|nil Error type for context
---@return string formatted_message Formatted error message
function error_reporter.format_error_message(message, error_type)
  local msg = message

  if is_empty(msg) then
    msg = "Unknown error"
  end

  if error_type == error_reporter.ERROR_VALIDATION then
    return "Validation failed:\n  " .. msg
  elseif error_type == error_reporter.ERROR_FILE_NOT_FOUND then
    return msg
  elseif error_type == error_reporter.ERROR_PROJECT_NOT_FOUND then
    return msg
  elseif error_type == error_reporter.ERROR_INVALID_ARGS then
    return msg
  else
    return msg
  end
end

---Report error with consistent formatting and return exit code
---@param message string|nil Error message to display
---@param error_type string Error type constant
---@return number exit_code Exit code for the error type
function error_reporter.report_error(message, error_type)
  local formatted_message =
    error_reporter.format_error_message(message, error_type)
  local exit_code = error_reporter.get_exit_code(error_type)

  -- Print error using cli_printer for consistent formatting
  if formatted_message:match("\n") then
    -- Multi-line error message
    local lines = {}
    for line in formatted_message:gmatch("[^\n]+") do
      table.insert(lines, line)
    end
    for _, line in ipairs(lines) do
      cli_printer.error(line)
    end
  else
    cli_printer.error(formatted_message)
  end

  return exit_code
end

---Report error and exit with appropriate code
---@param message string|nil Error message to display
---@param error_type string Error type constant
function error_reporter.report_and_exit(message, error_type)
  local exit_code = error_reporter.report_error(message, error_type)
  os.exit(exit_code)
end

return error_reporter
