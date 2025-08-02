#!/usr/bin/env lua
--[[
Manual Spawn Tool for Interactive Testing

This tool allows manual testing of app spawning with various tag specifications
and properties. Perfect for exploring individual app behavior and tag mapper integration.

Usage:
  lua examples/spawning/manual_spawn.lua <app> <tag_spec> [options]

Examples:
  lua examples/spawning/manual_spawn.lua firefox 0          # Spawn to current tag
  lua examples/spawning/manual_spawn.lua gedit +2           # Spawn to current tag + 2
  lua examples/spawning/manual_spawn.lua xterm "editor"     # Spawn to named tag "editor"
  lua examples/spawning/manual_spawn.lua nemo 3 --floating  # Spawn to tag 3, floating
  lua examples/spawning/manual_spawn.lua xcalc 0 --floating --placement=top_left

Options:
  --floating          Make the window floating
  --placement=<pos>   Window placement (top_left, top_right, bottom_left, bottom_right, center)
  --width=<w>         Window width
  --height=<h>        Window height
  --help              Show this help
--]]

-- Add project paths
package.path = package.path .. ";lua/?.lua"

local dbus_comm = require("dbus_communication")

-- Parse command line arguments
local function parse_args(args)
  if #args < 1 then
    return nil, "Usage: manual_spawn.lua <app> <tag_spec> [options]"
  end
  
  -- Check for help first
  for i = 1, #args do
    if args[i] == "--help" then
      return "help"
    end
  end
  
  if #args < 2 then
    return nil, "Usage: manual_spawn.lua <app> <tag_spec> [options]"
  end
  
  local config = {
    app = args[1],
    tag_spec = args[2],
    floating = false,
    placement = nil,
    width = nil,
    height = nil
  }
  
  -- Parse options
  for i = 3, #args do
    local arg = args[i]
    if arg == "--help" then
      return "help"
    elseif arg == "--floating" then
      config.floating = true
    elseif arg:match("^--placement=") then
      config.placement = arg:match("^--placement=(.+)$")
    elseif arg:match("^--width=") then
      config.width = tonumber(arg:match("^--width=(.+)$"))
    elseif arg:match("^--height=") then
      config.height = tonumber(arg:match("^--height=(.+)$"))
    else
      return nil, "Unknown option: " .. arg
    end
  end
  
  return config
end

