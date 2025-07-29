--[[
CLI Communication Layer for Diligent

This module handles bidirectional communication between the Diligent CLI
and the AwesomeWM window manager via the awesome-client command.

Responsibilities:
- Encode command payloads as JSON for transmission to AwesomeWM
- Execute awesome-client commands with proper shell escaping
- Parse JSON responses from AwesomeWM signal handlers
- Check if AwesomeWM is available and responsive
- Handle communication errors gracefully

The communication protocol uses AwesomeWM signals:
- CLI sends: awesome.emit_signal("diligent::<command>", "<json_payload>")
- AwesomeWM responds: awesome.emit_signal("diligent::response", "<json_response>")

All functions accept an optional execute_fn parameter for dependency injection
during testing, allowing the communication logic to be tested without requiring
an actual AwesomeWM instance.
--]]

local cli_comm = {}

local dkjson = require("dkjson")

-- Default command executor (can be overridden for testing)
local function default_execute(command)
  local handle = io.popen(command .. " 2>&1")
  if not handle then
    return false, "Failed to execute command"
  end

  local output = handle:read("*a")
  local success, exit_type, exit_code = handle:close()

  if success and exit_type == "exit" and exit_code == 0 then
    return true, output
  else
    return false, output
  end
end

-- Send a command to AwesomeWM via awesome-client
function cli_comm.send_command(command, payload, execute_fn)
  execute_fn = execute_fn or default_execute

  -- Encode payload as JSON (with error handling)
  local status, json_payload = pcall(dkjson.encode, payload)
  if not status then
    return false, "JSON encoding error: " .. (json_payload or "unknown error")
  end

  -- Escape JSON for shell - use single quotes to wrap the entire JSON
  -- and escape any single quotes within
  local escaped_json = json_payload:gsub("'", "'\"'\"'")

  -- Build awesome-client command using proper shell escaping
  -- Use double quotes for the outer shell command and escape inner quotes
  local awesome_cmd = string.format(
    'awesome-client "awesome.emit_signal(\\"diligent::%s\\", \'%s\')"',
    command,
    escaped_json
  )

  -- Execute command
  local success, output = execute_fn(awesome_cmd)

  if not success then
    return false, output
  end

  return true, output
end

-- Check if awesome-client is available and AwesomeWM is running
function cli_comm.check_awesome_available(execute_fn)
  execute_fn = execute_fn or default_execute

  -- Try to execute a simple awesome-client command
  local test_cmd = "awesome-client 'return true'"
  local success, output = execute_fn(test_cmd)

  if not success then
    return false
  end

  -- Check if output indicates success (awesome-client returns "true")
  if output and output:match("true") then
    return true
  end

  return false
end

-- Parse JSON response from AwesomeWM
function cli_comm.parse_response(response)
  if not response or response == "" then
    return false, "empty response"
  end

  -- Try to decode JSON
  local data, err = dkjson.decode(response)
  if not data then
    return false, "JSON parsing error: " .. (err or "invalid JSON")
  end

  return true, data
end

return cli_comm
