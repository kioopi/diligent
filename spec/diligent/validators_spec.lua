local assert = require("luassert")
local validators = require("diligent.validators")

describe("Diligent Validators", function()
  describe("custom LIVR rules", function()
    it("should validate timestamp format", function()
      local validator = validators.create_timestamp_validator()

      local valid_data, errors = validator:validate({
        timestamp = "2025-07-29T10:00:00Z",
      })
      assert.is_not_nil(valid_data)
      assert.is_nil(errors)

      local invalid_data, errors = validator:validate({
        timestamp = "invalid-timestamp",
      })
      assert.is_nil(invalid_data)
      assert.is_not_nil(errors)
      assert.is_string(errors.timestamp)
    end)

    it("should validate command strings", function()
      local validator = validators.create_command_validator()

      local valid_data, errors = validator:validate({
        command = "echo 'hello world'",
      })
      assert.is_not_nil(valid_data)
      assert.is_nil(errors)

      local invalid_data, errors = validator:validate({
        command = "",
      })
      assert.is_nil(invalid_data)
      assert.is_not_nil(errors)
      assert.is_string(errors.command)
    end)

    it("should validate positive integers", function()
      local validator = validators.create_pid_validator()

      local valid_data, errors = validator:validate({
        pid = 1234,
      })
      assert.is_not_nil(valid_data)
      assert.is_nil(errors)

      local invalid_data, errors = validator:validate({
        pid = -1,
      })
      assert.is_nil(invalid_data)
      assert.is_not_nil(errors)
      assert.is_string(errors.pid)
    end)
  end)
end)
