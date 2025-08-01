--[[
DSL Validator - Schema validation logic

Enhanced validation for DSL structure and content with detailed error messages.
Validates DSL tables according to the specification and delegates resource 
validation to appropriate helpers.
--]]

local helpers = require("dsl.helpers.init")

local validator = {}

-- Count keys in a table (since vim.tbl_keys is not available)
local function count_table_keys(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end

---Validate DSL structure according to specification
---@param dsl table DSL table to validate
---@return boolean success True if validation passed
---@return string|nil error Error message if validation failed
function validator.validate_dsl(dsl)
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

  if dsl.name == "" then
    return false, "name cannot be empty"
  end

  if not dsl.resources then
    return false, "resources field is required"
  end

  if type(dsl.resources) ~= "table" then
    return false, "resources must be a table"
  end

  -- Validate resources
  local success, error_msg = validator.validate_resources(dsl.resources)
  if not success then
    return false, error_msg
  end

  -- Optional field validation
  if dsl.hooks then
    local hooks_success, hooks_error = validator.validate_hooks(dsl.hooks)
    if not hooks_success then
      return false, hooks_error
    end
  end

  if dsl.layouts then
    local layouts_success, layouts_error =
      validator.validate_layouts(dsl.layouts)
    if not layouts_success then
      return false, layouts_error
    end
  end

  return true, nil
end

---Validate resources collection
---@param resources table Resources table from DSL
---@return boolean success True if validation passed
---@return string|nil error Error message if validation failed
function validator.validate_resources(resources)
  if not resources then
    return false, "resources table is required"
  end

  if type(resources) ~= "table" then
    return false, "resources must be a table"
  end

  -- Check that resources table is not empty
  local resource_count = count_table_keys(resources)
  if resource_count == 0 then
    return false, "at least one resource is required"
  end

  -- Validate each resource
  for resource_name, resource_spec in pairs(resources) do
    local success, error_msg =
      validator.validate_resource(resource_spec, resource_name)
    if not success then
      return false, "resource '" .. resource_name .. "': " .. error_msg
    end
  end

  return true, nil
end

---Validate individual resource specification
---@param resource_spec table Resource specification to validate
---@param resource_name string Name of the resource (for error context)
---@return boolean success True if validation passed
---@return string|nil error Error message if validation failed
function validator.validate_resource(resource_spec, _)
  if not resource_spec then
    return false, "resource specification is required"
  end

  if type(resource_spec) ~= "table" then
    return false, "resource specification must be a table"
  end

  if not resource_spec.type then
    return false, "resource type is required"
  end

  if type(resource_spec.type) ~= "string" then
    return false, "resource type must be a string"
  end

  -- Delegate to helper-specific validation
  local success, error_msg =
    helpers.validate_resource(resource_spec, resource_spec.type)
  if not success then
    return false, error_msg
  end

  return true, nil
end

---Validate hooks configuration (future feature)
---@param hooks table Hooks configuration to validate
---@return boolean success True if validation passed
---@return string|nil error Error message if validation failed
function validator.validate_hooks(hooks)
  if not hooks then
    return false, "hooks table is required"
  end

  if type(hooks) ~= "table" then
    return false, "hooks must be a table"
  end

  -- Validate start hook if present
  if hooks.start then
    if type(hooks.start) ~= "string" then
      return false, "hooks.start must be a string"
    end
    if hooks.start == "" then
      return false, "hooks.start cannot be empty"
    end
  end

  -- Validate stop hook if present
  if hooks.stop then
    if type(hooks.stop) ~= "string" then
      return false, "hooks.stop must be a string"
    end
    if hooks.stop == "" then
      return false, "hooks.stop cannot be empty"
    end
  end

  -- Check for unknown hook types
  local valid_hooks = { start = true, stop = true }
  for hook_name, _ in pairs(hooks) do
    if not valid_hooks[hook_name] then
      return false,
        "unknown hook type: " .. hook_name .. " (valid: start, stop)"
    end
  end

  return true, nil
end

---Validate layouts configuration (future feature)
---@param layouts table Layouts configuration to validate
---@return boolean success True if validation passed
---@return string|nil error Error message if validation failed
function validator.validate_layouts(layouts)
  if not layouts then
    return false, "layouts table is required"
  end

  if type(layouts) ~= "table" then
    return false, "layouts must be a table"
  end

  local layout_count = count_table_keys(layouts)
  if layout_count == 0 then
    return false, "at least one layout is required if layouts table is present"
  end

  -- Validate each layout
  for layout_name, layout_spec in pairs(layouts) do
    if type(layout_name) ~= "string" then
      return false, "layout name must be a string"
    end

    if layout_name == "" then
      return false, "layout name cannot be empty"
    end

    if type(layout_spec) ~= "table" then
      return false, "layout '" .. layout_name .. "' must be a table"
    end

    -- Layout spec validation would go here
    -- For now, we just ensure it's a table
  end

  return true, nil
end

---Get validation summary for human-readable output
---@param dsl table DSL table that was validated
---@return table summary Validation summary with details
function validator.get_validation_summary(dsl)
  local summary = {
    project_name = dsl and dsl.name or "unknown",
    resource_count = 0,
    resources = {},
    has_hooks = false,
    has_layouts = false,
    valid = false,
    errors = {},
  }

  if not dsl then
    table.insert(summary.errors, "DSL is nil")
    return summary
  end

  -- Count resources and validate each
  if dsl.resources and type(dsl.resources) == "table" then
    for resource_name, resource_spec in pairs(dsl.resources) do
      summary.resource_count = summary.resource_count + 1

      local resource_info = {
        name = resource_name,
        type = resource_spec and resource_spec.type or "unknown",
        valid = false,
        error = nil,
      }

      local success, error_msg =
        validator.validate_resource(resource_spec, resource_name)
      resource_info.valid = success
      resource_info.error = error_msg

      table.insert(summary.resources, resource_info)
    end
  end

  summary.has_hooks = (dsl.hooks ~= nil)
  summary.has_layouts = (dsl.layouts ~= nil)

  -- Overall validation
  local success, error_msg = validator.validate_dsl(dsl)
  summary.valid = success
  if not success then
    table.insert(summary.errors, error_msg)
  end

  return summary
end

return validator
