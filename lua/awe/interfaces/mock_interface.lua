--[[
Mock Interface Module

Provides same API as awesome_interface but returns predictable mock data
for testing purposes. All operations are simulated and deterministic.
--]]

local mock_interface = {}

-- Mock data storage
local mock_data = {
  clients = {},
  process_envs = {},
  spawn_config = {
    success = true,
    pid = 1234,
    snid = "mock-snid",
  },
  placement_functions = {
    centered = function()
      return "mock_centered_placement"
    end,
    top_left = function()
      return "mock_top_left_placement"
    end,
    bottom_right = function()
      return "mock_bottom_right_placement"
    end,
  },
  last_spawn_call = nil,
}

---Get mock screen context information
---Returns consistent mock data for testing
---@param screen table|nil Optional screen object (ignored, uses mock data)
---@return table context Mock screen context
function mock_interface.get_screen_context(screen)
  -- Return consistent mock data for testing
  return {
    screen = { index = 1, name = "mock_screen" },
    current_tag_index = 1,
    available_tags = {
      { name = "1", index = 1 },
      { name = "test", index = 2 },
      { name = "mock", index = 3 },
    },
    tag_count = 3,
  }
end

---Find tag by name (mock)
---Returns predefined mock tags for testing
---@param name string Name of the tag to find
---@param screen table|nil Optional screen object (ignored)
---@return table|nil tag Mock tag object if predefined, nil otherwise
function mock_interface.find_tag_by_name(name, screen)
  -- Validate tag name
  if not name or name == "" then
    return nil
  end

  -- Return mock data for specific test tags
  if name == "test" then
    return { name = "test", index = 2 }
  elseif name == "mock" then
    return { name = "mock", index = 3 }
  elseif name == "1" then
    return { name = "1", index = 1 }
  end

  -- Return nil for unknown tags
  return nil
end

---Create a new named tag (mock)
---Returns mock tag object for testing
---@param name string Name of the tag to create
---@param screen table|nil Optional screen object (ignored)
---@return table|nil tag Mock tag object or nil for invalid names
function mock_interface.create_named_tag(name, screen)
  -- Validate tag name
  if not name or name == "" then
    return nil
  end

  -- Return mock tag object
  return { name = name, index = 2 }
end

---Reset mock data to clean state
---Used for test setup
function mock_interface.reset()
  mock_data.clients = {}
  mock_data.process_envs = {}
  mock_data.spawn_config = {
    success = true,
    pid = 1234,
    snid = "mock-snid",
  }
  mock_data.placement_functions = {
    centered = function()
      return "mock_centered_placement"
    end,
    top_left = function()
      return "mock_top_left_placement"
    end,
    bottom_right = function()
      return "mock_bottom_right_placement"
    end,
  }
  mock_data.last_spawn_call = nil
end

---Set mock clients for testing
---@param clients table List of mock client objects
function mock_interface.set_clients(clients)
  mock_data.clients = clients or {}
end

---Get all mock clients
---@return table clients List of all mock clients
function mock_interface.get_clients()
  return mock_data.clients
end

---Set process environment data for a PID
---@param pid number Process ID
---@param env_vars table Environment variables for the process
function mock_interface.set_process_env(pid, env_vars)
  mock_data.process_envs[pid] = env_vars or {}
end

---Get process environment data for a PID
---@param pid number Process ID
---@return table|nil env_vars Environment variables or nil if not found
function mock_interface.get_process_env(pid)
  return mock_data.process_envs[pid]
end

---Spawn application using mock spawn behavior
---@param command string Command to execute
---@param properties table Spawn properties
---@return number|string pid Process ID or error string
---@return string|nil snid Spawn notification ID
function mock_interface.spawn(command, properties)
  -- Capture the spawn call for testing inspection
  mock_data.last_spawn_call = {
    command = command,
    properties = properties,
  }

  if mock_data.spawn_config.success then
    return mock_data.spawn_config.pid, mock_data.spawn_config.snid
  else
    return mock_data.spawn_config.error or "Mock spawn error"
  end
end

---Get placement function from mock placement registry
---@param placement_name string Name of placement function
---@return function|nil placement Placement function or nil
function mock_interface.get_placement(placement_name)
  return mock_data.placement_functions[placement_name]
end

---Set spawn configuration for testing
---@param config table Spawn configuration {success=bool, pid=number, snid=string, error=string}
function mock_interface.set_spawn_config(config)
  mock_data.spawn_config = config
    or {
      success = true,
      pid = 1234,
      snid = "mock-snid",
    }
end

---Set placement functions for testing
---@param placement_name string Name of placement function
---@param placement_func function Placement function
function mock_interface.set_placement_function(placement_name, placement_func)
  mock_data.placement_functions[placement_name] = placement_func
end

---Get the last spawn call for testing inspection
---@return table|nil spawn_call Table with command and properties, or nil if no calls made
function mock_interface.get_last_spawn_call()
  return mock_data.last_spawn_call
end

return mock_interface
