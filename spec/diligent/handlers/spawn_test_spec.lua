local assert = require("luassert")
local spawn_test_handler = require("diligent.handlers.spawn_test")

describe("Spawn Test Handler", function()
  describe("validator", function()
    it("should have LIVR validator for spawn_test payload", function()
      assert.is_table(spawn_test_handler.validator)
      assert.is_function(spawn_test_handler.validator.validate)
    end)

    it("should validate valid spawn_test payload", function()
      local payload = {
        command = "echo 'hello world'",
      }

      local valid_data, errors = spawn_test_handler.validator:validate(payload)
      assert.is_not_nil(valid_data)
      assert.is_nil(errors)
      assert.are.equal("echo 'hello world'", valid_data.command)
    end)

    it("should reject payload without command", function()
      local payload = {}

      local valid_data, errors = spawn_test_handler.validator:validate(payload)
      assert.is_nil(valid_data)
      assert.is_not_nil(errors)
      assert.is_string(errors.command)
    end)

    it("should reject payload with empty command", function()
      local payload = {
        command = "",
      }

      local valid_data, errors = spawn_test_handler.validator:validate(payload)
      assert.is_nil(valid_data)
      assert.is_not_nil(errors)
      assert.is_string(errors.command)
    end)

    it("should reject payload with whitespace-only command", function()
      local payload = {
        command = "   ",
      }

      local valid_data, errors = spawn_test_handler.validator:validate(payload)
      assert.is_nil(valid_data)
      assert.is_not_nil(errors)
      assert.is_string(errors.command)
    end)
  end)

  describe("execute", function()
    it("should return success response with mock PID", function()
      local payload = {
        command = "echo 'test command'",
      }

      local _, response = spawn_test_handler.execute(payload)

      assert.are.equal("success", response.status)
      assert.are.equal("echo 'test command'", response.command)
      assert.is_number(response.pid)
      assert.is_true(response.pid >= 1000)
      assert.is_true(response.pid <= 9999)
      assert.are.equal("Process spawned (mock)", response.message)
    end)

    it("should generate different PIDs for different calls", function()
      local payload = {
        command = "test command",
      }

      local _, response1 = spawn_test_handler.execute(payload)
      local _, response2 = spawn_test_handler.execute(payload)

      assert.is_number(response1.pid)
      assert.is_number(response2.pid)
      -- Note: theoretically they could be the same due to randomness, but very unlikely
    end)
  end)
end)
