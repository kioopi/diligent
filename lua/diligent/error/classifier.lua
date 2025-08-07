--[[
Enhanced Error Classification Module

This module provides error classification functionality, categorizing
error messages into specific types for better error handling and
user experience. Enhanced with tag resolution error support.

Features:
- Error type constants for consistent classification
- Pattern-based error message classification
- User-friendly error message generation
- Tag resolution specific error types
--]]

local classifier_factory = {}

-- Enhanced error classification constants
local ERROR_TYPES = {
  -- Original error types
  COMMAND_NOT_FOUND = "COMMAND_NOT_FOUND",
  PERMISSION_DENIED = "PERMISSION_DENIED",
  INVALID_COMMAND = "INVALID_COMMAND",
  TIMEOUT = "TIMEOUT",
  DEPENDENCY_FAILED = "DEPENDENCY_FAILED",
  TAG_RESOLUTION_FAILED = "TAG_RESOLUTION_FAILED",
  UNKNOWN = "UNKNOWN",

  -- New tag resolution specific error types
  TAG_SPEC_INVALID = "TAG_SPEC_INVALID",
  TAG_OVERFLOW = "TAG_OVERFLOW",
  TAG_NAME_INVALID = "TAG_NAME_INVALID",
  MULTIPLE_TAG_ERRORS = "MULTIPLE_TAG_ERRORS",
}

-- Classify error message into error type
local function classify_error(error_message)
  if not error_message or type(error_message) ~= "string" then
    return ERROR_TYPES.UNKNOWN, "No error message provided"
  end

  local msg_lower = error_message:lower()

  -- Tag resolution specific errors (check these first for specificity)
  if
    msg_lower:find("tag overflow")
    or msg_lower:find("overflow.*tag")
    or msg_lower:find("tag.*index.*overflow")
  then
    return ERROR_TYPES.TAG_OVERFLOW, "Tag overflow"
  elseif
    msg_lower:find("invalid tag spec") or msg_lower:find("tag spec.*invalid")
  then
    return ERROR_TYPES.TAG_SPEC_INVALID, "Invalid tag specification"
  elseif
    msg_lower:find("invalid tag name")
    or msg_lower:find("tag name.*invalid")
    or msg_lower:find("tag name.*validation.*failed")
  then
    return ERROR_TYPES.TAG_NAME_INVALID, "Invalid tag name"
  elseif
    msg_lower:find("multiple.*tag.*error")
    or msg_lower:find("multiple.*error.*tag")
    or msg_lower:find("%d+.*error.*tag")
  then
    return ERROR_TYPES.MULTIPLE_TAG_ERRORS, "Multiple tag errors"
  elseif msg_lower:find("tag resolution failed") then
    return ERROR_TYPES.TAG_RESOLUTION_FAILED,
      "Could not resolve tag specification"

  -- Original error patterns
  elseif msg_lower:find("no such file or directory") then
    return ERROR_TYPES.COMMAND_NOT_FOUND, "Command not found in PATH"
  elseif msg_lower:find("permission denied") then
    return ERROR_TYPES.PERMISSION_DENIED, "Insufficient permissions to execute"
  elseif
    msg_lower:find("no command to execute") or error_message:match("^%s*$")
  then
    return ERROR_TYPES.INVALID_COMMAND, "Empty or invalid command"
  elseif msg_lower:find("timeout") then
    return ERROR_TYPES.TIMEOUT, "Operation timed out"
  else
    -- Check if it's likely a tag-related error even if pattern doesn't match
    if msg_lower:find("tag") then
      return ERROR_TYPES.TAG_RESOLUTION_FAILED,
        "Tag-related error: " .. error_message
    end
    return ERROR_TYPES.UNKNOWN, "Unclassified error: " .. error_message
  end
end

-- Create classifier instance with dependency injection
function classifier_factory.create(interface)
  return {
    ERROR_TYPES = ERROR_TYPES,
    classify_error = classify_error,
  }
end

return classifier_factory
