--[[
DSL Parser - Core parsing and compilation

Handles loading DSL files from filesystem, compiling them in a sandboxed 
environment, and executing them safely. Migrated from existing dsl_parser.lua
with improvements for modular architecture.
--]]

-- local lfs = require("lfs") -- Not needed for new parser
local P = require("pl.path")
local F = require("pl.file")
local helpers = require("dsl.helpers.init")

local parser = {}

---Load and safely execute a DSL file
---@param filepath string Path to DSL file
---@return boolean success True if loading succeeded
---@return table|string result DSL table or error message
function parser.load_dsl_file(filepath)
  if not filepath or filepath == "" then
    return false, "file path is required"
  end

  -- Check if file exists
  if not P.exists(filepath) then
    return false, "file not found: " .. filepath
  end

  local content = F.read(filepath)
  if not content then
    return false, "failed to read file: " .. filepath
  end

  return parser.compile_dsl(content, filepath)
end

---Compile DSL string with sandboxed environment
---@param dsl_string string DSL code to compile
---@param filepath string Source file path (for error context)
---@return boolean success True if compilation succeeded
---@return table|string result DSL table or error message
function parser.compile_dsl(dsl_string, filepath)
  if not dsl_string then
    return false, "DSL string is required"
  end

  filepath = filepath or "<string>"

  -- Create sandboxed environment
  local env = parser.create_dsl_env()

  -- Compile the Lua code
  local chunk, compile_err =
    -- selene: allow(incorrect_standard_library_use)
    load(dsl_string, "@" .. filepath, "t", env)
  if not chunk then
    return false, "syntax error: " .. (compile_err or "unknown error")
  end

  -- Execute the chunk safely
  local success, result = pcall(chunk)
  if not success then
    return false, "execution error: " .. (result or "unknown error")
  end

  -- Ensure the result is a table
  if type(result) ~= "table" then
    return false, "DSL file must return a table, got " .. type(result)
  end

  return true, result
end

---Create sandboxed environment for DSL execution
---@return table env Sandboxed environment with helper functions
function parser.create_dsl_env()
  -- Delegate to helper registry for consistent environment
  return helpers.create_env()
end

---Resolve project name to config file path
---Migrated from existing dsl_parser.lua for compatibility
---@param project_name string Name of the project
---@param home string|nil Home directory path (defaults to $HOME)
---@return string|false path Config file path or false on error
---@return string|nil error Error message if resolution failed
function parser.resolve_config_path(project_name, home)
  home = home or os.getenv("HOME")

  if not home then
    return false, "HOME environment variable is not set"
  end

  if not project_name or project_name == "" then
    return false, "project name is required"
  end

  local project_dir = P.join(home, ".config", "diligent", "projects")

  if not P.exists(project_dir) then
    return false, "project directory does not exist: " .. project_dir
  end

  local config_file = P.join(project_dir, project_name .. ".lua")

  if not P.exists(config_file) then
    return false, "project configuration file does not exist: " .. config_file
  end

  return config_file
end

return parser
