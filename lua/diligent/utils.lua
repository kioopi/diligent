local utils = {}

local json_utils = require("json_utils")

-- Parse JSON payload
function utils.parse_payload(json_str)
  if not json_str or json_str == "" then
    return nil, "Empty payload"
  end

  local success, data = json_utils.decode(json_str)
  if not success then
    return nil, data -- data contains error message
  end

  return data, nil
end

-- Validate payload using LIVR validator
function utils.validate_payload(payload, validator)
  if not validator then
    return payload, nil
  end

  local validated_data, errors = validator:validate(payload)
  return validated_data, errors
end

-- Format error response
function utils.format_error_response(message)
  return {
    status = "error",
    message = message,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }
end

-- Format validation error response
function utils.format_validation_error_response(validation_errors)
  return {
    status = "error",
    message = "Validation failed",
    errors = validation_errors,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }
end

-- Format success response
function utils.format_success_response(data)
  local response = {
    status = "success",
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }

  -- Merge data into response
  for key, value in pairs(data) do
    response[key] = value
  end

  return response
end

-- Send response back to CLI via signal
function utils.send_response(data)
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

return utils
