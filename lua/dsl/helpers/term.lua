--[[
Term Helper - Terminal Application Resource

Implements the term{} DSL helper function for spawning terminal applications.
Supports all fields defined in the DSL specification and provides validation.
--]]

local tag_mapper = require("tag_mapper")

local term_helper = {}

-- Schema definition for validation
term_helper.schema = {
  required = { "cmd" },
  optional = { "dir", "tag", "interactive", "terminal" },
  types = {
    cmd = "string",
    dir = "string",
    tag = { "number", "string" }, -- Supports both relative and absolute
    interactive = "boolean",
    terminal = "string",
  },
  defaults = {
    tag = 0, -- Default to current tag (relative offset 0)
    interactive = true, -- Default to interactive terminal
    terminal = "alacritty", -- Default terminal emulator
  },
}

---Create term resource specification from DSL input
---@param spec table Term specification from DSL
---@return table resource Normalized resource specification
function term_helper.create(spec)
  -- Input should already be validated, but we normalize here
  local resource = {
    type = "term",
    cmd = spec.cmd,
    dir = spec.dir,
    tag = spec.tag or term_helper.schema.defaults.tag,
    interactive = spec.interactive,
    terminal = spec.terminal or term_helper.schema.defaults.terminal,
  }

  -- Apply interactive default if not specified
  if resource.interactive == nil then
    resource.interactive = term_helper.schema.defaults.interactive
  end

  return resource
end

---Validate term specification according to schema
---@param spec table Term specification to validate
---@return boolean success True if validation passed
---@return string|nil error Error message if validation failed
function term_helper.validate(spec)
  if not spec then
    return false, "term spec is required"
  end

  if type(spec) ~= "table" then
    return false, "term spec must be a table"
  end

  -- Check required fields
  for _, field in ipairs(term_helper.schema.required) do
    if not spec[field] then
      return false, field .. " field is required"
    end
  end

  -- Validate field types
  for field, value in pairs(spec) do
    local expected_types = term_helper.schema.types[field]
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
  for _, field in ipairs(term_helper.schema.required) do
    known_fields[field] = true
  end
  for _, field in ipairs(term_helper.schema.optional) do
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

---Get human-readable description of term spec for validation output
---@param spec table Term specification
---@return string description Description of the term resource
function term_helper.describe(spec)
  if not spec or not spec.cmd then
    return "invalid term spec"
  end

  local parts = { "term: " .. spec.cmd }

  if spec.dir then
    table.insert(parts, "dir: " .. spec.dir)
  end

  if spec.tag then
    table.insert(parts, "tag: " .. tag_mapper.describe_tag_spec(spec.tag))
  end

  if
    spec.terminal and spec.terminal ~= term_helper.schema.defaults.terminal
  then
    table.insert(parts, "terminal: " .. spec.terminal)
  end

  if spec.interactive == false then -- Only show when explicitly false
    table.insert(parts, "interactive: false")
  end

  return table.concat(parts, ", ")
end

return term_helper