-- Show help
local function show_help()
  print([[
Manual Spawn Tool for Interactive Testing

Usage:
  lua5.3 examples/spawning/manual_spawn.lua <app> <tag_spec> [options]

Arguments:
  app       Application command to spawn
  tag_spec  Tag specification:
            - 0       Current tag
            - +N      Current tag + N (e.g., +2)
            - -N      Current tag - N (e.g., -1)
            - N       Absolute tag index (e.g., 3)
            - "name"  Named tag (created if doesn't exist)

Options:
  --floating           Make the window floating
  --placement=<pos>    Window placement: top_left, top_right, bottom_left, 
                       bottom_right, center, centered, top, bottom, left, right
  --width=<w>          Window width in pixels
  --height=<h>         Window height in pixels
  --help               Show this help

Examples:
  manual_spawn.lua firefox 0                    # Current tag
  manual_spawn.lua gedit +2                     # Current tag + 2  
  manual_spawn.lua xterm "editor"               # Named tag "editor"
  manual_spawn.lua nemo 3 --floating            # Tag 3, floating
  manual_spawn.lua xcalc 0 --floating --placement=top_left --width=300 --height=200

This tool integrates with Diligent's tag mapper to test tag resolution behavior.
]])
end

-- Helper function to execute Lua code in AwesomeWM
local function exec_in_awesome(code)
  local success, result = dbus_comm.execute_in_awesome(code, 10000)
  return success, result
end

-- Convert tag spec to tag resolution logic (simplified for exploration)
local function resolve_tag_spec(tag_spec)
  local lua_code = [[
    local awful = require("awful")
    
    local screen = awful.screen.focused()
    local tags = screen.tags
    local current_tag = screen.selected_tag
    local tag_spec = "]] .. tag_spec .. [["
    
    local target_tag = nil
    local error_msg = nil
    
    -- Parse tag specification
    if tag_spec == "0" then
      -- Current tag
      target_tag = current_tag
    elseif tag_spec:match("^%+(%d+)$") then
      -- Relative positive (current + N)
      local offset = tonumber(tag_spec:match("^%+(%d+)$"))
      local target_index = current_tag.index + offset
      if target_index <= #tags then
        target_tag = tags[target_index]
      else
        error_msg = "Target index " .. target_index .. " exceeds available tags (" .. #tags .. ")"
      end
    elseif tag_spec:match("^%-(%d+)$") then
      -- Relative negative (current - N)
      local offset = tonumber(tag_spec:match("^%-(%d+)$"))
      local target_index = current_tag.index - offset
      if target_index >= 1 then
        target_tag = tags[target_index]
      else
        error_msg = "Target index " .. target_index .. " is less than 1"
      end
    elseif tag_spec:match("^(%d+)$") then
      -- Absolute index
      local target_index = tonumber(tag_spec)
      if target_index >= 1 and target_index <= #tags then
        target_tag = tags[target_index]
      else
        error_msg = "Tag index " .. target_index .. " not found (available: 1-" .. #tags .. ")"
      end
    else
      -- Named tag - search for existing or create new
      for _, tag in ipairs(tags) do
        if tag.name == tag_spec then
          target_tag = tag
          break
        end
      end
      
      if not target_tag then
        -- Create new named tag
        target_tag = awful.tag.add(tag_spec, {
          screen = screen,
          layout = awful.layout.layouts[1]  -- Use first available layout
        })
      end
    end
    
    if target_tag then
      return "SUCCESS: Resolved to tag '" .. tostring(target_tag.name or "unnamed") .. 
             "' (index: " .. target_tag.index .. ", screen: " .. screen.index .. ")"
    else
      return "ERROR: " .. (error_msg or "Unknown error")
    end
  ]]
  
  return exec_in_awesome(lua_code)
end

-- Build spawn properties
local function build_spawn_properties(config, resolved_tag)
  local properties = {}
  
  -- Add tag if resolved
  if resolved_tag then
    properties.tag = resolved_tag
  end
  
  -- Add floating
  if config.floating then
    properties.floating = true
  end
  
  -- Add placement
  if config.placement then
    properties.placement = "awful.placement." .. config.placement
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

-- Spawn the application
local function spawn_application(config)
  print("=== Manual Spawn Tool ===")
  print()
  
  -- Step 1: Show current AwesomeWM context
  print("1. Current AwesomeWM Context")
  print("----------------------------")
  local success, result = exec_in_awesome([[
    local awful = require("awful")
    local screen = awful.screen.focused()
    local tag = screen.selected_tag
    local tags = screen.tags
    
    return string.format("Screen: %d | Current tag: %s (index: %d) | Total tags: %d", 
      screen.index,
      tag.name or "unnamed",
      tag.index,
      #tags)
  ]])
  
  if success then
    print("✓", result)
  else
    print("✗ Failed to get context:", result)
    return false
  end
  print()
  
  -- Step 2: Resolve tag specification
  print("2. Tag Resolution")
  print("-----------------")
  print(string.format("Tag spec: %q", config.tag_spec))
  
  success, result = resolve_tag_spec(config.tag_spec)
  if not success then
    print("✗ Tag resolution failed:", result)
    return false
  end
  
  print("✓", result)
  
  -- Extract resolved tag for spawn
  local tag_var = "resolved_tag"
  if not result:match("SUCCESS:") then
    print("✗ Tag resolution unsuccessful")
    return false
  end
  print()
  
  -- Step 3: Build spawn command
  print("3. Spawn Configuration")
  print("----------------------")
  print(string.format("App: %s", config.app))
  print(string.format("Tag spec: %s", config.tag_spec))
  print(string.format("Floating: %s", config.floating))
  if config.placement then
    print(string.format("Placement: %s", config.placement))
  end
  if config.width or config.height then
    print(string.format("Dimensions: %sx%s", config.width or "auto", config.height or "auto"))
  end
  print()
  
  -- Step 4: Execute spawn
  print("4. Spawning Application")
  print("-----------------------")
  
  local spawn_code = [[
    local awful = require("awful")
    local screen = awful.screen.focused()
    local tags = screen.tags
    local current_tag = screen.selected_tag
    local tag_spec = "]] .. config.tag_spec .. [["
    
    -- Re-resolve tag (simplified version)
    local target_tag = nil
    local error_msg = nil
    
    if tag_spec == "0" then
      target_tag = current_tag
    elseif tag_spec:match("^%+(%d+)$") then
      local offset = tonumber(tag_spec:match("^%+(%d+)$"))
      local target_index = current_tag.index + offset
      if target_index <= #tags then
        target_tag = tags[target_index]
      else
        error_msg = "Target index " .. target_index .. " exceeds available tags (" .. #tags .. ")"
      end
    elseif tag_spec:match("^%-(%d+)$") then
      local offset = tonumber(tag_spec:match("^%-(%d+)$"))
      local target_index = current_tag.index - offset
      if target_index >= 1 then
        target_tag = tags[target_index]
      else
        error_msg = "Target index " .. target_index .. " is less than 1"
      end
    elseif tag_spec:match("^(%d+)$") then
      local target_index = tonumber(tag_spec)
      if target_index >= 1 and target_index <= #tags then
        target_tag = tags[target_index]
      else
        error_msg = "Tag index " .. target_index .. " not found (available: 1-" .. #tags .. ")"
      end
    else
      for _, tag in ipairs(tags) do
        if tag.name == tag_spec then
          target_tag = tag
          break
        end
      end
      if not target_tag then
        target_tag = awful.tag.add(tag_spec, {
          screen = screen,
          layout = awful.layout.layouts[1]
        })
      end
    end
    
    if not target_tag then
      return "ERROR: Tag resolution failed: " .. (error_msg or "Unknown error")
    end
    
    local tag = target_tag
    
    -- Build properties
    local properties = {tag = tag}]] ..
    (config.floating and "\n    properties.floating = true" or "") ..
    (config.placement and "\n    properties.placement = awful.placement." .. config.placement or "") ..
    (config.width and "\n    properties.width = " .. config.width or "") ..
    (config.height and "\n    properties.height = " .. config.height or "") .. [[
    
    -- Spawn application
    local pid, snid = awful.spawn("]] .. config.app .. [[", properties)
    
    -- Check result
    if type(pid) == "string" then
      return "SPAWN_ERROR: " .. pid
    else
      return "SPAWN_SUCCESS: PID=" .. pid .. ", SNID=" .. (snid or "nil") .. 
             ", Tag=" .. (tag.name or "unnamed") .. "(" .. tag.index .. ")"
    end
  ]]
  
  success, result = exec_in_awesome(spawn_code)
  
  if success then
    if result:match("^SPAWN_SUCCESS:") then
      print("✓", result:gsub("^SPAWN_SUCCESS: ", ""))
      print()
      print("🎉 Application spawned successfully!")
      
      -- Optional: Show updated tag info
      print()
      print("5. Updated Context")
      print("------------------")
      success, result = exec_in_awesome([[
        local awful = require("awful")
        local screen = awful.screen.focused()
        local tag = screen.selected_tag
        
        -- Count clients on current tag
        local client_count = 0
        for _, c in ipairs(tag:clients()) do
          client_count = client_count + 1
        end
        
        return string.format("Current tag now has %d clients", client_count)
      ]])
      
      if success then
        print("✓", result)
      end
      
    elseif result:match("^SPAWN_ERROR:") then
      print("✗", result:gsub("^SPAWN_ERROR: ", ""))
      return false
    elseif result:match("^ERROR:") then
      print("✗", result:gsub("^ERROR: ", ""))
      return false
    else
      print("✗ Unexpected result:", result)
      return false
    end
  else
    print("✗ Spawn execution failed:", result)
    return false
  end
  
  return true
end

-- Main execution
local function main()
  -- Check if AwesomeWM is available
  if not dbus_comm.check_awesome_available() then
    print("✗ AwesomeWM not available via D-Bus. Make sure AwesomeWM is running.")
    os.exit(1)
  end
  
  -- Parse arguments
  local config, error_msg = parse_args(arg)
  
  if config == "help" then
    show_help()
    os.exit(0)
  elseif not config then
    print("✗ " .. error_msg)
    print()
    show_help()
    os.exit(1)
  end
  
  -- Execute spawn
  local success = spawn_application(config)
  os.exit(success and 0 or 1)
end

-- Run main function
main()