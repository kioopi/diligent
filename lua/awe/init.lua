--[[
AwesomeWM Module (awe)

Main entry point for AwesomeWM integration functionality.
Provides direct access to all interfaces and sub-modules.

This module follows the refactoring plan to create a modular,
testable architecture for AwesomeWM interaction.
--]]

local awe = {}

-- Direct access to interfaces
awe.awesome_interface = require("awe.interfaces.awesome_interface")
awe.dry_run_interface = require("awe.interfaces.dry_run_interface")
awe.mock_interface = require("awe.interfaces.mock_interface")

return awe
