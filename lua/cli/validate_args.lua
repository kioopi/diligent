--[[
CLI Validate Arguments Module

Handles validation of CLI arguments for the validate command.
Provides standardized argument validation and error reporting.
--]]

local validate_args = {}

-- Constants for input types
validate_args.INPUT_TYPE_PROJECT = "project"
validate_args.INPUT_TYPE_FILE = "file"

-- Constants for error types
validate_args.ERROR_MISSING_INPUT = "missing_input"
validate_args.ERROR_CONFLICTING_INPUT = "conflicting_input"

---Check if a value is empty (nil or empty string)
---@param value any Value to check
---@return boolean true if value is nil or empty string
local function is_empty(value)
  return value == nil or (type(value) == "string" and value == "")
end

---Validate parsed CLI arguments
---@param args table Parsed arguments from cliargs
---@return boolean success True if validation succeeded
---@return table|string result Validated arguments or error message
function validate_args.validate_parsed_args(args)
  local project_name = args.PROJECT_NAME
  local file_path = args.file

  -- Check for empty values
  local has_project = not is_empty(project_name)
  local has_file = not is_empty(file_path)

  -- Validate argument combinations
  if not has_project and not has_file then
    return false, "Must provide either project name or --file option"
  end

  if has_project and has_file then
    return false, "Cannot use both project name and --file option"
  end

  -- Return validated arguments
  if has_project then
    return true,
      {
        input_type = validate_args.INPUT_TYPE_PROJECT,
        project_name = project_name,
        file_path = nil,
      }
  else
    return true,
      {
        input_type = validate_args.INPUT_TYPE_FILE,
        project_name = nil,
        file_path = file_path,
      }
  end
end

---Get error type for given arguments (for programmatic error handling)
---@param args table Parsed arguments from cliargs
---@return string|nil error_type Error type constant or nil if valid
function validate_args.get_error_type(args)
  local project_name = args.PROJECT_NAME
  local file_path = args.file

  -- Check for empty values
  local has_project = not is_empty(project_name)
  local has_file = not is_empty(file_path)

  if not has_project and not has_file then
    return validate_args.ERROR_MISSING_INPUT
  end

  if has_project and has_file then
    return validate_args.ERROR_CONFLICTING_INPUT
  end

  return nil -- Valid arguments
end

return validate_args
