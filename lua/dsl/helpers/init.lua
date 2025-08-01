--[[
Helper Registry System

Manages registration and loading of DSL helper functions.  
Provides the sandboxed environment for DSL execution with all available helpers.
--]]

local helpers = {}

-- Registry of available helper functions
local registry = {}

-- Load built-in helpers
local app_helper = require("dsl.helpers.app")

-- Register built-in helpers
registry.app = function(spec)
  return app_helper.create(spec)
end

---Register a helper function
---@param name string Helper name (must be valid Lua identifier)
---@param helper_function function Function that creates resource spec
function helpers.register(name, helper_function)
  if not name or name == "" then
    error("helper name is required")
  end

  if type(name) ~= "string" then
    error("helper name must be a string")
  end

  if not name:match("^[a-zA-Z][a-zA-Z0-9_]*$") then
    error("helper name must be a valid Lua identifier: " .. name)
  end

  if type(helper_function) ~= "function" then
    error("helper must be a function")
  end

  if registry[name] then
    error("helper '" .. name .. "' is already registered")
  end

  registry[name] = helper_function
end

---Get registered helper function
---@param name string Helper name
---@return function|nil helper Helper function or nil if not found
function helpers.get(name)
  return registry[name]
end

---List all registered helper names
---@return table helper_names Array of registered helper names
function helpers.list()
  local names = {}
  for name, _ in pairs(registry) do
    table.insert(names, name)
  end
  table.sort(names) -- Consistent ordering
  return names
end

---Get helper schema for validation
---@param name string Helper name
---@return table|nil schema Helper schema or nil if not found
function helpers.get_schema(name)
  if name == "app" then
    return app_helper.schema
  end

  -- Future helpers would be added here
  -- if name == "term" then
  --   return term_helper.schema
  -- end

  return nil
end

---Validate resource spec using appropriate helper
---@param resource_spec table Resource specification to validate
---@param resource_type string Type of resource (app, term, etc.)
---@return boolean success True if validation passed
---@return string|nil error Error message if validation failed
function helpers.validate_resource(resource_spec, resource_type)
  if resource_type == "app" then
    return app_helper.validate(resource_spec)
  end

  -- Future helper validation would be added here
  -- if resource_type == "term" then
  --   return term_helper.validate(resource_spec)
  -- end

  return false, "unknown resource type: " .. tostring(resource_type)
end

---Create sandboxed environment with all registered helpers
---@return table env Sandboxed environment table
function helpers.create_env()
  -- Base safe environment
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
  }

  -- Add all registered helpers
  for name, helper_function in pairs(registry) do
    env[name] = helper_function
  end

  return env
end

---Clear registry (primarily for testing)
function helpers._clear_registry()
  registry = {}

  -- Re-register built-in helpers
  registry.app = function(spec)
    return app_helper.create(spec)
  end
end

return helpers
