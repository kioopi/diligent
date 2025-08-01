--[[
CLI Project Loader Module

Handles loading DSL projects by file path or project name.
Provides standardized error handling and file existence checking.
--]]

local project_loader = {}

-- Import DSL module
local dsl = require("dsl")

-- Constants for error types
project_loader.ERROR_FILE_NOT_FOUND = "file_not_found"
project_loader.ERROR_PROJECT_NOT_FOUND = "project_not_found"
project_loader.ERROR_VALIDATION_ERROR = "validation_error"

---Check if a value is empty (nil or empty string)
---@param value any Value to check
---@return boolean true if value is nil or empty string
local function is_empty(value)
  return value == nil or (type(value) == "string" and value == "")
end

---Check if file exists
---@param file_path string Path to file
---@return boolean true if file exists and is readable
function project_loader.file_exists(file_path)
  if is_empty(file_path) then
    return false
  end

  local file = io.open(file_path, "r")
  if file then
    file:close()
    return true
  end

  return false
end

---Load DSL project by file path
---@param file_path string Path to DSL file
---@return boolean success True if loading succeeded
---@return table|string result DSL table or error message
function project_loader.load_by_file_path(file_path)
  if is_empty(file_path) then
    return false, "file path is required"
  end

  -- Check if file exists
  if not project_loader.file_exists(file_path) then
    return false, "File not found: " .. file_path
  end

  -- Load and validate DSL file
  local success, result = dsl.load_and_validate(file_path)
  if not success then
    return false, result
  end

  return true, result
end

---Load DSL project by project name
---@param project_name string Name of the project
---@return boolean success True if loading succeeded
---@return table|string result DSL table or error message
function project_loader.load_by_project_name(project_name)
  if is_empty(project_name) then
    return false, "project name is required"
  end

  -- Load project using DSL module
  local success, result = dsl.load_project(project_name)
  if not success then
    -- Check if it's a "not found" error to provide better error message
    if
      result and (result:match("not found") or result:match("does not exist"))
    then
      return false, "Project not found: " .. project_name
    end
    return false, result
  end

  return true, result
end

---Get error type from error message (for programmatic error handling)
---@param error_msg string Error message
---@return string error_type Error type constant
function project_loader.get_error_type(error_msg)
  if not error_msg then
    return project_loader.ERROR_VALIDATION_ERROR
  end

  if error_msg:match("File not found") then
    return project_loader.ERROR_FILE_NOT_FOUND
  end

  if error_msg:match("Project not found") then
    return project_loader.ERROR_PROJECT_NOT_FOUND
  end

  return project_loader.ERROR_VALIDATION_ERROR
end

return project_loader
