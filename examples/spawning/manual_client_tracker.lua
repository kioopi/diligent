#!/usr/bin/env lua
--[[
Manual Client Tracker Tool

This tool provides comprehensive client tracking analysis using the three methods
discovered in Section 3 exploration: PID matching, environment variables, and 
client properties.

Features:
- Lookup clients by PID, environment variables, or client properties
- Validate tracking integrity across all methods
- Set/update client tracking information
- List all tracked clients with detailed analysis
- Comprehensive error handling and diagnostics

Usage examples:
  manual_client_tracker.lua --pid 12345
  manual_client_tracker.lua --env DILIGENT_PROJECT=my-project  
  manual_client_tracker.lua --property diligent_role=terminal
  manual_client_tracker.lua --list-all --verbose
  manual_client_tracker.lua --validate
--]]

-- Add project paths
package.path = package.path .. ";lua/?.lua"

local dbus_comm = require("dbus_communication")
local cliargs = require("cliargs")

-- Configure CLI arguments
cliargs:set_description("Manual client tracking analysis tool for Diligent")

-- Lookup modes
cliargs:option("-p, --pid=PID", "Find client by process ID")
cliargs:option(
  "-e, --env=KEY=VALUE",
  "Find clients by environment variable (format: KEY=VALUE)"
)
cliargs:option(
  "-r, --property=KEY=VALUE",
  "Find clients by client property (format: KEY=VALUE)"
)
cliargs:option("-c, --client=NAME", "Find client by name or class")
cliargs:flag("-l, --list-all", "List all clients with tracking information")
cliargs:flag("--validate", "Validate tracking integrity across all methods")

-- Display options
cliargs:flag("--verbose", "Show detailed diagnostic information")
cliargs:flag("--json", "Output results in JSON format")

-- Modification options
cliargs:option(
  "--set-property=KEY=VALUE",
  "Set a client property (requires --pid)"
)
cliargs:option(
  "--set-env=KEY=VALUE",
  "Set environment variable for process (requires --pid)"
)

-- Parse arguments
local args, err = cliargs:parse()

if not args then
  print("Error: " .. err)
  print()
  print(cliargs:print_help())
  os.exit(1)
end

-- Helper function to execute Lua code in AwesomeWM
local function exec_in_awesome(code)
  local success, result = dbus_comm.execute_in_awesome(code, 15000)
  return success, result
end

-- Check if AwesomeWM is available
if not dbus_comm.check_awesome_available() then
  print(
    "✗ AwesomeWM not available via D-Bus. Make sure AwesomeWM is running."
  )
  os.exit(1)
end

-- Setup client manager module in AwesomeWM
print("Loading client manager module...")
local success, result = exec_in_awesome([[
  -- Load the awesome_client_manager module
  local success, acm = pcall(require, "awesome_client_manager")
  
  if not success then
    return "ERROR: Failed to load awesome_client_manager module: " .. tostring(acm)
  end
  
  -- Store reference globally for easy access
  _G.diligent_client_manager = acm
  
  -- Check module status
  local status = acm.check_status()
  
  return "✓ Client manager module loaded (functions: " .. status.functions_count .. ")"
]])

if not success then
  print("✗ Failed to setup tracking system:", result)
  os.exit(1)
end

