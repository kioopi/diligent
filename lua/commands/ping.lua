--[[
Ping Command Script for Diligent CLI

Implements the ping command that tests communication with AwesomeWM via D-Bus.
This is a standalone script that can be executed directly or via lua_cliargs :file().
--]]

-- Setup package path to find lua modules
local script_dir = arg and arg[0] and arg[0]:match("(.+)/[^/]+$") or "."
package.path = script_dir
  .. "/../?.lua;"
  .. script_dir
  .. "/../../lua/?.lua;"
  .. package.path

local dbus = require("dbus_communication")
local p = require("cli_printer")

local awesome_success, result = pcall(dbus.check_awesome_available)
local available = awesome_success and result

if not awesome_success then
  p.error("Error checking AwesomeWM availability: " .. tostring(result))
  os.exit(1)
end

if not available then
  p.error("AwesomeWM not available via D-Bus")
  p.info("  • Make sure AwesomeWM is running")
  p.info("  • Check that D-Bus session bus is available")
  p.info("  • Verify AwesomeWM has D-Bus support enabled")
  os.exit(1)
end

-- Send ping command and wait for response
local payload = {
  timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  source = "diligent-cli",
}

local success, response = dbus.send_ping(payload)

if not success then
  p.error("Failed to get response: " .. response)
  p.info("")
  p.info("Troubleshooting:")
  p.info("  • Ensure the Diligent module is loaded in your AwesomeWM rc.lua:")
  p.info("    local diligent = require('diligent')")
  p.info("    diligent.setup()")
  p.info("  • Check that the lua/ directory is in your Lua path")
  os.exit(1)
end

p.success("Ping successful!")
p.info("Response: " .. response)

-- Check if response is valid JSON
local parse_success, error = dbus.parse_response(response)
if not parse_success then
  p.error("Could not JSON parse response " .. tostring(error))
end
