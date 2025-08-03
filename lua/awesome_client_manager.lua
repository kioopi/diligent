--[[
AwesomeWM Client Manager

This module provides comprehensive client tracking and spawning functionality
for AwesomeWM integration. It extracts the core functionality previously 
embedded in manual exploration scripts into a reusable library.

Features:
- Client information retrieval and tracking
- Environment variable management for processes
- Client property management 
- Multiple client search methods (PID, env vars, properties, name/class)
- Tag resolution and spawning with full property support
- Environment variable injection during spawn

This module is designed to work within the AwesomeWM context via D-Bus
communication and provides the foundation for Diligent's client management.
--]]

local awesome_client_manager = {}

-- Dependencies (available in AwesomeWM context)
local awful = require("awful")
local client = client -- Global AwesomeWM client module

--==============================================================================
-- CLIENT TRACKING FUNCTIONS
--==============================================================================

-- Get comprehensive client information
function awesome_client_manager.get_client_info(client)
  return {
    pid = client.pid,
    name = client.name or "unnamed",
    class = client.class or "unknown",
    instance = client.instance or "unknown",
    window_title = client.name or "untitled",
    tag_index = client.first_tag and client.first_tag.index or 0,
    tag_name = client.first_tag and client.first_tag.name or "no tag",
    screen_index = client.screen and client.screen.index or 0,
    floating = client.floating or false,
    minimized = client.minimized or false,
    maximized = client.maximized or false,
    geometry = {
      x = client.x or 0,
      y = client.y or 0,
      width = client.width or 0,
      height = client.height or 0,
    },
  }
end

-- Read environment variables from process
function awesome_client_manager.read_process_env(pid)
  local env_file = "/proc/" .. pid .. "/environ"
  local file = io.open(env_file, "r")

  if not file then
    return nil,
      "Cannot open " .. env_file .. " (process may not exist or no permission)"
  end

  local content = file:read("*all")
  file:close()

  if not content then
    return nil, "Cannot read environ file"
  end

  -- Parse environment variables (null-separated)
  local env_vars = {}
  local diligent_vars = {}

  for var in content:gmatch("([^%z]+)") do
    local key, value = var:match("^([^=]+)=(.*)$")
    if key then
      env_vars[key] = value
      if key:match("^DILIGENT_") then
        diligent_vars[key] = value
      end
    end
  end

  return {
    all_vars = env_vars,
    diligent_vars = diligent_vars,
    total_count = (function()
      local count = 0
      for _ in pairs(env_vars) do
        count = count + 1
      end
      return count
    end)(),
  }
end

-- Get client properties (focusing on diligent_* properties)
function awesome_client_manager.get_client_properties(client)
  local properties = {}
  local diligent_properties = {}

  -- Common properties to check
  local property_names = {
    "diligent_project",
    "diligent_role",
    "diligent_resource_id",
    "diligent_workspace",
    "diligent_start_time",
    "diligent_managed",
  }

  for _, prop_name in ipairs(property_names) do
    if client[prop_name] ~= nil then
      properties[prop_name] = client[prop_name]
      diligent_properties[prop_name] = client[prop_name]
    end
  end

  return {
    all_properties = properties,
    diligent_properties = diligent_properties,
  }
end

-- Find client by PID
function awesome_client_manager.find_by_pid(target_pid)
  target_pid = tonumber(target_pid)
  if not target_pid then
    return nil, "Invalid PID format"
  end

  for _, c in ipairs(client.get()) do
    if c.pid == target_pid then
      return c
    end
  end

  return nil, "No client found with PID " .. target_pid
end

-- Find clients by environment variable
function awesome_client_manager.find_by_env(env_key, env_value)
  local matching_clients = {}

  for _, c in ipairs(client.get()) do
    if c.pid then
      local env_data, err = awesome_client_manager.read_process_env(c.pid)
      if env_data and env_data.all_vars[env_key] == env_value then
        table.insert(matching_clients, c)
      end
    end
  end

  return matching_clients
end

-- Find clients by property
function awesome_client_manager.find_by_property(prop_key, prop_value)
  local matching_clients = {}

  for _, c in ipairs(client.get()) do
    if c[prop_key] == prop_value then
      table.insert(matching_clients, c)
    end
  end

  return matching_clients
end

-- Find clients by name or class
function awesome_client_manager.find_by_name_or_class(search_term)
  local matching_clients = {}
  local search_lower = search_term:lower()

  for _, c in ipairs(client.get()) do
    local name = (c.name or ""):lower()
    local class = (c.class or ""):lower()

    if name:find(search_lower) or class:find(search_lower) then
      table.insert(matching_clients, c)
    end
  end

  return matching_clients
