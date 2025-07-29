local assert = require("luassert")

describe("Diligent AwesomeWM Module", function()
  local diligent
  local mock_awesome
  local captured_signals

  before_each(function()
    -- Reset captured signals
    captured_signals = {}

    -- Mock awesome global
    mock_awesome = {
      connect_signal = function(signal, handler)
        captured_signals[signal] = handler
      end,
      emit_signal = function(signal, ...)
        -- Mock signal emission for testing responses
        if captured_signals[signal] then
          captured_signals[signal](...)
        end
      end,
    }

    -- Inject mock into global scope
    _G.awesome = mock_awesome

    -- Require diligent module fresh each time
    package.loaded.diligent = nil
    diligent = require("diligent")
  end)

  after_each(function()
    -- Clean up global mock
    _G.awesome = nil
  end)

  describe("setup", function()
    it("should register signal handlers for basic commands", function()
      diligent.setup()

      -- Verify that signal handlers were registered
      assert.is_function(captured_signals["diligent::ping"])
      assert.is_function(captured_signals["diligent::spawn_test"])
      assert.is_function(captured_signals["diligent::kill_test"])
    end)

    it("should handle multiple setup calls gracefully", function()
      diligent.setup()
      local first_ping_handler = captured_signals["diligent::ping"]

      -- Setup again
      diligent.setup()
      local second_ping_handler = captured_signals["diligent::ping"]

      -- Should not cause errors and handlers should be functions
      assert.is_function(first_ping_handler)
      assert.is_function(second_ping_handler)
    end)
  end)

  describe("ping handler", function()
    before_each(function()
      diligent.setup()
    end)

    it("should respond to ping with pong and timestamp", function()
      local response_signal = nil
      local response_data = nil

      -- Mock the response emission
      mock_awesome.emit_signal = function(signal, data)
        response_signal = signal
        response_data = data
      end

      -- Trigger ping
      local json_payload = '{"timestamp": "2025-07-29T10:00:00Z"}'
      captured_signals["diligent::ping"](json_payload)

      -- Verify response
      assert.are.equal("diligent::response", response_signal)
      assert.is_string(response_data)

      -- Parse response JSON
      local dkjson = require("dkjson")
      local data = dkjson.decode(response_data)
      assert.are.equal("success", data.status)
      assert.are.equal("pong", data.message)
      assert.is_string(data.timestamp)
    end)

    it("should handle malformed JSON in ping", function()
      local response_signal = nil
      local response_data = nil

      mock_awesome.emit_signal = function(signal, data)
        response_signal = signal
        response_data = data
      end

      -- Trigger ping with invalid JSON
      captured_signals["diligent::ping"]("invalid json")

      -- Verify error response
      assert.are.equal("diligent::response", response_signal)
      local dkjson = require("dkjson")
      local data = dkjson.decode(response_data)
      assert.are.equal("error", data.status)
      assert.matches("JSON", data.message)
    end)
  end)

  describe("spawn_test handler", function()
    before_each(function()
      diligent.setup()
    end)

    it("should parse spawn command and mock spawn response", function()
      local response_signal = nil
      local response_data = nil

      mock_awesome.emit_signal = function(signal, data)
        response_signal = signal
        response_data = data
      end

      -- Trigger spawn test
      local json_payload = '{"command": "xterm", "args": []}'
      captured_signals["diligent::spawn_test"](json_payload)

      -- Verify response contains mock PID
      assert.are.equal("diligent::response", response_signal)
      local dkjson = require("dkjson")
      local data = dkjson.decode(response_data)
      assert.are.equal("success", data.status)
      assert.is_number(data.pid)
      assert.are.equal("xterm", data.command)
    end)

    it("should handle empty command", function()
      local response_data = nil

      mock_awesome.emit_signal = function(signal, data)
        response_data = data
      end

      -- Trigger spawn with empty command
      local json_payload = '{"command": "", "args": []}'
      captured_signals["diligent::spawn_test"](json_payload)

      -- Verify error response
      local dkjson = require("dkjson")
      local data = dkjson.decode(response_data)
      assert.are.equal("error", data.status)
      assert.matches("command", data.message)
    end)
  end)

  describe("kill_test handler", function()
    before_each(function()
      diligent.setup()
    end)

    it("should handle kill request with PID", function()
      local response_data = nil

      mock_awesome.emit_signal = function(signal, data)
        response_data = data
      end

      -- Trigger kill test
      local json_payload = '{"pid": 1234}'
      captured_signals["diligent::kill_test"](json_payload)

      -- Verify response
      local dkjson = require("dkjson")
      local data = dkjson.decode(response_data)
      assert.are.equal("success", data.status)
      assert.are.equal(1234, data.pid)
      assert.is_boolean(data.killed)
    end)

    it("should handle invalid PID", function()
      local response_data = nil

      mock_awesome.emit_signal = function(signal, data)
        response_data = data
      end

      -- Trigger kill with invalid PID
      local json_payload = '{"pid": "not_a_number"}'
      captured_signals["diligent::kill_test"](json_payload)

      -- Verify error response
      local dkjson = require("dkjson")
      local data = dkjson.decode(response_data)
      assert.are.equal("error", data.status)
      assert.matches("PID", data.message)
    end)

    it("should handle missing PID", function()
      local response_data = nil

      mock_awesome.emit_signal = function(signal, data)
        response_data = data
      end

      -- Trigger kill without PID
      local json_payload = "{}"
      captured_signals["diligent::kill_test"](json_payload)

      -- Verify error response
      local dkjson = require("dkjson")
      local data = dkjson.decode(response_data)
      assert.are.equal("error", data.status)
      assert.matches("PID", data.message)
    end)
  end)
end)