-- Function to format client information for display
local function format_client_display(client_data, env_data, prop_data, verbose)
  local lines = {}

  -- Basic client information
  table.insert(lines, "=== CLIENT INFORMATION ===")
  table.insert(lines, string.format("Name: %s", client_data.name))
  table.insert(lines, string.format("Class: %s", client_data.class))
  table.insert(lines, string.format("Instance: %s", client_data.instance))
  table.insert(lines, string.format("PID: %s", client_data.pid or "unknown"))
  table.insert(lines, "")

  -- AwesomeWM state
  table.insert(lines, "=== AWESOMEWM STATE ===")
  table.insert(
    lines,
    string.format("Tag: %d (%s)", client_data.tag_index, client_data.tag_name)
  )
  table.insert(lines, string.format("Screen: %d", client_data.screen_index))
  table.insert(lines, string.format("Floating: %s", client_data.floating))
  if verbose then
    table.insert(
      lines,
      string.format(
        "Geometry: %dx%d at (%d,%d)",
        client_data.geometry.width,
        client_data.geometry.height,
        client_data.geometry.x,
        client_data.geometry.y
      )
    )
    table.insert(lines, string.format("Minimized: %s", client_data.minimized))
    table.insert(lines, string.format("Maximized: %s", client_data.maximized))
  end
  table.insert(lines, "")

  -- Environment variables
  if env_data then
    if next(env_data.diligent_vars) then
      table.insert(lines, "=== ENVIRONMENT VARIABLES ===")
      for key, value in pairs(env_data.diligent_vars) do
        table.insert(lines, string.format("  %s=%s", key, value))
      end
      if verbose then
        table.insert(
          lines,
          string.format("Total env vars: %d", env_data.total_count)
        )
      end
    else
      table.insert(lines, "=== ENVIRONMENT VARIABLES ===")
      table.insert(lines, "  No DILIGENT_* environment variables found")
      if verbose then
        table.insert(
          lines,
          string.format("Total env vars: %d", env_data.total_count)
        )
      end
    end
  else
    table.insert(lines, "=== ENVIRONMENT VARIABLES ===")
    table.insert(lines, "  Cannot read environment variables")
  end
  table.insert(lines, "")

  -- Client properties
  if next(prop_data.diligent_properties) then
    table.insert(lines, "=== CLIENT PROPERTIES ===")
    for key, value in pairs(prop_data.diligent_properties) do
      table.insert(lines, string.format("  %s=%s", key, tostring(value)))
    end
  else
    table.insert(lines, "=== CLIENT PROPERTIES ===")
    table.insert(lines, "  No diligent_* client properties found")
  end
  table.insert(lines, "")

  return table.concat(lines, "\n")
end

-- Function to analyze tracking integrity
local function analyze_tracking_integrity(env_data, prop_data)
  local issues = {}
  local project_env = env_data and env_data.diligent_vars.DILIGENT_PROJECT
  local project_prop = prop_data.diligent_properties.diligent_project

  -- Check project consistency
  if project_env and project_prop and project_env ~= project_prop then
    table.insert(
      issues,
      string.format(
        "Project mismatch: env=%s, property=%s",
        project_env,
        project_prop
      )
    )
  elseif project_env and not project_prop then
    table.insert(issues, "Project in environment but not in properties")
  elseif project_prop and not project_env then
    table.insert(issues, "Project in properties but not in environment")
  end

  if #issues == 0 then
    return "✅ TRACKING INTEGRITY: Consistent across all methods"
  else
    return "⚠️ TRACKING ISSUES:\n  " .. table.concat(issues, "\n  ")
  end
end

