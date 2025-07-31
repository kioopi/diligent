local assert = require("luassert")

describe("CLI Argument Parsing", function()
  local cli_path = "cli/workon"

  describe("lua_cliargs configuration", function()
    it("should be configured with correct name and description", function()
      local handle = io.popen("lua " .. cli_path .. " --help 2>&1")
      local output = handle:read("*a")
      handle:close()

      assert.matches("workon", output, "Should show correct CLI name")
      assert.matches(
        "Usage: workon",
        output,
        "Should show correct usage format"
      )
    end)

    it("should list available commands in help", function()
      local handle = io.popen("lua " .. cli_path .. " --help 2>&1")
      local output = handle:read("*a")
      handle:close()

      assert.matches("COMMANDS:", output, "Should have COMMANDS section")
      assert.matches("ping", output, "Should list ping command")
      assert.matches(
        "Test communication with AwesomeWM",
        output,
        "Should show ping description"
      )
    end)

    it("should list available options in help", function()
      local handle = io.popen("lua " .. cli_path .. " --help 2>&1")
      local output = handle:read("*a")
      handle:close()

      assert.matches("OPTIONS:", output, "Should have OPTIONS section")
      assert.matches("%-v, %-%-verbose", output, "Should list verbose option")
      assert.matches("%-%-version", output, "Should list version option")
    end)
  end)

  describe("command routing", function()
    it("should route ping command to correct file", function()
      -- Test that ping command gets routed to the ping.lua file
      -- We can verify this by checking that we get output from ping.lua
      local handle = io.popen("lua " .. cli_path .. " ping 2>&1")
      local output = handle:read("*a")
      handle:close()

      -- Output should come from ping.lua script (success or error symbols)
      local has_success_symbol = string.match(output, "✓") ~= nil
      local has_error_symbol = string.match(output, "✗") ~= nil
      assert.is_true(
        has_success_symbol or has_error_symbol,
        "Should route to ping.lua and show its output"
      )
    end)
  end)

  describe("flag parsing", function()
    it("should parse version flag correctly", function()
      local handle = io.popen("lua " .. cli_path .. " --version 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      assert.are.equal(0, exit_code, "Version flag should exit successfully")
      assert.matches("Diligent v0.1.0", output, "Should show version number")
    end)

    it("should parse verbose flag without errors", function()
      local handle = io.popen("lua " .. cli_path .. " ping --verbose 2>&1")
      local output = handle:read("*a")
      handle:close()

      -- Should not show parsing errors for verbose flag
      assert.is_false(
        string.match(output, "unknown option") ~= nil,
        "Should parse verbose flag without errors"
      )
      assert.is_false(
        string.match(output, "invalid option") ~= nil,
        "Should parse verbose flag without errors"
      )
    end)

    it("should parse short verbose flag without errors", function()
      local handle = io.popen("lua " .. cli_path .. " ping -v 2>&1")
      local output = handle:read("*a")
      handle:close()

      -- Should not show parsing errors for short verbose flag
      assert.is_false(
        string.match(output, "unknown option") ~= nil,
        "Should parse short verbose flag without errors"
      )
    end)
  end)

  describe("error handling", function()
    it("should show proper error format for unknown commands", function()
      local handle = io.popen("lua " .. cli_path .. " nonexistent 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      assert.are.equal(
        1,
        exit_code,
        "Should exit with error code for unknown command"
      )
      assert.matches("workon:", output, "Should show CLI name in error")
    end)

    it("should show proper error format for invalid flags", function()
      local handle = io.popen("lua " .. cli_path .. " --invalid-flag 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      assert.are.equal(
        1,
        exit_code,
        "Should exit with error code for invalid flag"
      )
      assert.matches("workon:", output, "Should show CLI name in error")
    end)
  end)

  describe("tablex integration", function()
    it("should use tablex for argument size checking", function()
      -- Test that the T.size(args) == 0 logic works by testing no-command scenario
      local handle = io.popen("lua " .. cli_path .. " 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      assert.are.equal(
        0,
        exit_code,
        "Should show help when no command provided"
      )
      assert.matches("Usage:", output, "Should show help text")
    end)
  end)

  describe("argument structure", function()
    it("should handle empty argument list correctly", function()
      -- Test the T.size(args) == 0 condition
      local handle = io.popen("lua " .. cli_path .. " 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      assert.are.equal(0, exit_code, "Should exit successfully for help")
      assert.matches("Usage:", output, "Should show usage when no args")
    end)
  end)
end)
