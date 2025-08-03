--[[
Spawn Environment Module Tests

Tests environment variable handling for application spawning.
--]]

local assert = require("luassert")
local awe = require("awe")

describe("awe.spawn.environment", function()
  local mock_interface
  local environment

  before_each(function()
    mock_interface = awe.interfaces.mock_interface
    local spawn = awe.create(mock_interface).spawn
    environment = spawn.environment
  end)

  describe("build_command_with_env", function()
    it("should return app unchanged when env_vars is nil", function()
      local result = environment.build_command_with_env("firefox", nil)
      assert.are.equal("firefox", result)
    end)

    it(
      "should return app unchanged when env_vars is false (JSON quirk)",
      function()
        local result = environment.build_command_with_env("firefox", false)
        assert.are.equal("firefox", result)
      end
    )

    it("should return app unchanged when env_vars is empty table", function()
      local result = environment.build_command_with_env("firefox", {})
      assert.are.equal("firefox", result)
    end)

    it("should prepend env command with single environment variable", function()
      local env_vars = { DISPLAY = ":1" }
      local result = environment.build_command_with_env("firefox", env_vars)
      assert.are.equal("env DISPLAY=:1 firefox", result)
    end)

    it(
      "should prepend env command with multiple environment variables",
      function()
        local env_vars = {
          DISPLAY = ":1",
          DILIGENT_PROJECT = "test-project",
          HOME = "/tmp/test",
        }
        local result = environment.build_command_with_env("firefox", env_vars)

        -- Order may vary, so check that all parts are present
        assert.is_truthy(result:match("^env "))
        assert.is_truthy(result:match("DISPLAY=:1"))
        assert.is_truthy(result:match("DILIGENT_PROJECT=test%-project"))
        assert.is_truthy(result:match("HOME=/tmp/test"))
        assert.is_truthy(result:match(" firefox$"))
      end
    )

    it("should handle env vars with spaces and special characters", function()
      local env_vars = {
        MESSAGE = "hello world",
        PATH = "/usr/bin:/bin",
      }
      local result = environment.build_command_with_env("myapp", env_vars)

      assert.is_truthy(result:match("^env "))
      assert.is_truthy(result:match("MESSAGE=hello world"))
      assert.is_truthy(result:match("PATH=/usr/bin:/bin"))
      assert.is_truthy(result:match(" myapp$"))
    end)

    it("should handle complex app commands with arguments", function()
      local env_vars = { DISPLAY = ":0" }
      local result =
        environment.build_command_with_env("firefox --new-window", env_vars)
      assert.are.equal("env DISPLAY=:0 firefox --new-window", result)
    end)

    it("should handle numeric values in env vars", function()
      local env_vars = {
        PORT = "8080",
        DEBUG = "1",
      }
      local result = environment.build_command_with_env("server", env_vars)

      assert.is_truthy(result:match("PORT=8080"))
      assert.is_truthy(result:match("DEBUG=1"))
    end)
  end)
end)