-- Main execution logic
local function main()
  print("=== Manual Client Tracker ===")
  print()

  -- Debug: show parsed arguments
  if args.verbose then
    print("Debug - Parsed arguments:")
    for k, v in pairs(args) do
      print("  " .. k .. " = " .. tostring(v))
    end
    print()
  end

  -- Handle property setting FIRST (before any lookups)
  if args["set-property"] then
    if not args.pid then
      print("✗ --set-property requires --pid to specify target client")
      os.exit(1)
    end

    local key, value = args["set-property"]:match("^([^=]+)=(.*)$")
    if not key or not value then
      print("✗ Invalid property format. Use KEY=VALUE")
      os.exit(1)
    end

    print(
      string.format("Setting property %s=%s on PID %s...", key, value, args.pid)
    )

    local set_code = string.format(
      [[
      local acm = _G.diligent_client_manager
      local success, result = acm.set_client_property(%s, "%s", "%s")
      
      if success then
        return "SUCCESS: " .. result
      else
        return "ERROR: " .. result
      end
    ]],
      args.pid,
      key,
      value
    )

    local success, result = exec_in_awesome(set_code)

    if success then
      if result:match("^SUCCESS:") then
        print("✓", result:gsub("^SUCCESS: ", ""))
        print()
      else
        print("✗", result:gsub("^ERROR: ", ""))
        os.exit(1)
      end
    else
      print("✗ Property setting failed:", result)
      os.exit(1)
    end
  end

  -- Handle environment variable setting FIRST (if implemented)
  if args["set-env"] then
    if not args.pid then
      print("✗ --set-env requires --pid to specify target client")
      os.exit(1)
    end

    print("🚧 Environment variable setting not yet implemented")
    print()
  end

  -- Now handle lookup modes (will show updated information)
  if args.pid then
    -- Find by PID
    print("Looking up client by PID:", args.pid)
    print()

    local lookup_code = string.format(
      [[
      local acm = _G.diligent_client_manager
      local client_obj, err = acm.find_by_pid(%s)
      
      if not client_obj then
        return "ERROR: " .. err
      end
      
      local client_info = acm.get_client_info(client_obj)
      local env_data, env_err = acm.read_process_env(client_obj.pid)
      local prop_data = acm.get_client_properties(client_obj)
      
      local result = {
        status = "success",
        client = client_info,
        environment = env_data,
        env_error = env_err,
        properties = prop_data
      }
      
      return require("dkjson").encode(result)
    ]],
      args.pid
    )

    local success, result = exec_in_awesome(lookup_code)

    if not success then
      print("✗ Lookup failed:", result)
      os.exit(1)
    end

    if result:match("^ERROR:") then
      print("✗", result:gsub("^ERROR: ", ""))
      os.exit(1)
    end

    -- Parse JSON result
    local json_utils = require("json_utils")
    local parsed, data = json_utils.decode(result)

    if not parsed then
      print("✗ Failed to parse result:", data)
      os.exit(1)
    end

    -- Display formatted information
    print(
      format_client_display(
        data.client,
        data.environment,
        data.properties,
        args.verbose
      )
    )
    print(analyze_tracking_integrity(data.environment, data.properties))
  elseif args.env then
    -- Find by environment variable
    local key, value = args.env:match("^([^=]+)=(.*)$")
    if not key or not value then
      print("✗ Invalid environment variable format. Use KEY=VALUE")
      os.exit(1)
    end

    print(
      string.format(
        "Looking up clients by environment variable: %s=%s",
        key,
        value
      )
    )
    print()

    local lookup_code = string.format(
      [[
      local acm = _G.diligent_client_manager
      local clients = acm.find_by_env("%s", "%s")
      
      if #clients == 0 then
        return "ERROR: No clients found with %s=%s"
      end
      
      local results = {}
      for _, client_obj in ipairs(clients) do
        local client_info = acm.get_client_info(client_obj)
        local env_data, env_err = acm.read_process_env(client_obj.pid)
        local prop_data = acm.get_client_properties(client_obj)
        
        table.insert(results, {
          client = client_info,
          environment = env_data,
          env_error = env_err,
          properties = prop_data
        })
      end
      
      return require("dkjson").encode({status = "success", results = results})
    ]],
      key,
      value,
      key,
      value
    )

    local success, result = exec_in_awesome(lookup_code)

    if not success then
      print("✗ Lookup failed:", result)
      os.exit(1)
    end

    if result:match("^ERROR:") then
      print("✗", result:gsub("^ERROR: ", ""))
      os.exit(1)
    end

    -- Parse and display results
    local json_utils = require("json_utils")
    local parsed, data = json_utils.decode(result)

    if not parsed then
      print("✗ Failed to parse result:", data)
      os.exit(1)
    end

    print(string.format("Found %d matching client(s):", #data.results))
    print()

    for i, client_data in ipairs(data.results) do
      print(string.format("=== CLIENT %d ===", i))
      print(
        format_client_display(
          client_data.client,
          client_data.environment,
          client_data.properties,
          args.verbose
        )
      )
      print(
        analyze_tracking_integrity(
          client_data.environment,
          client_data.properties
        )
      )
      print()
    end
  elseif args.property then
    -- Find by client property
    local key, value = args.property:match("^([^=]+)=(.*)$")
    if not key or not value then
      print("✗ Invalid property format. Use KEY=VALUE")
      os.exit(1)
    end

    print(string.format("Looking up clients by property: %s=%s", key, value))
    print()

    local lookup_code = string.format(
      [[
      local acm = _G.diligent_client_manager
      local clients = acm.find_by_property("%s", "%s")
      
      if #clients == 0 then
        return "ERROR: No clients found with property %s=%s"
      end
      
      local results = {}
      for _, client_obj in ipairs(clients) do
        local client_info = acm.get_client_info(client_obj)
        local env_data, env_err = acm.read_process_env(client_obj.pid)
        local prop_data = acm.get_client_properties(client_obj)
        
        table.insert(results, {
          client = client_info,
          environment = env_data,
          env_error = env_err,
          properties = prop_data
        })
      end
      
      return require("dkjson").encode({status = "success", results = results})
    ]],
      key,
      value,
      key,
      value
    )

    local success, result = exec_in_awesome(lookup_code)

    if not success then
      print("✗ Lookup failed:", result)
      os.exit(1)
    end

    if result:match("^ERROR:") then
      print("✗", result:gsub("^ERROR: ", ""))
      os.exit(1)
    end

    -- Parse and display results
    local json_utils = require("json_utils")
    local parsed, data = json_utils.decode(result)

    if not parsed then
      print("✗ Failed to parse result:", data)
      os.exit(1)
    end

    print(string.format("Found %d matching client(s):", #data.results))
    print()

    for i, client_data in ipairs(data.results) do
      print(string.format("=== CLIENT %d ===", i))
      print(
        format_client_display(
          client_data.client,
          client_data.environment,
          client_data.properties,
          args.verbose
        )
      )
      print(
        analyze_tracking_integrity(
          client_data.environment,
          client_data.properties
        )
      )
      print()
    end
  elseif args.client then
    -- Find by client name or class
    print(string.format("Looking up clients by name/class: %s", args.client))
    print()

    local lookup_code = string.format(
      [[
      local acm = _G.diligent_client_manager
      local clients = acm.find_by_name_or_class("%s")
      
      if #clients == 0 then
        return "ERROR: No clients found matching '%s'"
      end
      
      local results = {}
      for _, client_obj in ipairs(clients) do
        local client_info = acm.get_client_info(client_obj)
        local env_data, env_err = acm.read_process_env(client_obj.pid)
        local prop_data = acm.get_client_properties(client_obj)
        
        table.insert(results, {
          client = client_info,
          environment = env_data,
          env_error = env_err,
          properties = prop_data
        })
      end
      
      return require("dkjson").encode({status = "success", results = results})
    ]],
      args.client,
      args.client
    )

    local success, result = exec_in_awesome(lookup_code)

    if not success then
      print("✗ Lookup failed:", result)
      os.exit(1)
    end

    if result:match("^ERROR:") then
      print("✗", result:gsub("^ERROR: ", ""))
      os.exit(1)
    end

    -- Parse and display results
    local json_utils = require("json_utils")
    local parsed, data = json_utils.decode(result)

    if not parsed then
      print("✗ Failed to parse result:", data)
      os.exit(1)
    end

    print(string.format("Found %d matching client(s):", #data.results))
    print()

    for i, client_data in ipairs(data.results) do
      print(string.format("=== CLIENT %d ===", i))
      print(
        format_client_display(
          client_data.client,
          client_data.environment,
          client_data.properties,
          args.verbose
        )
      )
      print(
        analyze_tracking_integrity(
          client_data.environment,
          client_data.properties
        )
      )
      print()
    end
  elseif args["list-all"] or args.l then
    -- List all tracked clients
    print("Listing all clients with tracking information...")
    print()

    local success, result = exec_in_awesome([[
      local acm = _G.diligent_client_manager
      local clients = acm.get_all_tracked_clients()
      
      if #clients == 0 then
        return "ERROR: No tracked clients found"
      end
      
      local results = {}
      for _, client_obj in ipairs(clients) do
        local client_info = acm.get_client_info(client_obj)
        local env_data, env_err = acm.read_process_env(client_obj.pid)
        local prop_data = acm.get_client_properties(client_obj)
        
        table.insert(results, {
          client = client_info,
          environment = env_data,
          env_error = env_err,
          properties = prop_data
        })
      end
      
      return require("dkjson").encode({status = "success", results = results})
    ]])

    if not success then
      print("✗ Listing failed:", result)
      os.exit(1)
    end

    if result:match("^ERROR:") then
      print("✗", result:gsub("^ERROR: ", ""))
      os.exit(1)
    end

    -- Parse and display results
    local json_utils = require("json_utils")
    local parsed, data = json_utils.decode(result)

    if not parsed then
      print("✗ Failed to parse result:", data)
      os.exit(1)
    end

    print(string.format("Found %d tracked client(s):", #data.results))
    print()

    for i, client_data in ipairs(data.results) do
      print(string.format("=== CLIENT %d ===", i))
      print(
        format_client_display(
          client_data.client,
          client_data.environment,
          client_data.properties,
          args.verbose
        )
      )
      print(
        analyze_tracking_integrity(
          client_data.environment,
          client_data.properties
        )
      )
      print()
    end
  elseif args.validate then
    -- Validate tracking integrity
    print("Validating tracking integrity across all clients...")
    print()

    -- Implementation for validation mode
    print("🚧 Validation mode coming soon!")
  else
    -- No mode specified
    print("No lookup mode specified. Use --help for usage information.")
    print()
    print(cliargs:print_help())
    os.exit(1)
  end
end

-- Run main function
main()
