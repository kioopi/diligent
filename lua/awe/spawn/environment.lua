--[[
Spawn Environment Module

Handles environment variable processing for application spawning.
--]]

---Create environment module with injected interface
---@param _interface table Interface implementation (awesome, dry_run, mock)
---@return table environment Environment module functions
local function create_environment(_interface)
  local environment = {}

  ---Build command with environment variables
  ---@param app string Application command
  ---@param env_vars table|nil Environment variables
  ---@return string command Complete command with environment
  function environment.build_command_with_env(app, env_vars)
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

  return environment
end

return create_environment
