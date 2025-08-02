--[[
Tag Mapper Integration Module

Coordinates between the pure core logic and interface layers.
Provides high-level functions that orchestrate the complete tag resolution workflow.
--]]

local integration = {}

-- Load dependencies
local tag_mapper_core = require("tag_mapper.core")

---Execute tag plan via provided interface
---Takes a structured plan and executes the operations using the given interface
---@param plan table Tag operation plan from tag_mapper_core.plan_tag_operations()
---@param interface table Interface object (awesome_interface or dry_run_interface)
---@return table results Structured execution results
function integration.execute_tag_plan(plan, interface)
  -- Input validation
  if plan == nil then
    error("plan is required")
  end

  if interface == nil then
    error("interface is required")
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
    local created_tag =
      interface.create_named_tag(creation.name, creation.screen)

    if created_tag then
      table.insert(results.created_tags, {
        name = creation.name,
        tag = created_tag,
        operation = "create",
      })
    else
      table.insert(results.failures, {
        operation = "create_tag",
        tag_name = creation.name,
        error = "failed to create tag: " .. creation.name,
      })
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
  if resources == nil then
    error("resources list is required")
  end

  if base_tag == nil then
    error("base tag is required")
  end

  if interface == nil then
    error("interface is required")
  end

  -- Step 1: Collect screen context
  local screen_context = interface.get_screen_context()

  -- Step 2: Plan tag operations
  local plan =
    tag_mapper_core.plan_tag_operations(resources, screen_context, base_tag)

  -- Step 3: Execute plan
  local execution_results = integration.execute_tag_plan(plan, interface)

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
