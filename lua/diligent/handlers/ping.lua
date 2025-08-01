require("diligent.validators")
local livr = require("LIVR")

local ping_handler = {}

-- LIVR validator for ping payload
ping_handler.validator = livr.new({
  timestamp = { "required", "iso_date" },
})

-- Execute ping command
function ping_handler.execute(payload)
  return true, {
    status = "success",
    message = "pong",
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    received_timestamp = payload.timestamp,
  }
end

return ping_handler
