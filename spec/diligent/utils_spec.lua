local assert = require("luassert")
local utils = require("diligent.utils")

describe("Diligent Utils", function()
  describe("parse_payload", function()
    it("should parse valid JSON payload", function()
      local json_str =
        '{"command": "test", "timestamp": "2025-07-29T10:00:00Z"}'
      local payload, err = utils.parse_payload(json_str)

      assert.is_not_nil(payload)
      assert.is_nil(err)
      assert.are.equal("test", payload.command)
      assert.are.equal("2025-07-29T10:00:00Z", payload.timestamp)
    end)

    it("should handle empty payload", function()
      local payload, err = utils.parse_payload("")

      assert.is_nil(payload)
      assert.are.equal("Empty payload", err)
    end)

    it("should handle nil payload", function()
      local payload, err = utils.parse_payload(nil)

      assert.is_nil(payload)
      assert.are.equal("Empty payload", err)
    end)

    it("should handle invalid JSON", function()
      local payload, err = utils.parse_payload('{"invalid": json}')

      assert.is_nil(payload)
      assert.is_string(err)
    end)
  end)

  describe("validate_payload", function()
    it("should validate payload with LIVR validator", function()
      local livr = require("LIVR")
      local validator = livr.new({
        command = "required",
      })

      local valid_payload = { command = "test" }
      local validated_data, validation_errors =
        utils.validate_payload(valid_payload, validator)

      assert.is_not_nil(validated_data)
      assert.is_nil(validation_errors)
      assert.are.equal("test", validated_data.command)
    end)

    it("should return validation errors for invalid payload", function()
      local livr = require("LIVR")
      local validator = livr.new({
        command = "required",
      })

      local invalid_payload = {}
      local validated_data, validation_errors =
        utils.validate_payload(invalid_payload, validator)

      assert.is_nil(validated_data)
      assert.is_not_nil(validation_errors)
      assert.is_string(validation_errors.command)
    end)
  end)

  describe("format_error_response", function()
    it("should format error response with message", function()
      local response = utils.format_error_response("Test error message")

      assert.are.equal("error", response.status)
      assert.are.equal("Test error message", response.message)
      assert.is_string(response.timestamp)
    end)

    it("should format validation error response", function()
      local validation_errors = {
        command = "REQUIRED",
        pid = "NOT_POSITIVE_INTEGER",
      }

      local response = utils.format_validation_error_response(validation_errors)

      assert.are.equal("error", response.status)
      assert.matches("Validation failed", response.message)
      assert.is_table(response.errors)
      assert.are.equal("REQUIRED", response.errors.command)
      assert.are.equal("NOT_POSITIVE_INTEGER", response.errors.pid)
    end)
  end)

  describe("format_success_response", function()
    it("should format success response with data", function()
      local data = { message = "Operation successful", result = 42 }
      local response = utils.format_success_response(data)

      assert.are.equal("success", response.status)
      assert.are.equal("Operation successful", response.message)
      assert.are.equal(42, response.result)
      assert.is_string(response.timestamp)
    end)
  end)

  describe("send_response", function()
    it("should call awesome.emit_signal when awesome is available", function()
      local original_awesome = _G.awesome
      local signal_data = nil
      local signal_name = nil

      _G.awesome = {
        emit_signal = function(name, data)
          signal_name = name
          signal_data = data
        end,
      }

      local test_data = { status = "success", message = "test" }
      utils.send_response(test_data)

      assert.are.equal("diligent::response", signal_name)
      assert.is_string(signal_data)

      local json_utils = require("json_utils")
      local success, parsed_data = json_utils.decode(signal_data)
      assert.is_true(success)
      assert.are.equal("success", parsed_data.status)
      assert.are.equal("test", parsed_data.message)

      _G.awesome = original_awesome
    end)

    it("should handle JSON encoding failures gracefully", function()
      local original_awesome = _G.awesome
      local signal_calls = {}

      _G.awesome = {
        emit_signal = function(name, data)
          table.insert(signal_calls, { name = name, data = data })
        end,
      }

      local circular_table = {}
      circular_table.self = circular_table

      utils.send_response(circular_table)

      assert.are.equal(1, #signal_calls)
      assert.are.equal("diligent::response", signal_calls[1].name)

      local json_utils = require("json_utils")
      local success, parsed_data = json_utils.decode(signal_calls[1].data)
      assert.is_true(success)
      assert.are.equal("error", parsed_data.status)
      assert.matches("Response encoding failed", parsed_data.message)

      _G.awesome = original_awesome
    end)
  end)
end)
