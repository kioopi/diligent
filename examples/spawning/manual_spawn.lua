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
local cliargs = require("cliargs")

-- Configure CLI arguments
cliargs:set_description(
  "Manual spawn tool for interactive testing of client spawning with tag assignment"
)

-- Required arguments
cliargs:argument("APP", "Application command to spawn")
cliargs:argument(
  "TAG_SPEC",
  'Tag specification: 0 (current), +N/-N (relative), N (absolute), or "name" (named tag)'
)

-- Optional flags and options
cliargs:flag("--floating", "Make the window floating")
cliargs:option(
  "--placement=POS",
  "Window placement (top_left, top_right, bottom_left, bottom_right, center, etc.)"
)
cliargs:option("--width=PIXELS", "Window width in pixels")
cliargs:option("--height=PIXELS", "Window height in pixels")

-- Tracking options
cliargs:option(
  "--env=KEY=VALUE",
  "Set environment variable (can be used multiple times)"
)
cliargs:option(
  "--property=KEY=VALUE",
  "Set client property after spawn (can be used multiple times)"
)

-- Output control options
cliargs:flag("--quiet", "Minimal output for piping")
cliargs:flag("--pid-only", "Output only the PID")
cliargs:flag("--json", "JSON formatted output")
cliargs:flag(
  "--no-wait",
  "Don't wait for client to appear (faster, no property setting)"
)

-- Parse arguments
local args, err = cliargs:parse()

if not args then
  print("Error: " .. err)
  print()
  print(cliargs:print_help())
  os.exit(1)
end

-- Parse environment variables and properties (handle multiple values)
local env_vars = {}
local properties = {}

-- Handle --env options (can be multiple)
if args.env then
  if type(args.env) == "string" then
    -- Single --env option
    local key, value = args.env:match("^([^=]+)=(.*)$")
    if key and value then
      env_vars[key] = value
    else
      print(
        "✗ Invalid environment variable format: "
          .. args.env
          .. " (use KEY=VALUE)"
      )
      os.exit(1)
    end
  elseif type(args.env) == "table" then
    -- Multiple --env options
    for _, env_str in ipairs(args.env) do
      local key, value = env_str:match("^([^=]+)=(.*)$")
      if key and value then
        env_vars[key] = value
      else
        print(
          "✗ Invalid environment variable format: "
            .. env_str
            .. " (use KEY=VALUE)"
        )
        os.exit(1)
      end
    end
  end
end

-- Handle --property options (can be multiple)
if args.property then
  if type(args.property) == "string" then
    -- Single --property option
    local key, value = args.property:match("^([^=]+)=(.*)$")
    if key and value then
      properties[key] = value
    else
      print(
        "✗ Invalid property format: " .. args.property .. " (use KEY=VALUE)"
      )
      os.exit(1)
    end
  elseif type(args.property) == "table" then
    -- Multiple --property options
    for _, prop_str in ipairs(args.property) do
      local key, value = prop_str:match("^([^=]+)=(.*)$")
      if key and value then
        properties[key] = value
      else
        print("✗ Invalid property format: " .. prop_str .. " (use KEY=VALUE)")
        os.exit(1)
      end
    end
  end
end

-- Convert parsed args to config format for compatibility
local config = {
  app = args.APP,
  tag_spec = args.TAG_SPEC,
  floating = args.floating or false,
  placement = args.placement,
  width = args.width and tonumber(args.width),
  height = args.height and tonumber(args.height),

  -- New tracking features
  env_vars = env_vars,
  properties = properties,

  -- Output control
  quiet = args.quiet or false,
  pid_only = args["pid-only"] or false,
  json = args.json or false,
  no_wait = args["no-wait"] or false,
}

-- Helper function to execute Lua code in AwesomeWM
local function exec_in_awesome(code)
  local success, result = dbus_comm.execute_in_awesome(code, 10000)
  return success, result
end

-- Initialize client manager module in AwesomeWM
local function init_client_manager()
  local success, result = exec_in_awesome([[
    -- Load the awesome_client_manager module
    local success, acm = pcall(require, "awesome_client_manager")
    
    if not success then
      return "ERROR: Failed to load awesome_client_manager module: " .. tostring(acm)
    end
    
    -- Store reference globally for easy access
    _G.diligent_client_manager = acm
    
    return "SUCCESS: Client manager module loaded"
  ]])

  return success, result
