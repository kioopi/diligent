local assert = require("luassert")
local diligent = require("diligent")

describe("Diligent Refactored Module", function()
  describe("module structure", function()
    it("should load the main module", function()
      assert.is_table(diligent)
    end)

    it("should have required functions", function()
      assert.is_function(diligent.setup)
      assert.is_function(diligent.hello)
      assert.is_function(diligent.connect_signal)
      assert.are.equal("Hello from Diligent!", diligent.hello())
    end)
  end)

  describe("connect_signal", function()
    it("should register signal handler with validation", function()
      local original_awesome = _G.awesome
      local connected_signals = {}

      _G.awesome = {
        connect_signal = function(signal_name, handler_func)
          connected_signals[signal_name] = handler_func
        end,
      }

      -- Mock handler with validator
      local mock_handler = {
        validator = {
          validate = function(self, payload)
            if payload.command then
              return payload, nil
            else
              return nil, { command = "REQUIRED" }
            end
          end,
        },
        execute = function(payload)
          return {
            status = "success",
            message = "mock response",
            command = payload.command,
          }
        end,
      }

      diligent.connect_signal("test::command", mock_handler)

      assert.is_function(connected_signals["test::command"])

      _G.awesome = original_awesome
    end)

    it("should handle validation errors in signal handler", function()
      local original_awesome = _G.awesome
      local emitted_responses = {}

      _G.awesome = {
        connect_signal = function(signal_name, handler_func)
          -- Store the handler for testing
          _G.test_handler = handler_func
        end,
        emit_signal = function(signal_name, data)
          emitted_responses[signal_name] = data
        end,
      }

      -- Mock handler with validator that requires 'command'
      local mock_handler = {
        validator = {
          validate = function(self, payload)
            if payload.command then
              return payload, nil
            else
              return nil, { command = "REQUIRED" }
            end
          end,
        },
        execute = function(payload)
          return { status = "success", command = payload.command }
        end,
      }

      diligent.connect_signal("test::command", mock_handler)

      -- Test with invalid payload (missing command)
      local json_utils = require("json_utils")
      local success, invalid_json = json_utils.encode({})
      assert.is_true(success)
      _G.test_handler(invalid_json)

      assert.is_string(emitted_responses["diligent::response"])

      local success, response_data =
        json_utils.decode(emitted_responses["diligent::response"])
      assert.is_true(success)
      assert.are.equal("error", response_data.status)
      assert.matches("Validation failed", response_data.message)
      assert.is_table(response_data.errors)
      assert.are.equal("REQUIRED", response_data.errors.command)

      _G.test_handler = nil
      _G.awesome = original_awesome
    end)

    it("should handle successful validation and execution", function()
      local original_awesome = _G.awesome
      local emitted_responses = {}

      _G.awesome = {
        connect_signal = function(signal_name, handler_func)
          _G.test_handler = handler_func
        end,
        emit_signal = function(signal_name, data)
          emitted_responses[signal_name] = data
        end,
      }

      local mock_handler = {
        validator = {
          validate = function(self, payload)
            if payload.command then
              return payload, nil
            else
              return nil, { command = "REQUIRED" }
            end
          end,
        },
        execute = function(payload)
          return {
            status = "success",
            message = "Command executed",
            command = payload.command,
          }
        end,
      }

      diligent.connect_signal("test::command", mock_handler)

      -- Test with valid payload
      local json_utils = require("json_utils")
      local success, valid_json = json_utils.encode({ command = "echo test" })
      assert.is_true(success)
      _G.test_handler(valid_json)

      assert.is_string(emitted_responses["diligent::response"])

      local success, response_data =
        json_utils.decode(emitted_responses["diligent::response"])
      assert.is_true(success)
      assert.are.equal("success", response_data.status)
      assert.are.equal("Command executed", response_data.message)
      assert.are.equal("echo test", response_data.command)

      _G.test_handler = nil
      _G.awesome = original_awesome
    end)
  end)

  describe("setup", function()
    it("should register all default handlers", function()
      local original_awesome = _G.awesome
      local connected_signals = {}

      _G.awesome = {
        connect_signal = function(signal_name, handler_func)
          connected_signals[signal_name] = handler_func
        end,
      }

      local result = diligent.setup()

      assert.is_true(result)
      assert.is_function(connected_signals["diligent::ping"])
      assert.is_function(connected_signals["diligent::spawn_test"])
      assert.is_function(connected_signals["diligent::kill_test"])

      _G.awesome = original_awesome
    end)

    it("should return true when awesome is not available", function()
      local original_awesome = _G.awesome
      _G.awesome = nil

      local result = diligent.setup()

      assert.is_true(result)

      _G.awesome = original_awesome
    end)
  end)
end)
