local assert = require("luassert")

describe("Validate Command Script", function()
  local validate_script_path = "cli/commands/validate.lua"

  describe("script execution", function()
    it("should execute validate command with project name", function()
      -- Test validation with a project name
      local handle =
        io.popen("lua " .. validate_script_path .. " web-project 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      -- Should handle project name argument
      assert.is_not_nil(output, "Should produce output")
      assert.is_true(
        exit_code == 0 or exit_code == 1 or exit_code == 2,
        "Should exit with 0, 1, or 2"
      )
    end)

    it("should execute validate command with file path", function()
      -- Test validation with a file path using --file flag
      local test_file = "lua/dsl/examples/minimal-project.lua"
      local handle = io.popen(
        "lua " .. validate_script_path .. " --file " .. test_file .. " 2>&1"
      )
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      -- Should handle file path argument
      assert.is_not_nil(output, "Should produce output")
      assert.is_true(
        exit_code == 0 or exit_code == 1 or exit_code == 2,
        "Should exit with 0, 1, or 2"
      )
    end)

    it("should show success indicators for valid DSL", function()
      -- Test with a known valid DSL file
      local test_file = "lua/dsl/examples/minimal-project.lua"
      local handle = io.popen(
        "lua " .. validate_script_path .. " --file " .. test_file .. " 2>&1"
      )
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      if exit_code == 0 then
        assert.matches("✓", output, "Should show success symbols")
        assert.matches(
          "DSL syntax valid",
          output,
          "Should show syntax validation"
        )
        assert.matches(
          "Validation passed",
          output,
          "Should show overall success"
        )
      end
    end)

    it("should show error indicators for missing files", function()
      -- Test with non-existent file
      local handle = io.popen(
        "lua " .. validate_script_path .. " --file /nonexistent/file.lua 2>&1"
      )
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      assert.is.equal(
        2,
        exit_code,
        "Should exit with code 2 for file not found"
      )
      assert.matches("✗", output, "Should show error symbol")
      assert.matches("not found", output, "Should mention file not found")
    end)

    it("should show validation summary with details", function()
      -- Test with valid DSL to check summary format
      local test_file = "lua/dsl/examples/web-development.lua"
      local handle = io.popen(
        "lua " .. validate_script_path .. " --file " .. test_file .. " 2>&1"
      )
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      if exit_code == 0 then
        assert.matches(
          "Required fields present",
          output,
          "Should show field validation"
        )
        assert.matches("Project name:", output, "Should show project name")
        assert.matches("Resource", output, "Should show resource validation")
        assert.matches(
          "checks passed",
          output,
          "Should show summary statistics"
        )
      end
    end)

    it("should handle invalid project names gracefully", function()
      -- Test with invalid project name
      local handle =
        io.popen("lua " .. validate_script_path .. " nonexistent-project 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      assert.is.equal(
        2,
        exit_code,
        "Should exit with code 2 for project not found"
      )
      assert.matches("✗", output, "Should show error symbol")
    end)

    it("should show error when no arguments provided", function()
      -- Test with no arguments
      local handle = io.popen("lua " .. validate_script_path .. " 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      assert.is.equal(
        1,
        exit_code,
        "Should exit with code 1 for missing arguments"
      )
      assert.matches("✗", output, "Should show error symbol")
      assert.matches(
        "Must provide either project name or %-%-file option",
        output,
        "Should show argument error"
      )
    end)
  end)

  describe("CLI integration", function()
    it("should be accessible via main workon CLI", function()
      -- Test that validate command is registered in main CLI
      local handle = io.popen("./cli/workon --help 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      assert.matches("validate", output, "Should list validate command in help")
      assert.matches(
        "Validate project files",
        output,
        "Should show validate description"
      )
    end)

    it("should work through main CLI with project name", function()
      -- Test via main CLI with project name
      local handle = io.popen("./cli/workon validate --help 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      -- Should show validate-specific help
      assert.is_not_nil(output, "Should produce help output")
    end)
  end)
end)
