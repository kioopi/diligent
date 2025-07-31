local assert = require("luassert")
local ping_handler = require("diligent.handlers.ping")

describe("Ping Handler", function()
  describe("validator", function()
    it("should have LIVR validator for ping payload", function()
      assert.is_table(ping_handler.validator)
      assert.is_function(ping_handler.validator.validate)
    end)

    it("should validate valid ping payload", function()
      local payload = {
        timestamp = "2025-07-29T10:00:00Z",
      }

      local valid_data, errors = ping_handler.validator:validate(payload)
      assert.is_not_nil(valid_data)
      assert.is_nil(errors)
      assert.are.equal("2025-07-29T10:00:00Z", valid_data.timestamp)
    end)

    it("should reject payload without timestamp", function()
      local payload = {}

      local valid_data, errors = ping_handler.validator:validate(payload)
      assert.is_nil(valid_data)
      assert.is_not_nil(errors)
      assert.is_string(errors.timestamp)
    end)
  end)

  describe("execute", function()
    it("should return pong response for valid payload", function()
      local payload = {
        timestamp = "2025-07-29T10:00:00Z",
      }

      local response = ping_handler.execute(payload)

      assert.are.equal("success", response.status)
      assert.are.equal("pong", response.message)
      assert.is_string(response.timestamp)
      assert.are.equal("2025-07-29T10:00:00Z", response.received_timestamp)
    end)

    it("should include current timestamp in response", function()
      local payload = {
        timestamp = "2025-07-29T10:00:00Z",
      }

      local response = ping_handler.execute(payload)

      assert.matches("%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ", response.timestamp)
    end)
  end)
end)
