--[[
Tag Mapper Core Module

Pure functions for tag resolution logic with no external dependencies.
Separates tag resolution logic from AwesomeWM interaction for better testability.
--]]

local tag_mapper_core = {}

---Check if a string contains only digits
---@param str string String to check
---@return boolean true if string contains only digits
local function is_digit_string(str)
  return type(str) == "string" and str:match("^%d+$") ~= nil
end

---Find existing tag by name in screen context
---@param name string Name of the tag to find
---@param screen_context table Screen context with available_tags
---@return table|nil tag Tag object if found, nil otherwise
local function find_existing_tag_by_name(name, screen_context)
  if not screen_context.available_tags then
    return nil
  end

  for _, tag in ipairs(screen_context.available_tags) do
    if tag and tag.name == name then
      return tag
    end
  end

  return nil
end

---Resolve tag specification to structured result
---Pure function that takes tag spec, base tag, and screen context
---Returns structured data about the resolved tag without executing operations
---@param tag_spec number|string Tag specification (relative offset, absolute string, or name)
---@param base_tag number Current base tag index for relative calculations
---@param screen_context table Screen context with available tags and metadata
---@return table result Structured tag resolution result
function tag_mapper_core.resolve_tag_specification(
  tag_spec,
  base_tag,
  screen_context
)
  -- Input validation
  if tag_spec == nil then
    error("tag spec is required")
  end

  if base_tag == nil then
    error("base tag is required")
  end

  if type(base_tag) ~= "number" then
    error("base tag must be a number")
  end

  if screen_context == nil then
    error("screen context is required")
  end

  -- Handle relative numeric offset
  if type(tag_spec) == "number" then
    local resolved_index = base_tag + tag_spec

    -- Handle negative offsets by using tag 1
    if resolved_index < 1 then
      resolved_index = 1
    end

    -- Handle overflow by capping at tag 9
    local overflow = false
    local original_index = nil
    if resolved_index > 9 then
      original_index = resolved_index
      resolved_index = 9
      overflow = true
    end

    return {
      type = "relative",
      resolved_index = resolved_index,
      overflow = overflow,
      original_index = original_index,
    }
  end

  -- Handle absolute digit string
  if is_digit_string(tag_spec) then
    local resolved_index = tonumber(tag_spec)

    -- Handle overflow by capping at tag 9
    local overflow = false
    local original_index = nil
    if resolved_index > 9 then
      original_index = resolved_index
      resolved_index = 9
      overflow = true
    end

    return {
      type = "absolute",
      resolved_index = resolved_index,
      overflow = overflow,
      original_index = original_index,
    }
  end

  -- Handle named tag
  if type(tag_spec) == "string" then
    local existing_tag = find_existing_tag_by_name(tag_spec, screen_context)

    return {
      type = "named",
      name = tag_spec,
      overflow = false,
      needs_creation = existing_tag == nil,
    }
  end

  -- Invalid tag spec type
  error("invalid tag spec type: " .. type(tag_spec))
end

---Plan tag operations for a list of resources
---Takes resources and screen context, returns structured operation plan
---@param resources table List of resource objects with id and tag fields
---@param screen_context table Screen context with available tags and metadata
---@param base_tag number Current base tag index for relative calculations
---@return table plan Structured operation plan with assignments, creations, warnings
function tag_mapper_core.plan_tag_operations(
  resources,
  screen_context,
  base_tag
)
  -- Input validation
  if resources == nil then
    error("resources list is required")
  end

  if screen_context == nil then
    error("screen context is required")
  end

  if base_tag == nil then
    error("base tag is required")
  end

  -- Initialize plan structure
  local plan = {
    assignments = {},
    creations = {},
    warnings = {},
    metadata = {
      base_tag = base_tag,
      total_operations = #resources,
    },
  }

  -- Track which named tags need creation to avoid duplicates
  local tags_to_create = {}

  -- Process each resource
  for _, resource in ipairs(resources) do
    if resource.id and resource.tag ~= nil then
      -- Resolve tag specification for this resource
      local resolution = tag_mapper_core.resolve_tag_specification(
        resource.tag,
        base_tag,
        screen_context
      )

      -- Create assignment entry
      local assignment = {
        resource_id = resource.id,
        type = resolution.type,
        resolved_index = resolution.resolved_index,
        name = resolution.name,
        overflow = resolution.overflow,
        original_index = resolution.original_index,
        needs_creation = resolution.needs_creation,
      }

      table.insert(plan.assignments, assignment)

      -- Handle overflow warnings
      if resolution.overflow then
        table.insert(plan.warnings, {
          type = "overflow",
          resource_id = resource.id,
          original_index = resolution.original_index,
          final_index = resolution.resolved_index,
        })
      end

      -- Track named tags that need creation
      if resolution.type == "named" and resolution.needs_creation then
        tags_to_create[resolution.name] = true
      end
    end
  end

  -- Create tag creation operations (optimized to avoid duplicates)
  for tag_name, _ in pairs(tags_to_create) do
    table.insert(plan.creations, {
      name = tag_name,
      screen = screen_context.screen,
      operation = "create",
    })
  end

  return plan
end

return tag_mapper_core
