-- Diligent AwesomeWM module
local diligent = {}

local json_utils = require("json_utils")

-- Helper function to send response back to CLI via signal
local function send_response(data)
  local success, json_response = json_utils.encode(data)
  if not success then
    -- If encoding fails, send error response
    success, json_response = json_utils.encode({
      status = "error",
      message = "Response encoding failed: " .. json_response,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    })
    if not success then
      return -- Cannot even encode error response
    end
  end

  -- Emit signal for signal-based communication
  if awesome and awesome.emit_signal then
    awesome.emit_signal("diligent::response", json_response)
  end
end

-- Helper function to parse JSON payload
local function parse_payload(json_str)
  if not json_str or json_str == "" then
    return nil, "Empty payload"
  end

  local success, data = json_utils.decode(json_str)
  if not success then
    return nil, data -- data contains error message
  end

  return data, nil
end

-- Handler for ping command
local function handle_ping(json_payload)
  local payload, err = parse_payload(json_payload)
  if not payload then
    send_response({
      status = "error",
      message = err,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    })
    return
  end

  send_response({
    status = "success",
    message = "pong",
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    received_timestamp = payload.timestamp,
  })
end

-- Handler for spawn test command
local function handle_spawn_test(json_payload)
  local payload, err = parse_payload(json_payload)
  if not payload then
    send_response({
      status = "error",
      message = err,
    })
    return
  end

  if not payload.command or payload.command == "" then
    send_response({
      status = "error",
      message = "Invalid or empty command",
    })
    return
  end

  -- Mock PID for testing (in real implementation, this would be from awful.spawn)
  local mock_pid = math.random(1000, 9999)

  send_response({
    status = "success",
    command = payload.command,
    pid = mock_pid,
    message = "Process spawned (mock)",
  })
end

-- Handler for kill test command
local function handle_kill_test(json_payload)
  local payload, err = parse_payload(json_payload)
  if not payload then
    send_response({
      status = "error",
      message = err,
    })
    return
  end

  if not payload.pid then
    send_response({
      status = "error",
      message = "Missing PID",
    })
    return
  end

  if type(payload.pid) ~= "number" then
    send_response({
      status = "error",
      message = "Invalid PID format",
    })
    return
  end

  -- Mock kill operation (in real implementation, this would use posix.kill)
  local mock_killed = payload.pid > 0 -- Simple mock logic

  send_response({
    status = "success",
    pid = payload.pid,
    killed = mock_killed,
    message = "Kill signal sent (mock)",
  })
end

function diligent.setup()
  -- Register signal handlers with awesome
  if awesome and awesome.connect_signal then
    awesome.connect_signal("diligent::ping", handle_ping)
    awesome.connect_signal("diligent::spawn_test", handle_spawn_test)
    awesome.connect_signal("diligent::kill_test", handle_kill_test)
  end

  return true
end

function diligent.hello()
  return "Hello from Diligent!"
end

return diligent
