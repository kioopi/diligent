--[[
Client Properties Module Factory

This module provides client property management functionality for AwesomeWM.
It handles getting and setting client properties with type conversion support.

Key Features:
- Retrieve all client properties with focus on diligent-specific ones
- Set client properties with automatic type conversion
- Clean dependency injection for testing and dry-run support
- Consistent error handling patterns

Usage:
  local create_properties = require("awe.client.properties")
  local properties = create_properties(interface)
  properties.get_client_properties(client)
  properties.set_client_property(pid, "role", "editor")
--]]

---Create properties module with injected interface
---@param interface table Interface implementation (awesome, dry_run, mock)
---@return table properties Properties module with all functions
local function create_properties(interface)
  local properties = {}

  -- Import tracker to find clients by PID
  local tracker = require("awe.client.tracker")(interface)

  ---Get client properties (focusing on diligent_* properties)
  ---@param client table Client object
  ---@return table result Contains all_properties and diligent_properties
  function properties.get_client_properties(client)
    local all_properties = {}
    local diligent_properties = {}

    -- Common diligent properties to check
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
        all_properties[prop_name] = client[prop_name]
        diligent_properties[prop_name] = client[prop_name]
      end
    end

    return {
      all_properties = all_properties,
      diligent_properties = diligent_properties,
    }
  end

  ---Set client property with type conversion
  ---@param pid number Process ID of the client
  ---@param prop_key string Property key to set
  ---@param prop_value any Property value to set (will be converted)
  ---@return boolean success True if property was set successfully
  ---@return string message Success or error message
  function properties.set_client_property(pid, prop_key, prop_value)
    local client_obj, err = tracker.find_by_pid(pid)
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

  return properties
end

return create_properties
