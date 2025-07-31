local assert = require("luassert")
local kill_test_handler = require("diligent.handlers.kill_test")

describe("Kill Test Handler", function()
  describe("validator", function()
    it("should have LIVR validator for kill_test payload", function()
      assert.is_table(kill_test_handler.validator)
      assert.is_function(kill_test_handler.validator.validate)
    end)

    it("should validate valid kill_test payload", function()
      local payload = {
        pid = 1234,
      }

      local valid_data, errors = kill_test_handler.validator:validate(payload)
      assert.is_not_nil(valid_data)
      assert.is_nil(errors)
      assert.are.equal(1234, valid_data.pid)
    end)

    it("should reject payload without pid", function()
      local payload = {}

      local valid_data, errors = kill_test_handler.validator:validate(payload)
      assert.is_nil(valid_data)
      assert.is_not_nil(errors)
      assert.is_string(errors.pid)
    end)

    it("should reject payload with negative pid", function()
      local payload = {
        pid = -1,
      }

      local valid_data, errors = kill_test_handler.validator:validate(payload)
      assert.is_nil(valid_data)
      assert.is_not_nil(errors)
      assert.is_string(errors.pid)
    end)

    it("should reject payload with zero pid", function()
      local payload = {
        pid = 0,
      }

      local valid_data, errors = kill_test_handler.validator:validate(payload)
      assert.is_nil(valid_data)
      assert.is_not_nil(errors)
      assert.is_string(errors.pid)
    end)

    it("should reject payload with non-number pid", function()
      local payload = {
        pid = "1234",
      }

      local valid_data, errors = kill_test_handler.validator:validate(payload)
      assert.is_nil(valid_data)
      assert.is_not_nil(errors)
      assert.is_string(errors.pid)
    end)
  end)

  describe("execute", function()
    it("should return success response for positive PID", function()
      local payload = {
        pid = 1234,
      }

      local response = kill_test_handler.execute(payload)

      assert.are.equal("success", response.status)
      assert.are.equal(1234, response.pid)
      assert.is_true(response.killed)
      assert.are.equal("Kill signal sent (mock)", response.message)
    end)

    it("should handle different PID values", function()
      local test_pids = { 1, 999, 1234, 9999 }

      for _, pid in ipairs(test_pids) do
        local payload = { pid = pid }
        local response = kill_test_handler.execute(payload)

        assert.are.equal("success", response.status)
        assert.are.equal(pid, response.pid)
        assert.is_boolean(response.killed)
        assert.are.equal("Kill signal sent (mock)", response.message)
      end
    end)
  end)
end)
