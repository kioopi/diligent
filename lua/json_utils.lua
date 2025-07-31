--[[
JSON Utilities Module for Diligent

Provides centralized JSON encoding and decoding functionality to eliminate
code duplication across the codebase. Uses dkjson internally while providing
a consistent error handling interface.

All functions return (success, result_or_error) pattern for consistency
with the rest of the codebase.
--]]

local json_utils = {}

local dkjson = require("dkjson")

-- Encode Lua table to JSON string
-- Returns: success (boolean), result_or_error (string)
function json_utils.encode(data)
  if data == nil then
    return false, "input is required"
  end

  local success, result = pcall(dkjson.encode, data)
  if not success then
    return false, "JSON encoding error: " .. (result or "unknown error")
  end

  return true, result
end

-- Decode JSON string to Lua table
-- Returns: success (boolean), result_or_error (table|string)
function json_utils.decode(json_string)
  if json_string == nil or json_string == "" then
    return false, "input is required"
  end

  if type(json_string) ~= "string" then
    return false, "input must be a string"
  end

  local data, err = dkjson.decode(json_string)
  if not data then
    return false, "JSON parsing error: " .. (err or "invalid JSON")
  end

  return true, data
end

return json_utils
