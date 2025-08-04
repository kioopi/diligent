--[[
Client Tracker Module Factory

This module provides client finding and tracking functionality for AwesomeWM.
It implements various search methods to locate clients by different criteria.

Key Features:
- Find clients by PID, environment variables, properties, or name/class
- Track all clients with diligent-specific configuration
- Consistent API patterns with proper error handling
- Clean dependency injection for testing and dry-run support

Usage:
  local create_tracker = require("awe.client.tracker")
  local tracker = create_tracker(interface)
  tracker.find_by_pid(1234)
--]]

---Create tracker module with injected interface
---@param interface table Interface implementation (awesome, dry_run, mock)
---@return table tracker Tracker module with all functions
local function create_tracker(interface)
  local tracker = {}

  ---Find client by PID
  ---@param target_pid number|string Process ID to search for
  ---@return table|nil client Client object if found, nil otherwise
  ---@return string|nil error_msg Error message if client not found or invalid PID
  function tracker.find_by_pid(target_pid)
    local pid = tonumber(target_pid)
    if not pid then
      return nil, "Invalid PID format"
    end

    local clients = interface.get_clients()
    for _, c in ipairs(clients) do
      if c.pid == pid then
        return c
      end
    end

    return nil, "No client found with PID " .. target_pid
  end

  ---Find clients by environment variable
  ---@param env_key string Environment variable key to search for
  ---@param env_value string Environment variable value to match
  ---@return table clients List of matching client objects (may be empty)
  function tracker.find_by_env(env_key, env_value)
    local matching_clients = {}
    local clients = interface.get_clients()

    for _, c in ipairs(clients) do
      if c.pid then
        local env_data = interface.get_process_env(c.pid)
        if env_data and env_data[env_key] == env_value then
          table.insert(matching_clients, c)
        end
      end
    end

    return matching_clients
  end

  ---Find clients by property
  ---@param prop_key string Property key to search for
  ---@param prop_value any Property value to match
  ---@return table clients List of matching client objects (may be empty)
  function tracker.find_by_property(prop_key, prop_value)
    local matching_clients = {}
    local clients = interface.get_clients()

    for _, c in ipairs(clients) do
      if c[prop_key] == prop_value then
        table.insert(matching_clients, c)
      end
    end

    return matching_clients
  end

  ---Find clients by name or class substring (case insensitive)
  ---@param search_term string Substring to search for in name or class
  ---@return table clients List of matching client objects (may be empty)
  function tracker.find_by_name_or_class(search_term)
    local matching_clients = {}
    local clients = interface.get_clients()
    local search_lower = search_term:lower()

    for _, c in ipairs(clients) do
      local name = (c.name or ""):lower()
      local class = (c.class or ""):lower()

      if name:find(search_lower) or class:find(search_lower) then
        table.insert(matching_clients, c)
      end
    end

    return matching_clients
  end

  ---Get all clients with any diligent tracking information
  ---Checks for both environment variables and client properties
  ---@return table clients List of tracked client objects (may be empty)
  function tracker.get_all_tracked_clients()
    local tracked_clients = {}
    local clients = interface.get_clients()

    for _, c in ipairs(clients) do
      local has_tracking = false

      -- Check for diligent environment variables
      if c.pid then
        local env_data = interface.get_process_env(c.pid)
        if env_data then
          for key, _ in pairs(env_data) do
            if key:match("^DILIGENT_") then
              has_tracking = true
              break
            end
          end
        end
      end

      -- Check for diligent client properties
      if not has_tracking then
        local diligent_properties = {
          "diligent_project",
          "diligent_role",
          "diligent_resource_id",
          "diligent_workspace",
          "diligent_start_time",
          "diligent_managed",
        }

        for _, prop_name in ipairs(diligent_properties) do
          if c[prop_name] ~= nil then
            has_tracking = true
            break
          end
        end
      end

      if has_tracking then
        table.insert(tracked_clients, c)
      end
    end

    return tracked_clients
  end

  return tracker
end

return create_tracker
