--[[
DSL Public API Interface

Main entry point for DSL operations. Coordinates parser and validator modules
to provide a clean, consistent interface for loading and validating DSL files.
--]]

local parser = require("dsl.parser")
local validator = require("dsl.validator")

local dsl = {}

---Load DSL file and validate it
---@param filepath string Path to DSL file
---@return boolean success True if loading and validation succeeded
---@return table|string result DSL table or error message
function dsl.load_and_validate(filepath)
  -- Load and parse DSL file
  local load_success, dsl_or_error = parser.load_dsl_file(filepath)
  if not load_success then
    return false, dsl_or_error
  end

  -- Validate DSL structure
  local validate_success, validate_error = validator.validate_dsl(dsl_or_error)
  if not validate_success then
    return false, validate_error
  end

  return true, dsl_or_error
end

---Load DSL from string and validate it
---@param dsl_string string DSL code to compile
---@param filepath string|nil Source file path (for error context)
---@return boolean success True if compilation and validation succeeded
---@return table|string result DSL table or error message
function dsl.compile_and_validate(dsl_string, filepath)
  -- Compile DSL string
  local compile_success, dsl_or_error = parser.compile_dsl(dsl_string, filepath)
  if not compile_success then
    return false, dsl_or_error
  end

  -- Validate DSL structure
  local validate_success, validate_error = validator.validate_dsl(dsl_or_error)
  if not validate_success then
    return false, validate_error
  end

  return true, dsl_or_error
end

---Validate pre-loaded DSL table
---@param dsl_table table DSL table to validate
---@return boolean success True if validation passed
---@return string|nil error Error message if validation failed
function dsl.validate(dsl_table)
  return validator.validate_dsl(dsl_table)
end

---Get detailed validation summary for human-readable output
---@param dsl_table table DSL table to analyze
---@return table summary Validation summary with details
function dsl.get_validation_summary(dsl_table)
  return validator.get_validation_summary(dsl_table)
end

---Resolve project name to config file path
---@param project_name string Name of the project
---@param home string|nil Home directory path (defaults to $HOME)
---@return string|false path Config file path or false on error
---@return string|nil error Error message if resolution failed
function dsl.resolve_config_path(project_name, home)
  return parser.resolve_config_path(project_name, home)
end

---Load project by name (resolves path and loads DSL)
---@param project_name string Name of the project
---@param home string|nil Home directory path (defaults to $HOME)
---@return boolean success True if loading succeeded
---@return table|string result DSL table or error message
function dsl.load_project(project_name, home)
  -- Resolve project path
  local config_path, path_error = dsl.resolve_config_path(project_name, home)
  if not config_path then
    return false, path_error
  end

  -- Load and validate DSL
  return dsl.load_and_validate(config_path)
end

-- Export internal modules for advanced usage
dsl.parser = parser
dsl.validator = validator

-- Export helper system for extensibility
dsl.helpers = require("dsl.helpers.init")

-- Export tag specification parser
dsl.tag_spec = require("dsl.tag_spec")

return dsl
