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

  -- Build combined response from tag and spawn metadata
  ---@param tag_metadata table Metadata from tag resolution
  ---@param spawn_metadata table Metadata from spawning operation
  ---@param payload table Original request payload
  ---@return boolean success Overall operation success
  ---@return table response Response object with comprehensive information
  function handler.build_combined_response(
    tag_metadata,
    spawn_metadata,
    payload
  )
    local total_attempted = #payload.resources
    local spawned_count = spawn_metadata.success_count or 0
    local has_spawn_errors = spawn_metadata.error_count
      and spawn_metadata.error_count > 0
    local has_tag_errors = tag_metadata.errors and #tag_metadata.errors > 0

    -- Determine overall success (succeed if any spawned OR if no resources to spawn)
    local overall_success = spawned_count > 0 or total_attempted == 0

    if overall_success then
      -- Success response (some or all resources spawned)
      local response = {
        project_name = payload.project_name,
        spawned_resources = spawn_metadata.result or {},
        total_spawned = spawned_count,
        tag_operations = tag_metadata.tag_operations or {},
      }

      -- Include warnings/errors in metadata if present
      if has_tag_errors or has_spawn_errors then
        response.warnings = {
          tag_errors = tag_metadata.errors or {},
          spawn_errors = spawn_metadata.errors or {},
        }
      end

      return true, response
    else
      -- Failure response (no resources spawned)
      local errors = {}

      -- Collect tag errors
      if has_tag_errors then
        for _, error_obj in ipairs(tag_metadata.errors) do
          table.insert(errors, {
            phase = "tag_resolution",
            resource_id = error_obj.resource_id,
            error = error_obj,
          })
        end
      end

      -- Collect spawn errors
      if has_spawn_errors then
        for _, error_obj in ipairs(spawn_metadata.errors) do
          table.insert(errors, {
            phase = "spawning",
            resource_id = error_obj.resource_id,
            error = error_obj,
          })
        end
      end

      local response = {
        project_name = payload.project_name,
        error_type = "COMPLETE_FAILURE",
        errors = errors,
        metadata = {
          total_attempted = total_attempted,
          success_count = 0,
          error_count = #errors,
        },
      }

      return false, response
    end
  end

  function handler.execute(payload)
    -- Get current tag index using tag_mapper
    local current_tag_index = tag_mapper.get_current_tag(awe_module.interface)

    -- Step 1: Batch tag resolution for all resources (with fallbacks)
    local tag_success, tag_result = tag_mapper.resolve_tags_for_project(
      payload.resources, -- {name, tag_spec} directly - no transformation!
      current_tag_index,
      awe_module.interface
    )

    -- Handle critical tag_mapper failure (rare)
    if not tag_success then
      local error_message = tag_result
      if type(tag_result) == "table" and tag_result.message then
        error_message = tag_result.message
      end
      return false,
        {
          error = "Critical tag mapper error: "
            .. (error_message or "unknown error"),
          project_name = payload.project_name,
        }
    end

    -- Extract resolved_tags and metadata from tag_result
    local resolved_tags = tag_result.resolved_tags
    local tag_metadata = {
      tag_operations = tag_result.tag_operations,
      errors = tag_result.tag_operations.errors or {},
    }

    -- Step 2: Spawn resources using resolved tags
    local spawn_success, spawned_resources, spawn_metadata =
      handler.spawn_resources(resolved_tags, payload.resources, awe_module)

    -- Store results in spawn_metadata for response building
    if spawn_success then
      spawn_metadata.result = spawned_resources
    end

    -- Step 3: Build combined response
    return handler.build_combined_response(
      tag_metadata,
      spawn_metadata,
      payload
    )
  end

  return handler
end

return start_handler
