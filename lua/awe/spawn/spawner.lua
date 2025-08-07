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
  ---@param target_tag table Resolved tag object with index and name properties
  ---@param config table Configuration options
  ---@return number|nil pid Process ID
  ---@return string|nil snid Spawn notification ID
  ---@return string message Result message
  function spawner.spawn_with_properties(app, target_tag, config)
    config = config or {}

    -- Handle JSON decoding quirk where {} becomes false
    if config == false then
      config = {}
    end

    -- Validate that we received a resolved tag object
    if type(target_tag) ~= "table" or not target_tag.index then
      return nil,
        nil,
        "Invalid tag object: expected resolved tag with index property"
    end

    -- Step 1: Build properties using configuration module
    local create_configuration = require("awe.spawn.configuration")
    local configuration = create_configuration(interface)
    local properties = configuration.build_spawn_properties(target_tag, config)

    -- Step 2: Build command with environment variables using environment module
    local create_environment = require("awe.spawn.environment")
    local environment = create_environment(interface)
    local command = environment.build_command_with_env(app, config.env_vars)

    -- Step 3: Spawn application using interface
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

  ---Simplified spawn interface (convenience function with tag resolution)
  ---@param app string Application command
  ---@param tag_spec string Tag specification
  ---@return number|nil pid Process ID
  ---@return string|nil snid Spawn notification ID
  ---@return string message Result message
  function spawner.spawn_simple(app, tag_spec)
    -- Resolve tag specification using tag_mapper for convenience function
    local tag_mapper = require("tag_mapper")
    local current_tag_index = tag_mapper.get_current_tag(interface)
    local success, target_tag =
      tag_mapper.resolve_tag(tag_spec, current_tag_index, interface)

    if not success then
      return nil, nil, "Tag resolution failed: " .. target_tag
    end

    -- Call main function with resolved tag
    return spawner.spawn_with_properties(app, target_tag, {})
  end

  return spawner
end

return create_spawner