end

-- Resolve tag spec using client manager module
local function resolve_tag_spec(tag_spec)
  local lua_code = string.format(
    [[
    local acm = _G.diligent_client_manager
    local tag, msg = acm.resolve_tag_spec("%s")
    
    if tag then
      return "SUCCESS: " .. msg
    else
      return "ERROR: " .. msg
    end
  ]],
    tag_spec
  )

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

-- Forward declarations
local spawn_minimal, spawn_quiet, spawn_json, spawn_verbose

-- PID-only spawn mode
spawn_minimal = function(config)
  local success, env_json = require("json_utils").encode(config.env_vars or {})
  if not success then
    print("ERROR: Failed to encode env_vars")
    return false
  end

  local spawn_code = string.format(
    [[
    local acm = _G.diligent_client_manager
    local json_utils = require("json_utils")
    local success, env_vars_data = json_utils.decode('%s')
    
    local pid, snid, msg = acm.spawn_with_properties("%s", "%s", {
      env_vars = env_vars_data or {}
    })
    
    if pid then
      return tostring(pid)
    else
      return "ERROR: " .. msg
    end
  ]],
    env_json,
    config.app,
    config.tag_spec
  )

  local success, result = exec_in_awesome(spawn_code)

  if success and not result:match("^ERROR:") then
    print(result) -- Just print the PID
    return true
  else
    return false
  end
end

-- Quiet spawn mode
spawn_quiet = function(config)
  local success, env_json = require("json_utils").encode(config.env_vars or {})
  if not success then
    print("ERROR: Failed to encode env_vars")
    return false
  end

  local spawn_code = string.format(
    [[
    local acm = _G.diligent_client_manager
    local json_utils = require("json_utils")
    local success, env_vars_data = json_utils.decode('%s')
    
    local pid, snid, msg = acm.spawn_with_properties("%s", "%s", {
      env_vars = env_vars_data or {}
    })
    
    if pid then
      return "SUCCESS: " .. pid
    else
      return "ERROR: " .. msg
    end
  ]],
    env_json,
    config.app,
    config.tag_spec
  )

  local success, result = exec_in_awesome(spawn_code)

  if success and result:match("^SUCCESS:") then
    local pid = result:match("SUCCESS: (%d+)")
    print("✓ Spawned " .. config.app .. " (PID: " .. pid .. ")")
    return true
  else
    print(
      "✗ Failed to spawn "
        .. config.app
        .. ": "
        .. (result:gsub("^ERROR: ", "") or "unknown error")
    )
    return false
  end
end

-- JSON spawn mode
spawn_json = function(config)
  local json_utils = require("json_utils")
  local spawn_config = {
    env_vars = config.env_vars or {},
    floating = config.floating,
    placement = config.placement,
    width = config.width,
    height = config.height,
  }

  local success, config_json = json_utils.encode(spawn_config)
  if not success then
    print("ERROR: Failed to encode spawn config")
    return false
  end

  local spawn_code = string.format(
    [[
    local acm = _G.diligent_client_manager
    local json_utils = require("json_utils")
    local success, spawn_config_data = json_utils.decode('%s')
    
    local pid, snid, msg = acm.spawn_with_properties("%s", "%s", spawn_config_data or {})
    
    if pid then
      return json_utils.encode({
        success = true,
        pid = pid,
        snid = snid,
        app = "%s",
        message = msg
      })
    else
      return json_utils.encode({
        success = false,
        error = msg,
        app = "%s"
      })
    end
  ]],
    config_json,
    config.app,
    config.tag_spec,
    config.app,
    config.app
  )

  local success, result = exec_in_awesome(spawn_code)

  if success then
    print(result) -- Print JSON result
    local parsed, data = json_utils.decode(result)
    return parsed and data.success
  else
    local error_json = json_utils.encode({ success = false, error = result })
    print(error_json)
    return false
  end
end

