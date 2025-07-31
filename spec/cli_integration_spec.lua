local assert = require("luassert")

describe("CLI Integration Tests", function()
  local cli_path = "cli/workon"

  describe("workon command execution", function()
    it("should show help when no command is provided", function()
      local handle = io.popen("lua " .. cli_path .. " 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      assert.are.equal(0, exit_code, "Should exit with code 0 for help")
      assert.matches("Usage:", output, "Should show usage information")
      assert.matches("workon", output, "Should mention workon command")
      assert.matches("ping", output, "Should list ping command")
    end)

    it("should show version with --version flag", function()
      local handle = io.popen("lua " .. cli_path .. " --version 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      assert.are.equal(0, exit_code, "Should exit with code 0 for version")
      assert.matches("Diligent v0.1.0", output, "Should show version number")
    end)

    it("should show help with --help flag", function()
      local handle = io.popen("lua " .. cli_path .. " --help 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      -- lua_cliargs treats --help as an error condition but shows help
      assert.matches("Usage:", output, "Should show usage information")
      assert.matches("ping", output, "Should list ping command")
    end)

    it("should execute ping command via file", function()
      local handle = io.popen("lua " .. cli_path .. " ping 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      -- Should either succeed (if AwesomeWM available) or show error message
      assert.is_true(
        exit_code == 0 or exit_code == 1,
        "Should exit with 0 or 1"
      )

      if exit_code == 0 then
        assert.matches("✓", output, "Should show success symbol")
        assert.matches(
          "Ping successful!",
          output,
          "Should show success message"
        )
      else
        assert.matches("✗", output, "Should show error symbol")
        assert.matches("AwesomeWM", output, "Should mention AwesomeWM in error")
      end
    end)

    it("should handle unknown commands gracefully", function()
      local handle = io.popen("lua " .. cli_path .. " unknown_command 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      assert.are.equal(
        1,
        exit_code,
        "Should exit with code 1 for unknown command"
      )
      assert.matches("workon:", output, "Should show CLI name in error")
    end)

    it("should handle invalid flags gracefully", function()
      local handle = io.popen("lua " .. cli_path .. " --invalid-flag 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      assert.are.equal(1, exit_code, "Should exit with code 1 for invalid flag")
      assert.matches("workon:", output, "Should show CLI name in error")
    end)
  end)

  describe("command file execution", function()
    it("should properly route ping command to ping.lua file", function()
      -- Test that the :file() mechanism works by checking ping command execution
      local handle = io.popen("lua " .. cli_path .. " ping 2>&1")
      local output = handle:read("*a")
      handle:close()

      -- The output should come from the ping.lua file, not from CLI script itself
      local has_success_symbol = string.match(output, "✓") ~= nil
      local has_error_symbol = string.match(output, "✗") ~= nil
      assert.is_true(
        has_success_symbol or has_error_symbol,
        "Should show output from ping.lua script execution: " .. output
      )
    end)
  end)

  describe("path and dependency resolution", function()
    it("should correctly resolve lua module paths", function()
      -- Test that the package.path setup works correctly
      local handle = io.popen("lua " .. cli_path .. " ping 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      -- Should not show "module not found" errors
      assert.is_false(
        string.match(output, "module .* not found") ~= nil,
        "Should not have module resolution errors: " .. output
      )
    end)

    it("should handle tablex dependency correctly", function()
      -- Test that pl.tablex is available and works
      local handle = io.popen(
        "lua -e \"local T = require('pl.tablex'); print('tablex_available')\" 2>&1"
      )
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      assert.are.equal(
        0,
        exit_code,
        "Should successfully load tablex: " .. output
      )
      assert.matches(
        "tablex_available",
        output,
        "Should load tablex without errors"
      )
    end)
  end)

  describe("verbose flag handling", function()
    it("should accept verbose flag with ping command", function()
      local handle = io.popen("lua " .. cli_path .. " ping --verbose 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      -- Should execute without parse errors (verbose flag should be recognized)
      assert.is_false(
        string.match(output, "unknown option") ~= nil,
        "Should recognize --verbose flag"
      )
    end)

    it("should accept short verbose flag with ping command", function()
      local handle = io.popen("lua " .. cli_path .. " ping -v 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      -- Should execute without parse errors (verbose flag should be recognized)
      assert.is_false(
        string.match(output, "unknown option") ~= nil,
        "Should recognize -v flag"
      )
    end)
  end)
end)
