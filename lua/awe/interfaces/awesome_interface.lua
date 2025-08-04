--[[
AwesomeWM Interface Module

Provides clean abstraction layer for all AwesomeWM API interactions.
Centralizes screen, tag, and window management operations to eliminate
code duplication and improve testability.
--]]

local awful_available, awful = pcall(require, "awful")

if not _G._TEST then
  if not awful_available then
    error("Failed to load awful module: " .. tostring(awful))
  end

  local required_awful_modules = { "screen", "tag", "spawn", "placement", }
  for _, module in ipairs(required_awful_modules) do
    if not awful[module] then
      error("Required awful module '" .. module .. "' is not available")
    end
  end
end

local awesome_interface = {}

---Get complete screen context information
---Centralized function to collect all screen-related information needed
---for tag operations, eliminating duplicate awful.screen.focused() calls
---@param screen table|nil Optional screen object (defaults to focused screen)
---@return table context Screen context with current tag, available tags, etc.
function awesome_interface.get_screen_context(screen)
  local target_screen = screen or awesome_interface._get_focused_screen()

  -- Validate screen object
  if not target_screen then
    error("no screen available - awful.screen.focused() returned nil")
  end

  -- Extract screen information with safe fallbacks
  local current_tag_index =
    awesome_interface._get_current_tag_index(target_screen)
  local available_tags = target_screen.tags or {}
  local tag_count = #available_tags

  return {
    screen = target_screen,
    current_tag_index = current_tag_index,
    available_tags = available_tags,
    tag_count = tag_count,
  }
end

---Internal helper to get focused screen
---@return table|nil screen Focused screen or nil if not available
function awesome_interface._get_focused_screen()
  return awful.screen.focused()
end

---Internal helper to get current tag index from screen
---@param screen table Screen object
---@return number index Current tag index (defaults to 1)
function awesome_interface._get_current_tag_index(screen)
  if screen and screen.selected_tag and screen.selected_tag.index then
    return screen.selected_tag.index
  end
  return 1 -- safe fallback
end

---Find tag by name on a specific screen
---Centralized tag lookup to eliminate duplicate awful.tag.find_by_name calls
---@param name string Name of the tag to find
---@param screen table|nil Optional screen object (defaults to focused screen)
---@return table|nil tag Tag object if found, nil otherwise
function awesome_interface.find_tag_by_name(name, screen)
  -- Validate tag name
  if not name or name == "" then
    return nil
  end

  -- Get target screen
  local target_screen = screen or awesome_interface._get_focused_screen()
  if not target_screen then
    return nil
  end

  -- Search through tags
  if target_screen.tags then
    for _, tag in ipairs(target_screen.tags) do
      if tag and tag.name == name then
        return tag
      end
    end
  end

  return nil
end

---Create a new named tag on a specific screen
---Centralized tag creation to eliminate duplicate awful.tag.add calls
---@param name string Name of the tag to create
---@param screen table|nil Optional screen object (defaults to focused screen)
---@return table|nil tag Created tag object or nil on failure
function awesome_interface.create_named_tag(name, screen)
  -- Validate tag name
  if not name or name == "" then
    return nil
  end

  -- Get target screen
  local target_screen = screen or awesome_interface._get_focused_screen()
  if not target_screen then
    return nil
  end

  -- Create tag using AwesomeWM API
  local new_tag = awful.tag.add(name, { screen = target_screen })
  return new_tag
end

---Get all clients from AwesomeWM
---@return table clients List of all client objects
function awesome_interface.get_clients()
  if client and client.get then
    return client.get()
  end
  return {}
end

---Read process environment variables
---@param pid number Process ID
---@return table|nil env_vars Environment variables or nil if not accessible
function awesome_interface.get_process_env(pid)
  local env_file = "/proc/" .. pid .. "/environ"
  local file = io.open(env_file, "r")

  if not file then
    return nil
  end

  local content = file:read("*all")
  file:close()

  if not content then
    return nil
  end

  -- Parse environment variables (null-separated)
  local env_vars = {}
  for var in content:gmatch("([^%z]+)") do
    local key, value = var:match("^([^=]+)=(.*)$")
    if key then
      env_vars[key] = value
    end
  end

  return env_vars
end

---Spawn application using AwesomeWM awful.spawn
---@param command string Command to execute
---@param properties table Spawn properties
---@return number|string pid Process ID or error string
---@return string|nil snid Spawn notification ID
function awesome_interface.spawn(command, properties)
  return awful.spawn(command, properties)
end

---Get placement function from awful.placement
---@param placement_name string Name of placement function
---@return function|nil placement Placement function or nil
function awesome_interface.get_placement(placement_name)
  if awful.placement and awful.placement[placement_name] then
    return awful.placement[placement_name]
  end
  return nil
end

return awesome_interface
