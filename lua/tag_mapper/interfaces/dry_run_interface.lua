--[[
Dry-Run Interface Module

Provides same API as awesome_interface but simulates operations without
executing them. Records all operations for later inspection and reporting.
Perfect for testing and CLI --dry-run functionality.
--]]

local dry_run_interface = {}

-- Internal state to track simulated tags and operations
local simulated_tags = {}
local execution_log = {}
local tag_counter = 0

---Create a mock tag object
---@param name string Name of the tag
---@param index number|nil Optional index for the tag
---@return table tag Mock tag object
local function create_mock_tag(name, index)
  if not index then
    tag_counter = tag_counter + 1
    index = tag_counter
  end

  return {
    name = name,
    index = index,
  }
end

---Log an operation for dry-run reporting
---@param operation string Type of operation (create_tag, find_tag, etc.)
---@param details table Additional details about the operation
local function log_operation(operation, details)
  table.insert(execution_log, {
    operation = operation,
    timestamp = os.time(),
    details = details or {},
    tag_name = details and details.tag_name,
  })
end

---Get complete screen context information (simulated)
---Provides reasonable defaults for dry-run mode
---@param screen table|nil Optional screen object (uses defaults if nil)
---@return table context Simulated screen context
function dry_run_interface.get_screen_context(screen)
  local target_screen = screen

  -- Create default screen if none provided
  if not target_screen then
    target_screen = {
      name = "dry_run_screen",
      selected_tag = { index = 1 },
      tags = {},
    }

    -- Create default numeric tags 1-9
    for i = 1, 9 do
      table.insert(target_screen.tags, create_mock_tag(tostring(i), i))
    end
  end

  -- Extract screen information with safe fallbacks
  local current_tag_index = 1
  if target_screen.selected_tag and target_screen.selected_tag.index then
    current_tag_index = target_screen.selected_tag.index
  end

  local available_tags = target_screen.tags or {}
  local tag_count = #available_tags

  return {
    screen = target_screen,
    current_tag_index = current_tag_index,
    available_tags = available_tags,
    tag_count = tag_count,
  }
end

---Find tag by name (simulated) - internal version without logging
---@param name string Name of the tag to find
---@return table|nil tag Tag object if found, nil otherwise
local function find_tag_internal(name)
  -- Validate tag name
  if not name or name == "" then
    return nil
  end

  -- Search in simulated tags
  for _, tag in ipairs(simulated_tags) do
    if tag.name == name then
      return tag
    end
  end

  return nil
end

---Find tag by name (simulated)
---Searches in simulated tags created during this session
---@param name string Name of the tag to find
---@param screen table|nil Optional screen object (ignored in dry-run)
---@return table|nil tag Tag object if found, nil otherwise
function dry_run_interface.find_tag_by_name(name, screen)
  -- Log the operation
  log_operation("find_tag", { tag_name = name })

  return find_tag_internal(name)
end

---Create a new named tag (simulated)
---Records the creation intent without actually creating in AwesomeWM
---@param name string Name of the tag to create
---@param screen table|nil Optional screen object (ignored in dry-run)
---@return table|nil tag Created tag object or nil on failure
function dry_run_interface.create_named_tag(name, screen)
  -- Validate tag name
  if not name or name == "" then
    return nil
  end

  -- Check if tag already exists (using internal find to avoid double logging)
  local existing_tag = find_tag_internal(name)
  if existing_tag then
    -- Log that we found existing instead of creating
    log_operation("create_tag", {
      tag_name = name,
      result = "existing_found",
      tag_index = existing_tag.index,
    })
    return existing_tag
  end

  -- Create new simulated tag
  local new_tag = create_mock_tag(name)
  table.insert(simulated_tags, new_tag)

  -- Log the creation
  log_operation("create_tag", {
    tag_name = name,
    result = "created",
    tag_index = new_tag.index,
  })

  return new_tag
end

---Get execution log for dry-run reporting
---Returns list of all operations performed during this session
---@return table log List of operation records
function dry_run_interface.get_execution_log()
  return execution_log
end

---Clear execution log
---Resets the operation log for new dry-run session
function dry_run_interface.clear_execution_log()
  execution_log = {}
  simulated_tags = {}
  tag_counter = 0
end

return dry_run_interface
