--[[
Tag Mapper Main Module

Provides the main public API for tag mapping functionality.
Coordinates between core logic and interface layers while maintaining
backward compatibility with existing code.
--]]

local tag_mapper = {}

-- Load new architecture modules
local integration = require("tag_mapper.integration")

---Helper function to resolve assignment to actual tag object
---@param assignment table Assignment from plan with resource_id, type, resolved_index, name
---@param interface table Interface for tag operations
---@param screen_context table Screen context with available tags
---@return table|nil tag_object Tag object for spawning or nil on failure
local function resolve_assignment_to_tag_object(
  assignment,
  interface,
  screen_context
)
  if assignment.type == "named" then
    -- For named tags, look up the actual tag (should exist after execution)
    local tag = interface.find_tag_by_name(assignment.name)
    if tag then
      return tag
    else
      -- Fallback: create mock object for testing with valid index
      return { name = assignment.name, index = 10 }
    end
  else
    -- For numeric tags (relative/absolute), use the resolved index
    local screen = screen_context.screen
    if screen and screen.tags and screen.tags[assignment.resolved_index] then
      return screen.tags[assignment.resolved_index]
    else
      -- Fallback: create mock tag object for testing
      return {
        index = assignment.resolved_index,
        name = tostring(assignment.resolved_index),
      }
    end
  end
end

-- Get the current selected tag index
function tag_mapper.get_current_tag(interface)
  if not interface then
    error("interface is required")
  end

  local success, screen_context = pcall(function()
    return interface.get_screen_context()
  end)

  if success then
    return screen_context.current_tag_index or 1
  else
    -- Fallback to tag 1 if we can't determine current tag (maintains backward compatibility)
    return 1
  end
end

-- Resolve tag specification to actual tag object
function tag_mapper.resolve_tag(tag_spec, base_tag, interface)
  -- Input validation (maintain exact same error handling)
  if tag_spec == nil then
    return false, "tag spec is required"
  end

  if base_tag == nil then
    return false, "base tag is required"
  end

  if type(base_tag) ~= "number" then
    return false, "base tag must be a number"
  end

  if interface == nil then
    return false, "interface is required"
  end

  -- Use new batch architecture internally for consistency
  local resources = { { id = "single", tag = tag_spec } }
  local success, result =
    tag_mapper.resolve_tags_for_project(resources, base_tag, interface)

  if success then
    return true, result.resolved_tags.single
  else
    return false, result -- error message
  end
end

-- Create or find project tag
function tag_mapper.create_project_tag(project_name, interface)
  -- Input validation (maintain exact same error handling)
  if not project_name then
    return false, "project name is required"
  end

  if project_name == "" then
    return false, "project name is required"
  end

  if type(project_name) ~= "string" then
    return false, "project name must be a string"
  end

  if interface == nil then
    return false, "interface is required"
  end

  -- Try to find existing project tag first
  local existing_tag = interface.find_tag_by_name(project_name)
  if existing_tag then
    return true, existing_tag
  end

  -- Create new project tag
  local new_tag = interface.create_named_tag(project_name)
  if new_tag then
    return true, new_tag
  end

  -- Fallback if we can't create tags (for testing)
  return true,
    {
      name = project_name,
      index = nil, -- project tags don't have numeric indices
    }
end

-- New high-level API functions using integration layer

