--[[
AwesomeWM Module (awe)

Main entry point for AwesomeWM integration functionality.
Provides instance-based dependency injection for clean testing and dry-run support.

Usage:
  local awe = require("awe")
  
  -- Default instance with awesome_interface
  awe.client.tracker.find_by_pid(1234)
  
  -- Create test instance with mock interface
  local test_awe = awe.create(awe.interfaces.mock_interface)
  test_awe.client.tracker.find_by_pid(1234)
  
  -- Create dry-run instance
  local dry_awe = awe.create(awe.interfaces.dry_run_interface)
--]]

local interfaces = require("awe.interfaces")
local create_client = require("awe.client")

local awe = {
  -- Default instance with awesome_interface
  client = create_client(interfaces.awesome_interface),

  -- Direct access to interfaces
  interfaces = interfaces,

  -- Backward compatibility - can be deprecated later
  awesome_interface = interfaces.awesome_interface,
  dry_run_interface = interfaces.dry_run_interface,
  mock_interface = interfaces.mock_interface,
}

---Create awe instance with specific interface
---@param interface table Interface implementation (awesome, dry_run, mock)
---@return table awe_instance Instance with client modules using specified interface
function awe.create(interface)
  interface = interface or interfaces.awesome_interface

  return {
    client = create_client(interface),
    interfaces = interfaces,
  }
end

return awe
