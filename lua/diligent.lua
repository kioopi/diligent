-- Diligent AwesomeWM module
local diligent = {}

local utils = require("diligent.utils")
local ping_handler = require("diligent.handlers.ping")
local spawn_test_handler = require("diligent.handlers.spawn_test")
local kill_test_handler = require("diligent.handlers.kill_test")

diligent.handlers = {
}

function diligent.register_handler(signal_name, handler)
  diligent.handlers[signal_name] = handler
  diligent.connect_signal(signal_name, handler)

  return true
end

-- Connect signal with automatic validation and error handling
function diligent.connect_signal(signal_name, handler)
  local signal_handler = function(json_payload)
    local is_valid, payload_or_error = parse_and_validate_payload(json_payload, handler.validator)
    if not is_valid then
      utils.emit_response(payload_or_error)
      return false
    end

    -- Execute handler
    local succes, response_or_error = handler.execute(payload_or_error)
    if succes then
      utils.emit_response(utils.format_success_response(response_or_error))
    else
      utils.emit_response(utils.format_failure_response(response_or_error))
    end
  end

  -- fixme this should not fail silently
  if awesome and awesome.connect_signal then
    awesome.connect_signal(signal_name, signal_handler)
  end

  return true
end

--- Parse and validate a JSON payload
--- @param json_payload string The JSON payload to parse
--- @param validator table|nil Optional validator function or schema
--- @return boolean is_valid Whether the payload is valid
--- @return table|string payload_or_error The parsed payload on success, or error response on failure
function parse_and_validate_payload(json_payload, validator)
  -- Parse JSON payload
  local payload, parse_err = utils.parse_payload(json_payload)
  if not payload then
    return false, utils.format_error_response(parse_err)
  end

  -- Validate payload if handler has validator
  return validate_payload(payload, validator)
end

function validate_payload(payload, validator)
  if validator then
    local validated_payload, validation_errors =
    utils.validate_payload(payload, validator)
    if not validated_payload then
      return false, utils.format_validation_error_response(validation_errors)
    end
    payload = validated_payload
  end

  return true, payload
end

function parse_if_json_and_validate(payload, validator)
  if type(payload) == "string" then
    return parse_and_validate_payload(payload, validator)
  end

  return validate_payload(payload, validator)
end


function diligent.dispatch(signal_name, payload)
  local handler = diligent.handlers[signal_name]

  if not handler then
    return utils.format_error_response("No handler registered for: " .. signal_name)
  end

  local is_valid, payload_or_error = parse_if_json_and_validate(payload, handler.validator)
  if not is_valid then
    return payload_or_error
  end

  local success, response_data = handler.execute(payload_or_error)
  if not success then
    return utils.format_failure_response(response_data)
  end

  return utils.format_success_response(response_data)
end

function diligent.dispatch_json(signal_name, json_payload)
  response = diligent.dispatch(signal_name, json_payload)

  return utils.encode_response(response)
end

function diligent.setup()
  diligent.register_handler("diligent::ping", ping_handler)
  diligent.register_handler("diligent::spawn_test", spawn_test_handler)
  diligent.register_handler("diligent::kill_test", kill_test_handler)

  return true
end

function diligent.hello()
  return "Hello from Diligent!"
end

return diligent
