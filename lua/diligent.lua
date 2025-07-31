-- Diligent AwesomeWM module
local diligent = {}

local utils = require("diligent.utils")
local ping_handler = require("diligent.handlers.ping")
local spawn_test_handler = require("diligent.handlers.spawn_test")
local kill_test_handler = require("diligent.handlers.kill_test")

-- Connect signal with automatic validation and error handling
function diligent.connect_signal(signal_name, handler)
  if not awesome or not awesome.connect_signal then
    return false
  end

  local signal_handler = function(json_payload)
    -- Parse JSON payload
    local payload, parse_err = utils.parse_payload(json_payload)
    if not payload then
      utils.send_response(utils.format_error_response(parse_err))
      return
    end

    -- Validate payload if handler has validator
    if handler.validator then
      local validated_payload, validation_errors =
        utils.validate_payload(payload, handler.validator)
      if not validated_payload then
        utils.send_response(
          utils.format_validation_error_response(validation_errors)
        )
        return
      end
      payload = validated_payload
    end

    -- Execute handler
    local response_data = handler.execute(payload)
    local response = utils.format_success_response(response_data)
    utils.send_response(response)
  end

  awesome.connect_signal(signal_name, signal_handler)
  return true
end

function diligent.setup()
  -- Register signal handlers with awesome
  if awesome and awesome.connect_signal then
    diligent.connect_signal("diligent::ping", ping_handler)
    diligent.connect_signal("diligent::spawn_test", spawn_test_handler)
    diligent.connect_signal("diligent::kill_test", kill_test_handler)
  end

  return true
end

function diligent.hello()
  return "Hello from Diligent!"
end

return diligent