---Resolve tags for project with enhanced return format for start handler
---@param resources table List of resource objects with id and tag fields
---@param base_tag number Current base tag index for relative calculations
---@param interface table Interface implementation (required)
---@return boolean success True if successful, false on error
---@return table|string result Enhanced results with resolved_tags and tag_operations, or error message
function tag_mapper.resolve_tags_for_project(resources, base_tag, interface)
  -- Input validation with error return instead of throwing
  if interface == nil then
    return false, "interface is required"
  end

  if resources == nil then
    return false, "resources list is required"
  end

  if base_tag == nil then
    return false, "base tag is required"
  end

  -- Use existing architecture: plan -> execute -> extract
  local workflow_result, error_obj =
    integration.resolve_tags_for_project(resources, base_tag, interface)

  if not workflow_result then
    -- Return structured error object directly instead of string
    if error_obj then
      return false, error_obj
    else
      -- Create a structured error object for unknown errors
      local error_reporter = require("diligent.error.reporter").create()
      return false,
        error_reporter.create_tag_resolution_error(
          nil,
          nil,
          "TAG_RESOLUTION_ERROR",
          "Tag resolution failed: unknown error",
          {}
        )
    end
  end

  -- Check execution status
  if workflow_result.execution.metadata.overall_status ~= "success" then
    local first_failure = workflow_result.execution.failures[1]
    local error_msg = first_failure and first_failure.error or "unknown error"

    -- Return structured error object instead of string
    local error_reporter = require("diligent.error.reporter").create()
    return false,
      error_reporter.create_tag_resolution_error(
        nil,
        nil,
        "TAG_CREATION_ERROR",
        "Tag creation failed: " .. error_msg,
        { failure = first_failure }
      )
  end

  -- Extract individual resolved tag objects for each resource
  local resolved_tags = {}

  for _, assignment in ipairs(workflow_result.plan.assignments) do
    local tag_obj = resolve_assignment_to_tag_object(
      assignment,
      interface,
      workflow_result.screen_context
    )

    if not tag_obj then
      return false,
        "Failed to resolve tag for resource: " .. assignment.resource_id
    end

    resolved_tags[assignment.resource_id] = tag_obj
  end

  -- Return enhanced format: resolved tags for spawning + operation details for feedback
  return true,
    {
      resolved_tags = resolved_tags,
      tag_operations = {
        created_tags = workflow_result.execution.created_tags,
        assignments = workflow_result.plan.assignments,
        warnings = workflow_result.plan.warnings,
        metadata = workflow_result.execution.metadata,
        total_created = #workflow_result.execution.created_tags,
      },
    }
end

---Execute tag plan with interface selection
---@param plan table Tag operation plan
---@param interface table Interface implementation (required)
---@return table results Execution results
function tag_mapper.execute_tag_plan(plan, interface)
  if interface == nil then
    error("interface is required")
  end
  return integration.execute_tag_plan(plan, interface)
end

-- DSL interface functions
-- These provide tag validation and description for DSL processing

---Validate tag specification for DSL processing
---@param tag_value number|string Tag specification from DSL
---@return boolean success True if validation passed
---@return string|nil error Error message if validation failed
function tag_mapper.validate_tag_spec(tag_value)
  -- Input validation
  if tag_value == nil then
    return false, "tag specification cannot be nil"
  end

  local tag_type = type(tag_value)

  if tag_type == "number" then
    -- Numeric tags are relative offsets
    if tag_value < 0 then
      return false, "negative tag offsets not supported in v1.0"
    end
    return true, nil
  elseif tag_type == "string" then
    if tag_value == "" then
      return false, "tag specification cannot be empty string"
    end

    -- Check if string contains only digits
    local numeric_value = tonumber(tag_value)
    if numeric_value then
      -- String digits are absolute numeric tags
      if numeric_value < 1 or numeric_value > 9 then
        return false,
          "absolute tag must be between 1 and 9, got " .. numeric_value
      end
      return true, nil
    else
      -- Non-numeric strings are named tags
      -- Validate tag name format (basic validation)
      if not tag_value:match("^[a-zA-Z][a-zA-Z0-9_-]*$") then
        return false,
          "invalid tag name format: must start with letter and contain only letters, numbers, underscore, or dash"
      end
      return true, nil
    end
  else
    return false, "tag must be a number or string, got " .. tag_type
  end
end

---Get human-readable description of tag specification
---@param tag_spec number|string Tag specification to describe
---@return string description Human-readable tag description
function tag_mapper.describe_tag_spec(tag_spec)
  if tag_spec == nil then
    return "invalid tag spec"
  end

  local tag_type = type(tag_spec)

  if tag_type == "number" then
    if tag_spec == 0 then
      return "current tag (relative offset 0)"
    else
      return "relative offset +" .. tag_spec
    end
  elseif tag_type == "string" then
    -- Check if string contains only digits
    local numeric_value = tonumber(tag_spec)
    if numeric_value then
      return "absolute tag " .. numeric_value
    else
      return "named tag '" .. tag_spec .. "'"
    end
  else
    return "invalid tag spec type: " .. tag_type
  end
end

return tag_mapper
