--[[
Spawn Configuration Module

Handles spawn property building and configuration validation.
--]]

---Create configuration module with injected interface
---@param interface table Interface implementation (awesome, dry_run, mock)
---@return table configuration Configuration module functions
local function create_configuration(interface)
  local configuration = {}

  ---Build spawn properties from configuration
  ---@param tag table Tag object
  ---@param config table Configuration options
  ---@return table properties Spawn properties
  function configuration.build_spawn_properties(tag, config)
    local properties = {}

    -- Add tag if provided
    if tag then
      properties.tag = tag
    end

    -- Add floating
    if config.floating then
      properties.floating = true
    end

    -- Add placement
    if config.placement then
      if interface.get_placement then
        properties.placement = interface.get_placement(config.placement)
      else
        -- Fallback for testing - just indicate placement was set
        properties.placement = config.placement
      end
    end

    -- Add dimensions
    if config.width then
      properties.width = config.width
    end
    if config.height then
      properties.height = config.height
    end

    return properties
  end

  return configuration
end

return create_configuration
