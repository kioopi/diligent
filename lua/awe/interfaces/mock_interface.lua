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

return mock_interface
