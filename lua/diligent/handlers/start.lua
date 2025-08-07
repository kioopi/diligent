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

  -- Helper function to attempt spawning a single resource
  local function attempt_single_spawn(resource, resolved_tag, awe_instance)
    local pid, snid, message = awe_instance.spawn.spawner.spawn_with_properties(
      resource.command,
      resolved_tag,
      {
        working_dir = resource.working_dir,
        reuse = resource.reuse,
      }
    )

    if pid and type(pid) == "number" then
      return true,
        {
          name = resource.name,
          pid = pid,
          snid = snid,
          command = resource.command,
          tag_spec = resource.tag_spec,
        }
    else
      return false, message
    end
  end

  -- Helper function to create a structured spawn error object
  local function create_spawn_error(resource, message)
    return {
      type = "SPAWN_FAILURE",
      category = "execution",
      resource_id = resource.name,
      message = message or "Unknown spawn failure",
      context = { command = resource.command },
      suggestions = {
        "Check if '" .. resource.command .. "' is installed",
        "Verify command name spelling",
        "Add application directory to PATH",
      },
      metadata = {
        timestamp = os.time(),
        phase = "spawning",
      },
    }
  end

  -- Spawn resources using resolved tags
  ---@param resolved_tags table Map of resource names to tag objects
  ---@param resources table Original resource configurations
  ---@param awe_module table Awe module instance for spawning
  ---@return boolean success True if any resource spawned successfully
  ---@return table|string result Spawned resources array on success, error message on complete failure
  ---@return table metadata Spawn results, errors, and statistics
  function handler.spawn_resources(resolved_tags, resources, awe_instance)
    local spawned_resources = {}
    local spawn_errors = {}
    local spawn_results = {}
    local total_attempted = #resources

    -- Attempt to spawn each resource
    for _, resource in ipairs(resources) do
      local resolved_tag = resolved_tags[resource.name]

      if not resolved_tag then
        -- This shouldn't happen with new fallback strategy
        local error_obj = {
          type = "INTERNAL_ERROR",
          message = "No resolved tag for resource: " .. resource.name,
          resource_id = resource.name,
          context = { resolved_tags = resolved_tags },
        }
        table.insert(spawn_errors, error_obj)
        table.insert(spawn_results, {
          resource_name = resource.name,
          success = false,
          error = error_obj,
        })
      else
        -- Attempt spawn using helper function
        local spawn_success, spawn_result =
          attempt_single_spawn(resource, resolved_tag, awe_instance)

        if spawn_success then
          -- Spawn success
          table.insert(spawned_resources, spawn_result)
          table.insert(spawn_results, {
            resource_name = resource.name,
            success = true,
            pid = spawn_result.pid,
            snid = spawn_result.snid,
          })
        else
          -- Spawn failure - create structured error
          local spawn_error = create_spawn_error(resource, spawn_result)
          table.insert(spawn_errors, spawn_error)
          table.insert(spawn_results, {
            resource_name = resource.name,
            success = false,
            error = spawn_error,
          })
        end
      end
    end

    local metadata = {
      total_attempted = total_attempted,
      success_count = #spawned_resources,
      error_count = #spawn_errors,
      spawn_results = spawn_results,
      errors = spawn_errors,
    }

    -- Return success if any resources spawned OR if no resources were provided (empty list)
    if #spawned_resources > 0 or total_attempted == 0 then
      return true, spawned_resources, metadata
    elseif #spawn_errors > 0 then
      -- Complete failure - create aggregated error
      local error_reporter = require("diligent.error.reporter").create()
      local aggregated_error = error_reporter.aggregate_errors(spawn_errors)
      return false, aggregated_error, metadata
    else
      -- This shouldn't happen
      return false, "Unexpected state in spawn_resources", metadata
    end
  end

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
            error = err,
          })
          error_count = error_count + 1
        end
      end

      -- Check for partial success data - use spawn_resources function
      if
        error_obj.partial_success and error_obj.partial_success.resolved_tags
      then
        -- Filter resources to only include those with resolved tags
        local resolved_resources = {}
        for _, resource in ipairs(resources) do
          if error_obj.partial_success.resolved_tags[resource.name] then
            table.insert(resolved_resources, resource)
          end
        end

        -- Use the new spawn_resources function for partial success handling
        local spawn_success, spawned_resources, spawn_metadata =
          handler.spawn_resources(
            error_obj.partial_success.resolved_tags,
            resolved_resources,
            awe_module
          )

        if spawn_success then
          partial_success = {
            spawned_resources = spawned_resources,
            total_spawned = #spawned_resources,
          }
          success_count = #spawned_resources
        end

        -- Add spawn errors to existing error collection (only for resources that had successful tag resolution)
        if spawn_metadata.errors then
          for _, spawn_err in ipairs(spawn_metadata.errors) do
            table.insert(errors, {
              phase = "spawning",
              resource_id = spawn_err.resource_id,
              error = spawn_err,
            })
            error_count = error_count + 1
          end
        end
      end
    else
      -- Single error case - determine phase from error metadata or type
      local phase = "tag_resolution" -- default
      if
        (error_obj.metadata and error_obj.metadata.phase == "spawning")
        or error_obj.type == "SPAWN_FAILURE"
      then
        phase = "spawning"
      end

      table.insert(errors, {
        phase = phase,
        resource_id = error_obj.resource_id
          or (resources[1] and resources[1].name),
        error = error_obj,
      })
      error_count = 1
    end

    local error_type = success_count > 0 and "PARTIAL_FAILURE"
      or "COMPLETE_FAILURE"

    local response = {
      project_name = project_name,
      error_type = error_type,
      errors = errors,
      metadata = {
        total_attempted = total_attempted,
        success_count = success_count,
        error_count = error_count,
      },
    }

    if partial_success then
      response.partial_success = partial_success
    end

    return false, response
  end

  function handler.execute(payload)
    -- Get the interface for tag_mapper (tag_mapper expects raw interface, not awe_module)
    local interface = awe_module.interface

    -- Get current tag index using tag_mapper
    local current_tag_index = tag_mapper.get_current_tag(interface)

    -- Batch tag resolution for all resources at once (no transformation needed)
    local tag_success, tag_result = tag_mapper.resolve_tags_for_project(
      payload.resources,
      current_tag_index,
      interface
    )

    if not tag_success then
      -- Tag resolution failed - tag_result is always a structured error object now
      return handler.format_error_response(
        payload.project_name,
        tag_result,
        payload.resources
      )
    end

    -- Use spawn_resources function to handle all spawning
    local spawn_success, spawned_resources, _ = handler.spawn_resources(
      tag_result.resolved_tags,
      payload.resources,
      awe_module
    )

    if spawn_success then
      -- All or partial spawning success
      return true,
        {
          project_name = payload.project_name,
          spawned_resources = spawned_resources,
          total_spawned = #spawned_resources,
          tag_operations = tag_result.tag_operations,
        }
    else
      -- Complete spawning failure - use error response formatting
      return handler.format_error_response(
        payload.project_name,
        spawned_resources, -- This is the error object when spawn_success is false
        payload.resources
      )
    end
  end

  return handler
end

return start_handler
