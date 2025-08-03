--[[
Error Classification Module

This module provides error classification functionality, categorizing
error messages into specific types for better error handling and
user experience.

Features:
- Error type constants for consistent classification
- Pattern-based error message classification
- User-friendly error message generation
- Dependency injection support
--]]

local classifier_factory = {}

-- Error classification constants
local ERROR_TYPES = {
  COMMAND_NOT_FOUND = "COMMAND_NOT_FOUND",
  PERMISSION_DENIED = "PERMISSION_DENIED",
  INVALID_COMMAND = "INVALID_COMMAND",
  TIMEOUT = "TIMEOUT",
  DEPENDENCY_FAILED = "DEPENDENCY_FAILED",
  TAG_RESOLUTION_FAILED = "TAG_RESOLUTION_FAILED",
  UNKNOWN = "UNKNOWN",
}

-- Classify error message into error type
local function classify_error(error_message)
  if not error_message or type(error_message) ~= "string" then
    return ERROR_TYPES.UNKNOWN, "No error message provided"
  end

  local msg_lower = error_message:lower()

  if msg_lower:find("no such file or directory") then
    return ERROR_TYPES.COMMAND_NOT_FOUND, "Command not found in PATH"
  elseif msg_lower:find("permission denied") then
    return ERROR_TYPES.PERMISSION_DENIED, "Insufficient permissions to execute"
  elseif
    msg_lower:find("no command to execute") or error_message:match("^%s*$")
  then
    return ERROR_TYPES.INVALID_COMMAND, "Empty or invalid command"
  elseif msg_lower:find("timeout") then
    return ERROR_TYPES.TIMEOUT, "Operation timed out"
  elseif msg_lower:find("tag resolution failed") then
    return ERROR_TYPES.TAG_RESOLUTION_FAILED,
      "Could not resolve tag specification"
  else
    return ERROR_TYPES.UNKNOWN, "Unclassified error: " .. error_message
  end
end

-- Create classifier instance with dependency injection
function classifier_factory.create(interface)
  interface = interface or require("awe").interfaces.awesome_interface

  return {
    ERROR_TYPES = ERROR_TYPES,
    classify_error = classify_error,
  }
end

return classifier_factory
