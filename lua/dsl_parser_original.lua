local lfs = require("lfs")
local P = require("pl.path")
local F = require("pl.file")

local dsl_parser = {}

-- Safe environment for loading DSL files
local function create_dsl_env()
  -- Create a sandboxed environment with only safe functions
  local env = {
    -- Basic Lua functions that are safe
    pairs = pairs,
    ipairs = ipairs,
    next = next,
    type = type,
    tostring = tostring,
    tonumber = tonumber,
    table = table,
    string = string,
    math = math,

    -- DSL helper functions
    app = function(spec)
      return {
        type = "app",
        cmd = spec.cmd,
        dir = spec.dir,
        tag = spec.tag or 0,
      }
    end,
  }
  return env
end

-- Count keys in a table (since vim.tbl_keys is not available)
local function count_table_keys(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end

-- Load and safely execute a DSL file
function dsl_parser.load_dsl_file(filepath)
  if not filepath or filepath == "" then
    return false, "file path is required"
  end

  -- Check if file exists
  if not P.exists(filepath) then
    return false, "file not found: " .. filepath
  end

  content = F.read(filepath)

  return dsl_parser.compile_dsl(content, filepath)
end

function dsl_parser.compile_dsl(dsl_string, filepath)
  -- Compile the Lua code
  local chunk, compile_err =
    -- selene: allow(incorrect_standard_library_use)
    load(dsl_string, "@" .. filepath, "t", create_dsl_env())
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

-- Validate DSL structure
function dsl_parser.validate_dsl(dsl)
  if not dsl then
    return false, "DSL is required"
  end

  if type(dsl) ~= "table" then
    return false, "DSL must be a table"
  end

  -- Check required fields
  if not dsl.name then
    return false, "name field is required"
  end

  if type(dsl.name) ~= "string" then
    return false, "name must be a string"
  end

  if not dsl.resources then
    return false, "resources field is required"
  end

  if type(dsl.resources) ~= "table" then
    return false, "resources must be a table"
  end

  -- Check that resources table is not empty
  local resource_count = count_table_keys(dsl.resources)
  if resource_count == 0 then
    return false, "at least one resource is required"
  end

  return true, nil
end

-- Parse app helper specification
function dsl_parser.parse_app_helper(app_spec)
  if not app_spec then
    return false, "app spec is required"
  end

  if type(app_spec) ~= "table" then
    return false, "app spec must be a table"
  end

  -- Validate required fields
  if not app_spec.cmd then
    return false, "cmd field is required"
  end

  if type(app_spec.cmd) ~= "string" then
    return false, "cmd must be a string"
  end

  -- Validate optional fields
  if app_spec.dir and type(app_spec.dir) ~= "string" then
    return false, "dir must be a string"
  end

  if app_spec.tag and type(app_spec.tag) ~= "number" then
    return false, "tag must be a number"
  end

  -- Create normalized resource spec
  local resource = {
    type = "app",
    cmd = app_spec.cmd,
    dir = app_spec.dir,
    tag = app_spec.tag or 0,
  }

  return true, resource
end

---Resolve project name to config file path
---Returns the full path to the project configuration file or false, error message
---@param project_name? string
---@param home string|nil
---@return string|false, string|nil
function dsl_parser.resolve_config_path(project_name, home)
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

return dsl_parser