-- Verbose spawn (default mode)
spawn_verbose = function(config)
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
    print(
      string.format(
        "Dimensions: %sx%s",
        config.width or "auto",
        config.height or "auto"
      )
    )
  end

  -- Show environment variables
  if next(config.env_vars) then
    print("Environment variables:")
    for key, value in pairs(config.env_vars) do
      print(string.format("  %s=%s", key, value))
    end
  end

  -- Show properties that will be set
  if next(config.properties) then
    print("Client properties to set:")
    for key, value in pairs(config.properties) do
      print(string.format("  %s=%s", key, value))
    end
  end

  print()

  -- Step 4: Execute spawn
  print("4. Spawning Application")
  print("-----------------------")

  local json_utils = require("json_utils")
  local spawn_config = {
    env_vars = config.env_vars or {},
    floating = config.floating,
    placement = config.placement,
    width = config.width,
    height = config.height,
  }

  local success, config_json = json_utils.encode(spawn_config)
  if not success then
    print("✗ Failed to encode spawn config")
    return false
  end

  local spawn_code = string.format(
    [[
    local acm = _G.diligent_client_manager
    local json_utils = require("json_utils")
    local success, spawn_config_data = json_utils.decode('%s')
    
    local pid, snid, msg = acm.spawn_with_properties("%s", "%s", spawn_config_data or {})
    
    if pid then
      return "SPAWN_SUCCESS: " .. msg .. ", PID=" .. pid .. ", SNID=" .. (snid or "nil")
    else
      return "SPAWN_ERROR: " .. msg
    end
  ]],
    config_json,
    config.app,
    config.tag_spec
  )

  success, result = exec_in_awesome(spawn_code)

  if success then
    if result:match("^SPAWN_SUCCESS:") then
      print("✓", result:gsub("^SPAWN_SUCCESS: ", ""))

      -- Extract PID for property setting
      local spawn_pid = result:match("PID=(%d+)")

      -- Step 5: Set client properties if requested
      if next(config.properties) and spawn_pid and not config.no_wait then
        print()
        print("5. Setting Client Properties")
        print("----------------------------")

        -- Wait a moment for client to appear
        os.execute("sleep 2")

        -- Set properties on the spawned client
        for prop_key, prop_value in pairs(config.properties) do
          local prop_code = string.format(
            [[
            local acm = _G.diligent_client_manager
            local success, result = acm.set_client_property(%s, "%s", "%s")
            
            if success then
              return "SUCCESS: " .. result
            else
              return "ERROR: " .. result
            end
          ]],
            spawn_pid,
            prop_key,
            prop_value
          )

          local prop_success, prop_result = exec_in_awesome(prop_code)

          if prop_success and prop_result:match("^SUCCESS:") then
            print("✓", prop_result:gsub("^SUCCESS: ", ""))
          else
            print("✗", prop_result:gsub("^ERROR: ", ""))
          end
        end
      end

      print()
      print("🎉 Application spawned successfully!")

      -- Optional: Show updated tag info
      print()
      local step_number = next(config.properties) and not config.no_wait and "6"
        or "5"
      print(step_number .. ". Updated Context")
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

-- Spawn application dispatcher
local function spawn_application(config)
  -- Handle different output modes
  if config.pid_only then
    -- PID-only mode: minimal execution, just return the PID
    return spawn_minimal(config)
  elseif config.json then
    -- JSON mode: structured output
    return spawn_json(config)
  elseif config.quiet then
    -- Quiet mode: minimal output for piping
    return spawn_quiet(config)
  else
    -- Default verbose mode
    return spawn_verbose(config)
  end
end

-- Main execution
local function main()
  -- Check if AwesomeWM is available
  if not dbus_comm.check_awesome_available() then
    print(
      "✗ AwesomeWM not available via D-Bus. Make sure AwesomeWM is running."
    )
    os.exit(1)
  end

  -- Initialize client manager module
  local success, result = init_client_manager()
  if not success or result:match("^ERROR:") then
    print("✗ Failed to load client manager module:", result)
    os.exit(1)
  end

  -- Execute spawn (config is already set up from cliargs parsing)
  local success = spawn_application(config)
  os.exit(success and 0 or 1)
end

-- Run main function
main()
