--[[
Core Spawner Module

Handles the core application spawning logic.
--]]

---Create spawner module with injected interface
---@param interface table Interface implementation (awesome, dry_run, mock)
---@return table spawner Spawner module functions
local function create_spawner(interface)
  local spawner = {}

  ---Spawn application with properties
  ---@param app string Application command
  ---@param tag_spec string Tag specification
  ---@param config table Configuration options
  ---@return number|nil pid Process ID
  ---@return string|nil snid Spawn notification ID
  ---@return string message Result message
  function spawner.spawn_with_properties(app, tag_spec, config)
    config = config or {}

    -- Handle JSON decoding quirk where {} becomes false
    if config == false then
      config = {}
    end

    -- Step 1: Resolve tag
    -- For now, we'll use the awesome_client_manager's resolve_tag_spec
    -- This will be moved to a proper tag resolver in Phase 5
    local target_tag, resolve_msg
    if
      interface.awesome_client_manager
      and interface.awesome_client_manager.resolve_tag_spec
    then
      target_tag, resolve_msg =
        interface.awesome_client_manager.resolve_tag_spec(tag_spec)
    else
      -- For mock/test interfaces, provide a simple fallback
      target_tag = { name = "test", index = 1 }
      resolve_msg = "Mock tag resolved"
    end

    if not target_tag then
      return nil, nil, "Tag resolution failed: " .. resolve_msg
    end

    -- Step 2: Build properties using configuration module
    local create_configuration = require("awe.spawn.configuration")
    local configuration = create_configuration(interface)
    local properties = configuration.build_spawn_properties(target_tag, config)

    -- Step 3: Build command with environment variables using environment module
    local create_environment = require("awe.spawn.environment")
    local environment = create_environment(interface)
    local command = environment.build_command_with_env(app, config.env_vars)

    -- Step 4: Spawn application using interface
    local pid, snid
    if interface.spawn then
      pid, snid = interface.spawn(command, properties)
    else
      -- Fallback error for interfaces without spawn support
      return nil, nil, "Interface does not support spawning"
    end

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

  ---Simplified spawn interface
  ---@param app string Application command
  ---@param tag_spec string Tag specification
  ---@return number|nil pid Process ID
  ---@return string|nil snid Spawn notification ID
  ---@return string message Result message
  function spawner.spawn_simple(app, tag_spec)
    return spawner.spawn_with_properties(app, tag_spec, {})
  end

  return spawner
end

return create_spawner
