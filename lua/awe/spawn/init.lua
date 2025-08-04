--[[
Spawn Module Factory

Creates spawn management modules with dependency injection support.
Enables clean testing and interface swapping for dry-run mode.

Usage:
  local spawn = require("awe.spawn")(interface)
  spawn.environment.build_command_with_env("firefox", {DISPLAY=":0"})
  spawn.configuration.build_spawn_properties(tag, config)
  spawn.spawner.spawn_with_properties("firefox", "+1", {floating=true})
--]]

local create_environment = require("awe.spawn.environment")
local create_configuration = require("awe.spawn.configuration")
local create_spawner = require("awe.spawn.spawner")

---Create spawn management modules with injected interface
---@param interface table Interface implementation (awesome, dry_run, mock)
---@return table spawn Spawn modules with environment, configuration, spawner
local function create_spawn(interface)
  return {
    environment = create_environment(interface),
    configuration = create_configuration(interface),
    spawner = create_spawner(interface),
  }
end

return create_spawn
