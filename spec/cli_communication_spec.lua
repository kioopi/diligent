local assert = require("luassert")
local cli_comm = require("cli_communication")

describe("CLI Communication", function()
  describe("send_command", function()
    it("should create proper JSON payload", function()
      local command = "ping"
      local payload = { timestamp = "2025-07-29T10:00:00Z" }

      -- Mock awesome-client execution
      local executed_command = nil
      local mock_execute = function(cmd)
        executed_command = cmd
        return true, "success"
      end

      local result, response =
        cli_comm.send_command(command, payload, mock_execute)

      assert.is_true(result)
      assert.is_string(executed_command)
      assert.matches("awesome%-client", executed_command)
      assert.matches("diligent::ping", executed_command)
      assert.matches("2025%-07%-29T10:00:00Z", executed_command)
    end)

    it("should handle awesome-client execution failure", function()
      local mock_execute = function(cmd)
        return false, "awesome-client not found"
      end

      local result, error_msg = cli_comm.send_command("ping", {}, mock_execute)

      assert.is_false(result)
      assert.matches("awesome%-client not found", error_msg)
    end)

    it("should handle JSON encoding errors", function()
      local invalid_payload = { func = function() end } -- functions can't be JSON encoded

      local mock_execute = function(cmd)
        return true, "success"
      end

      local result, error_msg =
        cli_comm.send_command("ping", invalid_payload, mock_execute)

      assert.is_false(result)
      assert.matches("JSON", error_msg)
    end)

    it("should escape shell characters in JSON", function()
      local payload = { message = 'test "quotes" and $variables' }
      local executed_command = nil

      local mock_execute = function(cmd)
        executed_command = cmd
        return true, "success"
      end

      cli_comm.send_command("test", payload, mock_execute)

      -- Verify that shell-dangerous characters are properly handled
      assert.is_string(executed_command)
      -- Should contain properly escaped JSON within the awesome-client command
      assert.matches("diligent::test", executed_command)
      assert.matches("quotes", executed_command)
    end)
  end)

  describe("check_awesome_available", function()
    it("should return true when awesome-client works", function()
      local mock_execute = function(cmd)
        if cmd:match("awesome%-client") then
          return true, "return true"
        end
        return false, "command not found"
      end

      local available = cli_comm.check_awesome_available(mock_execute)

      assert.is_true(available)
    end)

    it("should return false when awesome-client is not available", function()
      local mock_execute = function(cmd)
        return false, "awesome-client: command not found"
      end

      local available = cli_comm.check_awesome_available(mock_execute)

      assert.is_false(available)
    end)

    it("should return false when awesome-client returns error", function()
      local mock_execute = function(cmd)
        return true, "awesome: unable to connect to display"
      end

      local available = cli_comm.check_awesome_available(mock_execute)

      assert.is_false(available)
    end)
  end)

  describe("parse_response", function()
    it("should parse valid JSON response", function()
      local json_response =
        '{"status": "success", "message": "pong", "timestamp": "2025-07-29T10:00:01Z"}'

      local success, data = cli_comm.parse_response(json_response)

      assert.is_true(success)
      assert.are.equal("success", data.status)
      assert.are.equal("pong", data.message)
      assert.are.equal("2025-07-29T10:00:01Z", data.timestamp)
    end)

    it("should handle invalid JSON", function()
      local invalid_json = '{"status": "success", "message": incomplete'

      local success, error_msg = cli_comm.parse_response(invalid_json)

      assert.is_false(success)
      assert.matches("JSON", error_msg)
    end)

    it("should handle empty response", function()
      local success, error_msg = cli_comm.parse_response("")

      assert.is_false(success)
      assert.matches("empty", error_msg)
    end)

    it("should handle non-JSON response", function()
      local plain_text = "some plain text response"

      local success, error_msg = cli_comm.parse_response(plain_text)

      assert.is_false(success)
      assert.matches("JSON", error_msg)
    end)
  end)
end)
