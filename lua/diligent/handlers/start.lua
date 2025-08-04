require("diligent.validators")
local livr = require("LIVR")

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

    -- Phase 1: Sequential processing of resources
    for _, resource in ipairs(payload.resources or {}) do
      local pid, snid, message = awe_module.spawn.spawner.spawn_with_properties(
        resource.command,
        resource.tag_spec,
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
        -- Failure - return error immediately (fail-fast for Phase 1)
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
      }
  end

  return handler
end

return start_handler
