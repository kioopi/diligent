--[[
Tag Mapper Integration Module

Coordinates between the pure core logic and interface layers.
Provides high-level functions that orchestrate the complete tag resolution workflow.
--]]

local integration = {}

-- Load dependencies
local tag_mapper_core = require("tag_mapper.core")

-- Import error framework for structured error objects
local error_reporter = require("diligent.error.reporter").create()

-- Helper function to create validation error object for integration layer
local function create_validation_error(message, context)
  return error_reporter.create_tag_resolution_error(
    nil, -- no resource_id for validation errors
    nil, -- no tag_spec for validation errors
    "TAG_SPEC_INVALID", -- validation errors use this type
    message,
    context or {}
  )
end

-- Helper function to validate common input parameters
local function validate_inputs(required_params, provided_params)
  local validators = {
    plan = function(p)
      return p ~= nil, "plan is required"
    end,
    interface = function(i)
      return i ~= nil, "interface is required"
    end,
    resources = function(r)
      return r ~= nil, "resources list is required"
    end,
    base_tag = function(t)
      return t ~= nil, "base tag is required"
    end,
  }

  -- Check each required parameter explicitly
  for _, param_name in ipairs(required_params) do
    local validator = validators[param_name]
    local value = provided_params[param_name]

    if validator then
      local is_valid, error_message = validator(value)
      if not is_valid then
        return nil,
          create_validation_error(error_message, { phase = "validation" })
      end
    end
  end

  return true
end

-- Helper function to check planning results for errors
local function should_fail_on_planning_errors(plan, resources)
  -- Check if plan has errors that should cause complete failure
  if plan.has_errors and plan.errors and #plan.errors > 0 then
    -- If all resources have errors (complete failure), return aggregated error
    if #plan.errors >= #resources then
      return true, error_reporter.aggregate_errors(plan.errors)
    end
    -- If some resources have errors (partial failure), continue with execution
  end
  return false, nil
end

-- Helper function to handle tag creation failures with structured error support
local function handle_tag_creation_failure(creation, error_obj)
  local failure_entry = {
    operation = "create_tag",
    tag_name = creation.name,
    error = "failed to create tag: " .. creation.name,
  }

  -- If interface returned a structured error object, include it
  if error_obj and type(error_obj) == "table" then
    failure_entry.structured_error = error_obj
    -- Use structured error message if available
    if error_obj.message then
      failure_entry.error = error_obj.message
    end
  end

  return failure_entry
end

---Execute tag plan via provided interface
---Takes a structured plan and executes the operations using the given interface
---@param plan table Tag operation plan from tag_mapper_core.plan_tag_operations()
---@param interface table Interface object (awesome_interface or dry_run_interface)
---@return table results Structured execution results
function integration.execute_tag_plan(plan, interface)
  -- Input validation
  local valid, validation_error = validate_inputs(
    { "plan", "interface" },
    { plan = plan, interface = interface }
  )
  if not valid then
    return nil, validation_error
  end

  local start_time = os.clock()

  -- Initialize results structure
  local results = {
    created_tags = {},
    assignments = {},
    failures = {},
    warnings = plan.warnings or {},
    metadata = {
      overall_status = "success",
      execution_time_ms = 0,
      plan_metadata = plan.metadata or {},
    },
  }

  -- Execute tag creations
  for _, creation in ipairs(plan.creations or {}) do
    local created_tag, error_obj =
      interface.create_named_tag(creation.name, creation.screen)

    if created_tag then
      table.insert(results.created_tags, {
        name = creation.name,
        tag = created_tag,
        operation = "create",
      })
    else
      -- Handle tag creation failure with structured error support
      table.insert(
        results.failures,
        handle_tag_creation_failure(creation, error_obj)
      )
      results.metadata.overall_status = "partial_failure"
    end
  end

  -- Process assignments (just record them, actual assignment happens in higher layer)
  for _, assignment in ipairs(plan.assignments or {}) do
    table.insert(results.assignments, {
      resource_id = assignment.resource_id,
      type = assignment.type,
      resolved_index = assignment.resolved_index,
      name = assignment.name,
      tag_object = assignment.tag_object, -- May be nil for newly created tags
    })
  end

  -- Calculate execution time
  local end_time = os.clock()
  results.metadata.execution_time_ms =
    math.floor((end_time - start_time) * 1000)

  return results
end

---Resolve tags for project resources
---High-level coordinator that handles the complete workflow
---@param resources table List of resource objects with id and tag fields
---@param base_tag number Current base tag index for relative calculations
---@param interface table Interface object (awesome_interface or dry_run_interface)
---@return table results Complete workflow results with plan and execution
function integration.resolve_tags_for_project(resources, base_tag, interface)
  -- Input validation
  local valid, validation_error = validate_inputs(
    { "resources", "base_tag", "interface" },
    { resources = resources, base_tag = base_tag, interface = interface }
  )
  if not valid then
    return nil, validation_error
  end

  -- Step 1: Collect screen context
  local screen_context = interface.get_screen_context()

  -- Step 2: Plan tag operations
  local plan, plan_error =
    tag_mapper_core.plan_tag_operations(resources, screen_context, base_tag)

  if not plan then
    -- Return planning error directly
    return nil, plan_error
  end

  -- Check if plan has errors that should cause complete failure
  local should_fail, aggregated_error =
    should_fail_on_planning_errors(plan, resources)
  if should_fail then
    return nil, aggregated_error
  end

  -- Step 3: Execute plan
  local execution_results, execution_error =
    integration.execute_tag_plan(plan, interface)

  if not execution_results then
    -- Return execution error directly
    return nil, execution_error
  end

  -- Step 4: Return comprehensive results
  return {
    plan = plan,
    execution = execution_results,
    screen_context = screen_context,
    metadata = {
      total_resources = #resources,
      base_tag = base_tag,
      interface_type = interface.get_execution_log and "dry_run" or "awesome",
    },
  }
end

return integration
