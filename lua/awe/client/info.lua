--[[
Client Info Module Factory

This module provides client information retrieval functionality for AwesomeWM.
It handles extracting comprehensive client data and reading process environment variables.

Key Features:
- Get comprehensive client information with safe fallbacks
- Read and parse process environment variables from /proc
- Extract diligent-specific environment variables
- Clean dependency injection for testing and dry-run support
- Robust error handling for file system operations

Usage:
  local create_info = require("awe.client.info")
  local info = create_info(interface)
  info.get_client_info(client)
  info.read_process_env(pid)
--]]

---Create info module with injected interface
---@param _interface table Interface implementation (awesome, dry_run, mock)
---@return table info Info module with all functions
local function create_info(_interface)
  local info = {}

  ---Get comprehensive client information
  ---@param client table Client object
  ---@return table client_info Comprehensive information about the client
  function info.get_client_info(client)
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

  ---Read environment variables from process
  ---@param pid number Process ID
  ---@return table|nil env_data Environment data with all_vars, diligent_vars, total_count
  ---@return string|nil error_msg Error message if reading failed
  function info.read_process_env(pid)
    local env_file = "/proc/" .. pid .. "/environ"
    local file = io.open(env_file, "r")

    if not file then
      return nil,
        "Cannot open "
          .. env_file
          .. " (process may not exist or no permission)"
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

  return info
end

return create_info
