--[[
Start Processor Helper Functions

Common processing logic extracted from start_processor to eliminate duplication
and support multiple resource types (app, term, etc.).

This module provides reusable functions for:
- Resource definition to request format conversion 
- Supported resource type management
- Clean architectural separation between DSL helpers and start processor

Supported Resource Types:
- "app": Generic X11 applications (firefox, gedit, etc.)
- "term": Terminal applications (bash, nvim, etc.)
--]]

local start_processor_helpers = {}

---Convert resource definition to standardized request format
---Transforms normalized resource definitions into standardized start request format.
---No validation or default application - expects pre-normalized input from helper modules.
---@param name string Resource name for the request
---@param resource_def table Normalized resource definition from helper.create() with all defaults applied
---@param resource_type string Type of resource ("app", "term", etc.) for field mapping
---@return table request_resource Standardized resource request with name, command, tag_spec, etc.
function start_processor_helpers.convert_resource_to_request_format(
  name,
  resource_def,
  resource_type
)
  -- Base fields common to all resource types (simple format transformation)
  local request_resource = {
    name = name,
    command = resource_def.cmd,
    tag_spec = resource_def.tag, -- Use as-is (already processed by helpers)
    working_dir = resource_def.dir,
  }

  -- Copy type-specific fields as-is (no defaults - already applied by helpers)
  if resource_type == "app" then
    request_resource.reuse = resource_def.reuse
  elseif resource_type == "term" then
    request_resource.interactive = resource_def.interactive
    request_resource.terminal = resource_def.terminal
  end

  return request_resource
end

---Get list of currently supported resource types
---Returns list of resource types that can be processed by start_processor.
---Used for filtering DSL resources during conversion.
---@return string[] types List of supported resource type strings
function start_processor_helpers.get_supported_resource_types()
  return { "app", "term" }
end

return start_processor_helpers