end

-- Set client property
function awesome_client_manager.set_client_property(pid, prop_key, prop_value)
  local client_obj, err = awesome_client_manager.find_by_pid(pid)
  if not client_obj then
    return false, err
  end

  -- Convert string values to appropriate types
  if prop_value == "true" then
    prop_value = true
  elseif prop_value == "false" then
    prop_value = false
  elseif tonumber(prop_value) then
    prop_value = tonumber(prop_value)
  end

  client_obj[prop_key] = prop_value
  return true, "Property " .. prop_key .. " set to " .. tostring(prop_value)
end

-- Get all clients with any tracking information
function awesome_client_manager.get_all_tracked_clients()
  local tracked_clients = {}

  for _, c in ipairs(client.get()) do
    local has_tracking = false

    -- Check for environment variables
    local env_data = nil
    if c.pid then
      env_data, _ = awesome_client_manager.read_process_env(c.pid)
      if env_data and next(env_data.diligent_vars) then
        has_tracking = true
      end
    end

    -- Check for client properties
    local prop_data = awesome_client_manager.get_client_properties(c)
    if next(prop_data.diligent_properties) then
      has_tracking = true
    end

    if has_tracking then
      table.insert(tracked_clients, c)
    end
  end

  return tracked_clients
end

--==============================================================================
-- TAG RESOLUTION AND SPAWNING FUNCTIONS
--==============================================================================

-- Resolve tag specification to actual tag object
function awesome_client_manager.resolve_tag_spec(tag_spec)
  local screen = awful.screen.focused()
  local tags = screen.tags
  local current_tag = screen.selected_tag

  local target_tag = nil
  local error_msg = nil

  -- Parse tag specification
  if tag_spec == "0" then
    -- Current tag
    target_tag = current_tag
  elseif tag_spec:match("^%+(%d+)$") then
    -- Relative positive (current + N)
    local offset = tonumber(tag_spec:match("^%+(%d+)$"))
    local target_index = current_tag.index + offset
    if target_index <= #tags then
      target_tag = tags[target_index]
    else
      error_msg = "Target index "
        .. target_index
        .. " exceeds available tags ("
        .. #tags
        .. ")"
    end
  elseif tag_spec:match("^%-(%d+)$") then
    -- Relative negative (current - N)
    local offset = tonumber(tag_spec:match("^%-(%d+)$"))
    local target_index = current_tag.index - offset
    if target_index >= 1 then
      target_tag = tags[target_index]
    else
      error_msg = "Target index " .. target_index .. " is less than 1"
    end
  elseif tag_spec:match("^(%d+)$") then
    -- Absolute index
    local target_index = tonumber(tag_spec)
    if target_index >= 1 and target_index <= #tags then
      target_tag = tags[target_index]
    else
      error_msg = "Tag index "
        .. target_index
        .. " not found (available: 1-"
        .. #tags
        .. ")"
    end
  else
    -- Named tag - search for existing or create new
    for _, tag in ipairs(tags) do
      if tag.name == tag_spec then
        target_tag = tag
        break
      end
    end

    if not target_tag then
      -- Create new named tag
      target_tag = awful.tag.add(tag_spec, {
        screen = screen,
        layout = awful.layout.layouts[1], -- Use first available layout
      })
    end
  end

  if target_tag then
    return target_tag,
      "Resolved to tag '"
        .. tostring(target_tag.name or "unnamed")
        .. "' (index: "
        .. target_tag.index
        .. ", screen: "
        .. screen.index
        .. ")"
  else
    return nil, error_msg or "Unknown error"
  end
end

-- Build spawn properties from configuration
function awesome_client_manager.build_spawn_properties(tag, config)
  local properties = {}

  -- Add tag if provided
  if tag then
    properties.tag = tag
  end

  -- Add floating
  if config.floating then
    properties.floating = true
  end

  -- Add placement
  if config.placement then
    properties.placement = awful.placement[config.placement]
  end

  -- Add dimensions
  if config.width then
    properties.width = config.width
  end
  if config.height then
    properties.height = config.height
  end

  return properties
end

-- Build command with environment variables
function awesome_client_manager.build_command_with_env(app, env_vars)
  local command = app

  -- Handle JSON decoding quirk and add environment variables if provided
  if
    env_vars
    and env_vars ~= false
    and type(env_vars) == "table"
    and next(env_vars)
  then
    local env_setup = {}
    for key, value in pairs(env_vars) do
      table.insert(env_setup, key .. "=" .. value)
    end
    command = "env " .. table.concat(env_setup, " ") .. " " .. command
  end

  return command
