require("diligent.validators")
local livr = require("LIVR")

local spawn_test_handler = {}

-- LIVR validator for spawn_test payload
spawn_test_handler.validator = livr.new({
  command = { "required", "non_empty_string" },
})

-- Execute spawn_test command
function spawn_test_handler.execute(payload)
  -- Mock PID for testing (in real implementation, this would be from awful.spawn)
  local mock_pid = math.random(1000, 9999)

  return {
    status = "success",
    command = payload.command,
    pid = mock_pid,
    message = "Process spawned (mock)",
  }
end

return spawn_test_handler
