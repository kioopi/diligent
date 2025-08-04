--[[
Tag Factory Module

Creates tag modules with dependency injection following the awe architecture pattern.
--]]

---Create tag modules with injected interface
---@param interface table Interface implementation (awesome, dry_run, mock)
---@return table tag Tag modules with resolver
local function create_tag_modules(interface)
  local tag = {}

  -- Lazy load resolver with interface injection
  local create_resolver = require("awe.tag.resolver")
  tag.resolver = create_resolver(interface)

  return tag
end

return create_tag_modules
