--[[
App Helper - Generic Application Resource

Implements the app{} DSL helper function for spawning generic X11 applications.
Supports all fields defined in the DSL specification and provides validation.
--]]

local tag_mapper = require("tag_mapper")

local app_helper = {}

-- Schema definition for validation
app_helper.schema = {
  required = { "cmd" },
  optional = { "dir", "tag", "reuse" },
  types = {
    cmd = "string",
    dir = "string",
    tag = { "number", "string" }, -- Supports both relative and absolute
    reuse = "boolean",
  },
  defaults = {
    tag = 0, -- Default to current tag (relative offset 0)
    reuse = false,
  },
}

---Create app resource specification from DSL input
---@param spec table App specification from DSL
---@return table resource Normalized resource specification
function app_helper.create(spec)
  -- Input should already be validated, but we normalize here
  local resource = {
    type = "app",
    cmd = spec.cmd,
    dir = spec.dir,
    tag = spec.tag or app_helper.schema.defaults.tag,
    reuse = spec.reuse or app_helper.schema.defaults.reuse,
  }

  return resource
end

---Validate app specification according to schema
---@param spec table App specification to validate
---@return boolean success True if validation passed
---@return string|nil error Error message if validation failed
function app_helper.validate(spec)
  if not spec then
    return false, "app spec is required"
  end

  if type(spec) ~= "table" then
    return false, "app spec must be a table"
  end

  -- Check required fields
  for _, field in ipairs(app_helper.schema.required) do
    if not spec[field] then
      return false, field .. " field is required"
    end
  end

  -- Validate field types
  for field, value in pairs(spec) do
    local expected_types = app_helper.schema.types[field]
    if expected_types then
      local value_type = type(value)
      local valid_type = false

      if type(expected_types) == "string" then
        valid_type = (value_type == expected_types)
      elseif type(expected_types) == "table" then
        for _, expected_type in ipairs(expected_types) do
          if value_type == expected_type then
            valid_type = true
            break
          end
        end
      end

      if not valid_type then
        if type(expected_types) == "table" then
          local types_str = table.concat(expected_types, " or ")
          return false,
            field .. " must be " .. types_str .. ", got " .. value_type
        else
          return false,
            field .. " must be " .. expected_types .. ", got " .. value_type
        end
      end
    end
  end

  -- Validate tag specification if present
  if spec.tag then
    local tag_valid, tag_error = tag_mapper.validate_tag_spec(spec.tag)
    if not tag_valid then
      return false, "invalid tag specification: " .. tag_error
    end
  end

  -- Check for unknown fields (optional warning could be added here)
  local known_fields = {}
  for _, field in ipairs(app_helper.schema.required) do
    known_fields[field] = true
  end
  for _, field in ipairs(app_helper.schema.optional) do
    known_fields[field] = true
  end

  -- Check for unknown fields (currently permissive)
  -- Future: could add warning system for unknown fields
  -- for field, _ in pairs(spec) do
  --   if not known_fields[field] then
  --     -- warning: unknown field
  --   end
  -- end

  return true, nil
end

---Get human-readable description of app spec for validation output
---@param spec table App specification
---@return string description Description of the app resource
function app_helper.describe(spec)
  if not spec or not spec.cmd then
    return "invalid app spec"
  end

  local parts = { "app: " .. spec.cmd }

  if spec.dir then
    table.insert(parts, "dir: " .. spec.dir)
  end

  if spec.tag then
    table.insert(parts, "tag: " .. tag_mapper.describe_tag_spec(spec.tag))
  end

  if spec.reuse then
    table.insert(parts, "reuse: true")
  end

  return table.concat(parts, ", ")
end

return app_helper
