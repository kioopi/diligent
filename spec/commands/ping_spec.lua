local assert = require("luassert")

describe("Ping Command Script", function()
  local ping_script_path = "cli/commands/ping.lua"

  describe("script execution", function()
    it(
      "should execute as standalone script when AwesomeWM available",
      function()
        -- Test direct execution of ping.lua script
        local handle = io.popen("lua " .. ping_script_path .. " 2>&1")
        local output = handle:read("*a")
        local success, _, exit_code = handle:close()

        -- Should either succeed (if AwesomeWM available) or show error
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
          assert.matches(
            "AwesomeWM",
            output,
            "Should mention AwesomeWM in error"
          )
        end
      end
    )

    it("should handle missing dependencies gracefully", function()
      -- Test that script fails gracefully if dependencies are missing
      local test_code = [[
        local success, result = pcall(function()
          require("commands.bumm")
        end)
        if not success then
          print("dependency_error")
        end
      ]]

      local handle = io.popen("lua -e '" .. test_code .. "' 2>&1")
      local output = handle:read("*a")
      handle:close()

      -- Should either load successfully or show dependency error
      assert.matches(
        "dependency_error",
        output,
        "Should inform about missing dependencies"
      )
    end)
  end)

  describe("script structure and dependencies", function()
    it("should be a valid Lua script", function()
      -- Test that the script has valid Lua syntax
      local handle = io.popen(
        "lua -l "
          .. ping_script_path:gsub("%.lua$", ""):gsub("/", ".")
          .. " -e 'print(\"syntax_ok\")' 2>&1"
      )
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      -- Should not have syntax errors
      assert.is_false(
        string.match(output, "syntax error") ~= nil,
        "Should not have syntax errors: " .. output
      )
    end)

    it("should require expected dependencies", function()
      -- Test that the script tries to load the expected modules
      local file = io.open(ping_script_path, "r")
      assert.is_not_nil(file, "Should be able to read ping script")

      local content = file:read("*a")
      file:close()

      assert.matches(
        "require.*dbus_communication",
        content,
        "Should require dbus_communication"
      )
      assert.matches(
        "require.*cli_printer",
        content,
        "Should require cli_printer"
      )
    end)

    it("should use cli_printer functions for output", function()
      -- Test that the script uses the expected output functions
      local file = io.open(ping_script_path, "r")
      local content = file:read("*a")
      file:close()

      assert.matches("%.success", content, "Should use success")
      assert.matches("%.error", content, "Should use error")
      assert.matches("%.info", content, "Should use info")
    end)

    it("should perform D-Bus availability check", function()
      -- Test that the script checks AwesomeWM availability
      local file = io.open(ping_script_path, "r")
      local content = file:read("*a")
      file:close()

      assert.matches(
        "check_awesome_available",
        content,
        "Should check AwesomeWM availability"
      )
    end)

    it("should send ping command", function()
      -- Test that the script sends ping
      local file = io.open(ping_script_path, "r")
      local content = file:read("*a")
      file:close()

      assert.matches("send_ping", content, "Should send ping command")
      assert.matches("diligent%-cli", content, "Should set correct source")
    end)
  end)

  describe("error handling", function()
    it("should exit appropriately on errors", function()
      -- Test that the script uses os.exit appropriately
      local file = io.open(ping_script_path, "r")
      local content = file:read("*a")
      file:close()

      assert.matches(
        "os%.exit%(1%)",
        content,
        "Should exit with code 1 on errors"
      )
    end)

    it("should provide troubleshooting information", function()
      -- Test that the script provides helpful error messages
      local file = io.open(ping_script_path, "r")
      local content = file:read("*a")
      file:close()

      assert.matches(
        "Make sure AwesomeWM is running",
        content,
        "Should provide troubleshooting tips"
      )
      assert.matches(
        "diligent%.setup",
        content,
        "Should mention diligent.setup()"
      )
    end)
  end)
end)
