--[[
Client Module Factory

Creates client management modules with dependency injection support.
Enables clean testing and interface swapping for dry-run mode.

Usage:
  local client = require("awe.client")(interface)
  client.tracker.find_by_pid(1234)
  client.properties.set_client_property(1234, "role", "editor")
--]]

local create_tracker = require("awe.client.tracker")
local create_properties = require("awe.client.properties")
local create_info = require("awe.client.info")
local create_wait = require("awe.client.wait")

---Create client management modules with injected interface
---@param interface table Interface implementation (awesome, dry_run, mock)
---@return table client Client modules with tracker, properties, info, wait
local function create_client(interface)
  return {
    tracker = create_tracker(interface),
    properties = create_properties(interface),
    info = create_info(interface),
    wait = create_wait(interface),
  }
end

return create_client
