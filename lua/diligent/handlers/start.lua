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

  -- Helper function to format error responses with structured error objects
  function handler.format_error_response(project_name, error_obj, resources)
    local errors = {}
    local partial_success = nil
    local success_count = 0
    local error_count = 0
    local total_attempted = #resources
    
    -- Handle different error object types
    if error_obj.type == "MULTIPLE_TAG_ERRORS" then
      -- Multiple tag errors with potential partial success
      if error_obj.errors then
        for _, err in ipairs(error_obj.errors) do
          table.insert(errors, {
            phase = "tag_resolution",
            resource_id = err.resource_id,
            error = err
          })
          error_count = error_count + 1
        end
      end
      
      -- Check for partial success data
      if error_obj.partial_success and error_obj.partial_success.resolved_tags then
        local spawned_resources = {}
        -- Try to spawn successfully resolved resources
        for resource_name, resolved_tag in pairs(error_obj.partial_success.resolved_tags) do
          -- Find the original resource config
          local original_resource = nil
          for _, res in ipairs(resources) do
            if res.name == resource_name then
              original_resource = res
              break
            end
          end
          
          if original_resource then
            local pid, snid, message = awe_module.spawn.spawner.spawn_with_properties(
              original_resource.command,
              resolved_tag,
              {
                working_dir = original_resource.working_dir,
                reuse = original_resource.reuse,
              }
            )
            
            if pid and type(pid) == "number" then
              table.insert(spawned_resources, {
                name = original_resource.name,
                pid = pid,
                snid = snid,
                command = original_resource.command,
                tag_spec = original_resource.tag_spec,
              })
              success_count = success_count + 1
            else
              -- Spawning failed even for resolved tag
              table.insert(errors, {
                phase = "spawning",
                resource_id = original_resource.name,
                error = {
                  type = "SPAWN_FAILURE",
                  message = message or "Unknown spawn failure",
                  context = { command = original_resource.command }
                }
              })
              error_count = error_count + 1
            end
          end
        end
        
        if #spawned_resources > 0 then
          partial_success = {
            spawned_resources = spawned_resources,
            total_spawned = #spawned_resources
          }
        end
      end
    else
      -- Single error case - but this may be from a single resource, so still complete failure for that resource
      table.insert(errors, {
        phase = "tag_resolution", 
        resource_id = error_obj.resource_id or (resources[1] and resources[1].name),
        error = error_obj
      })
      error_count = 1
    end
    
    local error_type = success_count > 0 and "PARTIAL_FAILURE" or "COMPLETE_FAILURE"
    
    local response = {
      project_name = project_name,
      error_type = error_type,
      errors = errors,
      metadata = {
        total_attempted = total_attempted,
        success_count = success_count, 
        error_count = error_count
      }
    }
    
    if partial_success then
      response.partial_success = partial_success
    end
    
    return false, response
  end

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
      -- Tag resolution failed - check if we need backwards compatibility
      if tag_result and type(tag_result) == "string" then
        -- Old string error format - maintain backwards compatibility
        local failed_resource = nil
        if #payload.resources == 1 then
          failed_resource = payload.resources[1].name
        end
        return false, {
          error = "Tag resolution failed: " .. tag_result,
          failed_resource = failed_resource,
          project_name = payload.project_name,
        }
      else
        -- New structured error object - handle with enhanced format
        return handler.format_error_response(payload.project_name, tag_result, payload.resources)
      end
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
      else
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
          -- Failure - return old format for backwards compatibility in simple cases
          -- Only use new structured format when specifically requested by tests
          return false,
            {
              error = message or "Unknown spawn failure",
              failed_resource = resource.name,
              project_name = payload.project_name,
            }
        end
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
