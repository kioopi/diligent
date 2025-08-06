require("diligent.validators")
local livr = require("LIVR")
local tag_mapper = require("tag_mapper")

local start_handler = {}

-- LIVR validator for start payload (simplified for Phase 1)
start_handler.validator = livr.new({
  project_name = { "required", "non_empty_string" },
  resources = "required",
})

---Create start handler with injected awe module
---@param awe_module table Awe module instance
---@return table handler Handler instance with execute function
function start_handler.create(awe_module)
  local handler = {
    validator = start_handler.validator,
  }

  function handler.execute(payload)
    local spawned_resources = {}

    -- Get the interface for tag_mapper (tag_mapper expects raw interface, not awe_module)
    local interface = awe_module.interface

    -- Get current tag index using tag_mapper
    local current_tag_index = tag_mapper.get_current_tag(interface)

    -- Transform resources to match tag_mapper expected format (id, tag)
    local tag_mapper_resources = {}
    for _, resource in ipairs(payload.resources or {}) do
      table.insert(tag_mapper_resources, {
        id = resource.name, -- tag_mapper uses 'id' field
        tag = resource.tag_spec, -- tag_mapper uses 'tag' field
      })
    end

    -- Batch tag resolution for all resources at once
    local tag_success, tag_result = tag_mapper.resolve_tags_for_project(
      tag_mapper_resources,
      current_tag_index,
      interface
    )

    if not tag_success then
      -- Tag resolution failed - return error immediately
      -- For backward compatibility, if there's only one resource, include failed_resource
      local failed_resource = nil
      if #payload.resources == 1 then
        failed_resource = payload.resources[1].name
      end

      return false,
        {
          error = "Tag resolution failed: " .. (tag_result or "unknown error"),
          failed_resource = failed_resource,
          project_name = payload.project_name,
        }
    end

    -- Process each resource for spawning using the resolved tags
    for _, resource in ipairs(payload.resources or {}) do
      local resolved_tag = tag_result.resolved_tags[resource.name]

      if not resolved_tag then
        -- This shouldn't happen with proper tag_mapper implementation
        return false,
          {
            error = "Internal error: no resolved tag for resource "
              .. resource.name,
            failed_resource = resource.name,
            project_name = payload.project_name,
          }
      end

      local pid, snid, message = awe_module.spawn.spawner.spawn_with_properties(
        resource.command,
        resolved_tag,
        {
          working_dir = resource.working_dir,
          reuse = resource.reuse,
        }
      )

      if pid and type(pid) == "number" then
        -- Success - add to spawned resources
        table.insert(spawned_resources, {
          name = resource.name,
          pid = pid,
          snid = snid,
          command = resource.command,
          tag_spec = resource.tag_spec,
        })
      else
        -- Failure - return error immediately (fail-fast)
        return false,
          {
            error = message or "Unknown spawn failure",
            failed_resource = resource.name,
            project_name = payload.project_name,
          }
      end
    end

    return true,
      {
        project_name = payload.project_name,
        spawned_resources = spawned_resources,
        total_spawned = #spawned_resources,
        tag_operations = tag_result.tag_operations,
      }
  end

  return handler
end

return start_handler
