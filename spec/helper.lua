local assert = require("luassert")

local say = require("say")
say:set(
  "assertion.success.positive",
  "Expected success (got failure: %s). Error: %s"
)
say:set("assertion.success.negative", "Expected failure (got success: %s).")
local assert_success = function(state, arguments)
  local success, result = table.unpack(arguments)
  return success == true, { result }
end

assert:register(
  "assertion",
  "success",
  assert_success,
  "assertion.success.positive",
  "assertion.success.negative"
)
