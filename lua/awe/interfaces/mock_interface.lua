--[[
Mock Interface Module

Provides same API as awesome_interface but returns predictable mock data
for testing purposes. All operations are simulated and deterministic.
--]]

local mock_interface = {}

---Get mock screen context information
---Returns consistent mock data for testing
---@param screen table|nil Optional screen object (ignored, uses mock data)
---@return table context Mock screen context
function mock_interface.get_screen_context(screen)
  -- Return consistent mock data for testing
  return {
    screen = { index = 1, name = "mock_screen" },
    current_tag_index = 1,
    available_tags = {
      { name = "1", index = 1 },
      { name = "test", index = 2 },
      { name = "mock", index = 3 },
    },
    tag_count = 3,
  }
end

---Find tag by name (mock)
---Returns predefined mock tags for testing
---@param name string Name of the tag to find
---@param screen table|nil Optional screen object (ignored)
---@return table|nil tag Mock tag object if predefined, nil otherwise
function mock_interface.find_tag_by_name(name, screen)
  -- Validate tag name
  if not name or name == "" then
    return nil
  end

  -- Return mock data for specific test tags
  if name == "test" then
    return { name = "test", index = 2 }
  elseif name == "mock" then
    return { name = "mock", index = 3 }
  elseif name == "1" then
    return { name = "1", index = 1 }
  end

  -- Return nil for unknown tags
  return nil
end

---Create a new named tag (mock)
---Returns mock tag object for testing
---@param name string Name of the tag to create
---@param screen table|nil Optional screen object (ignored)
---@return table|nil tag Mock tag object or nil for invalid names
function mock_interface.create_named_tag(name, screen)
  -- Validate tag name
  if not name or name == "" then
    return nil
  end

  -- Return mock tag object
  return { name = name, index = 2 }
end

return mock_interface