end

-- Spawn application with full configuration
function awesome_client_manager.spawn_with_properties(app, tag_spec, config)
  config = config or {}

  -- Handle JSON decoding quirk where {} becomes false
  if config == false then
    config = {}
  end

  -- Step 1: Resolve tag
  local target_tag, resolve_msg =
    awesome_client_manager.resolve_tag_spec(tag_spec)
  if not target_tag then
    return nil, nil, "Tag resolution failed: " .. resolve_msg
  end

  -- Step 2: Build properties
  local properties =
    awesome_client_manager.build_spawn_properties(target_tag, config)

  -- Step 3: Build command with environment variables
  local command =
    awesome_client_manager.build_command_with_env(app, config.env_vars)

  -- Step 4: Spawn application
  local pid, snid = awful.spawn(command, properties)

  -- Check result
  if type(pid) == "string" then
    return nil, nil, pid -- Error string
  else
    return pid,
      snid,
      "SUCCESS: Spawned "
        .. app
        .. " (PID: "
        .. pid
        .. ", Tag: "
        .. (target_tag.name or "unnamed")
        .. "["
        .. target_tag.index
        .. "])"
  end
end

-- Simplified spawn interface
function awesome_client_manager.spawn_simple(app, tag_spec)
  return awesome_client_manager.spawn_with_properties(app, tag_spec, {})
end

-- Wait for client to appear and set properties
function awesome_client_manager.wait_and_set_properties(
  pid,
  properties,
  timeout
)
  timeout = timeout or 5
  local start_time = os.time()

  while os.time() - start_time < timeout do
    local client_obj = awesome_client_manager.find_by_pid(pid)
    if client_obj then
      -- Client found, set properties
      local results = {}
      for key, value in pairs(properties) do
        local success, msg =
          awesome_client_manager.set_client_property(pid, key, value)
        results[key] = { success = success, message = msg }
      end
      return true, results
    end

    -- Wait a bit before checking again
    os.execute("sleep 0.5")
  end

  return false, "Timeout waiting for client to appear"
end

--==============================================================================
-- ERROR REPORTING FRAMEWORK (using awe.error modules)
--==============================================================================

-- Create error handler instance
local error_handler = require("awe.error").create()

-- Expose ERROR_TYPES for backward compatibility
awesome_client_manager.ERROR_TYPES = error_handler.classifier.ERROR_TYPES

-- Delegate error classification to new module
function awesome_client_manager.classify_error(error_message)
  return error_handler.classifier.classify_error(error_message)
end

-- Delegate error report creation to new module
function awesome_client_manager.create_error_report(
  app_name,
  tag_spec,
  error_message,
  context
)
  return error_handler.reporter.create_error_report(
    app_name,
    tag_spec,
    error_message,
    context
  )
end

-- Delegate error suggestions to new module
function awesome_client_manager.get_error_suggestions(error_type, app_name)
  return error_handler.reporter.get_error_suggestions(error_type, app_name)
end

-- Delegate spawn summary creation to new module
function awesome_client_manager.create_spawn_summary(spawn_results)
  return error_handler.reporter.create_spawn_summary(spawn_results)
end

-- Delegate error formatting to new module
function awesome_client_manager.format_error_for_user(error_report)
  return error_handler.formatter.format_error_for_user(error_report)
end

-- Enhanced spawn function with comprehensive error reporting
function awesome_client_manager.spawn_with_error_reporting(
  app,
  tag_spec,
  config
)
  config = config or {}
  local context = {
    config = config,
    attempt_time = os.time(),
  }

  -- Attempt spawn
  local pid, snid, msg =
    awesome_client_manager.spawn_with_properties(app, tag_spec, config)

  local result = {
    app_name = app,
    tag_spec = tag_spec,
    success = pid ~= nil,
    pid = pid,
    snid = snid,
    message = msg,
  }

  if not result.success then
    result.error_report =
      awesome_client_manager.create_error_report(app, tag_spec, msg, context)
  end

  return result
end

--==============================================================================
-- UTILITY FUNCTIONS
--==============================================================================

-- Check if awesome_client_manager is properly loaded
function awesome_client_manager.check_status()
  return {
    module_loaded = true,
    awful_available = awful ~= nil,
    client_available = client ~= nil,
    functions_count = (function()
      local count = 0
      for _ in pairs(awesome_client_manager) do
        count = count + 1
      end
      return count
    end)(),
  }
end

return awesome_client_manager
