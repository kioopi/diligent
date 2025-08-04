--[[
Interface Centralization Module

Provides centralized access to all AwesomeWM interface implementations.
Eliminates need for direct requires of individual interface modules.
--]]

local interfaces = {
  awesome_interface = require("awe.interfaces.awesome_interface"),
  dry_run_interface = require("awe.interfaces.dry_run_interface"),
  mock_interface = require("awe.interfaces.mock_interface"),
}

return interfaces
