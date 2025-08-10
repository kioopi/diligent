--[[
DSL Start Processor Module

Converts DSL project structures to standardized start request format.
Handles resource type filtering and default value application.
--]]

local start_processor_helpers = require("dsl.start_processor_helpers")

local start_processor = {}

---Convert DSL project to start request format
---Transforms DSL project structure into standardized start request format,
---filtering by supported resource types and applying proper defaults.
---@param dsl_project table DSL project structure with 'name' and optional 'resources' table
---@return table start_request Standardized start request with 'project_name' and 'resources' array
function start_processor.convert_project_to_start_request(dsl_project)
  local resources = {}

  -- Get sorted list of resource names for deterministic order
  local resource_names = {}
  for name, _ in pairs(dsl_project.resources or {}) do
    table.insert(resource_names, name)
  end
  table.sort(resource_names)

  -- Get supported resource types
  local supported_types = start_processor_helpers.get_supported_resource_types()

  -- Process each resource from DSL in sorted order
  for _, name in ipairs(resource_names) do
    local resource_def = dsl_project.resources[name]

    -- Check if resource type is supported
    local is_supported = false
    for _, supported_type in ipairs(supported_types) do
      if resource_def.type == supported_type then
        is_supported = true
        break
      end
    end

    if is_supported then
      -- Use helper to convert resource to request format
      local request_resource =
        start_processor_helpers.convert_resource_to_request_format(
          name,
          resource_def,
          resource_def.type
        )
      table.insert(resources, request_resource)
    end
  end

  return {
    project_name = dsl_project.name,
    resources = resources,
  }
end

return start_processor
