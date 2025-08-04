--[[
Client Wait Module Factory

This module provides client waiting and property setting functionality for AwesomeWM.
It handles polling for client appearance and setting properties once clients are found.

Key Features:
- Wait for clients to appear with configurable timeout
- Set multiple properties on clients with result tracking
- Configurable polling intervals and timeouts
- Clean dependency injection for testing and dry-run support
- Comprehensive result reporting for property setting operations

Usage:
  local create_wait = require("awe.client.wait")
  local wait = create_wait(interface)
  wait.wait_and_set_properties(pid, properties, timeout)
--]]

---Create wait module with injected interface
---@param interface table Interface implementation (awesome, dry_run, mock)
---@return table wait Wait module with all functions
local function create_wait(interface)
  local wait = {}

  -- Import tracker and properties modules for functionality
  local tracker = require("awe.client.tracker")(interface)
  local properties = require("awe.client.properties")(interface)

  ---Wait for client to appear and set properties
  ---@param pid number Process ID of the client to wait for
  ---@param properties_to_set table Properties to set on the client once found
  ---@param timeout number|nil Timeout in seconds (defaults to 5)
  ---@return boolean success True if client was found and properties set
  ---@return table|string results Table of property setting results, or error message
  function wait.wait_and_set_properties(pid, properties_to_set, timeout)
    timeout = timeout or 5
    local start_time = os.time()

    while os.time() - start_time < timeout do
      local client_obj = tracker.find_by_pid(pid)
      if client_obj then
        -- Client found, set properties
        local results = {}
        for key, value in pairs(properties_to_set) do
          local success, msg = properties.set_client_property(pid, key, value)
          results[key] = { success = success, message = msg }
        end
        return true, results
      end

      -- Wait a bit before checking again
      os.execute("sleep 0.5")
    end

    return false, "Timeout waiting for client to appear"
  end

  return wait
end

return create_wait
