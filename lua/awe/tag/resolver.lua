--[[
Tag Resolver Module

Handles tag resolution by integrating with tag_mapper and providing 
convenient API for AwesomeWM context with dependency injection.
--]]

---Create resolver module with injected interface
---@param interface table Interface implementation (awesome, dry_run, mock)
---@return table resolver Resolver module functions
local function create_resolver(interface)
  local resolver = {}
  local tag_mapper = require("tag_mapper")
  
  ---Resolve tag specification using tag_mapper
  ---@param tag_spec string|number Tag specification
  ---@param options table|nil Optional parameters
  ---@return boolean success Success indicator
  ---@return table|string result Tag object or error message
  function resolver.resolve_tag_spec(tag_spec, options)
    options = options or {}
    
    -- Get current tag from interface or options
    local base_tag
    if interface.get_current_tag then
      base_tag = interface.get_current_tag()
    else
      base_tag = options.base_tag or 1  -- fallback
    end
    
    -- Convert string formats to appropriate types for tag_mapper
    local structured_spec
    
    if tag_spec == "0" then
      structured_spec = 0  -- relative to current
    elseif type(tag_spec) == "string" and tag_spec:match("^[+](%d+)$") then
      local offset = tonumber(tag_spec:match("^[+](%d+)$"))
      structured_spec = offset  -- positive relative offset
    elseif type(tag_spec) == "string" and tag_spec:match("^[-](%d+)$") then
      local offset = tonumber(tag_spec:match("^[-](%d+)$"))
      structured_spec = -offset  -- negative relative offset
    elseif type(tag_spec) == "string" and tag_spec:match("^%d+$") then
      structured_spec = tag_spec  -- absolute string
    else
      structured_spec = tag_spec  -- named tag or other
    end
    
    -- Use tag_mapper for actual resolution (pass interface to avoid circular dependency)
    return tag_mapper.resolve_tag(structured_spec, base_tag, interface)
  end
  
  return resolver
end

return create_resolver