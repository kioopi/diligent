--[[
DSL Start Processor Module

Converts DSL project structures to standardized start request format.
Handles resource type filtering and default value application.
--]]

local start_processor = {}

---Convert DSL project to start request format
---@param dsl_project table DSL project structure
---@return table start_request Standardized start request
function start_processor.convert_project_to_start_request(dsl_project)
  local resources = {}

  -- Get sorted list of resource names for deterministic order
  local resource_names = {}
  for name, _ in pairs(dsl_project.resources or {}) do
    table.insert(resource_names, name)
  end
  table.sort(resource_names)

  -- Process each resource from DSL in sorted order
  for _, name in ipairs(resource_names) do
    local resource_def = dsl_project.resources[name]
    -- Phase 1: Only handle app resource types
    if resource_def.type == "app" then
      -- Handle tag specification (preserve type: numeric stays numeric, string stays string)
      local tag_spec_value = resource_def.tag
      if tag_spec_value == nil then
        tag_spec_value = 0 -- Default to numeric 0 (current tag, relative offset 0)
      end

      -- Basic type validation only
      if
        type(tag_spec_value) ~= "number" and type(tag_spec_value) ~= "string"
      then
        error(
          "Invalid tag specification for resource '"
            .. name
            .. "': must be number or string, got "
            .. type(tag_spec_value)
        )
      end

      table.insert(resources, {
        name = name,
        command = resource_def.cmd,
        tag_spec = tag_spec_value,
        working_dir = resource_def.dir,
        reuse = resource_def.reuse or false, -- Default to false
      })
    end
  end

  return {
    project_name = dsl_project.name,
    resources = resources,
  }
end

return start_processor
