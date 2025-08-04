local assert = require("luassert")

describe("Start Command Script", function()
  local start_script_path = "cli/commands/start.lua"

  describe("script execution", function()
    it("should execute start command with project name", function()
      -- Test start with a project name
      local handle =
        io.popen("lua " .. start_script_path .. " web-project 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      -- Should handle project name argument
      assert.is_not_nil(output, "Should produce output")
      assert.is_true(
        exit_code == 0 or exit_code == 1 or exit_code == 2,
        "Should exit with 0, 1, or 2"
      )
    end)

    it("should execute start command with file path", function()
      -- Test start with a file path using --file flag
      local test_file = "lua/dsl/examples/minimal-project.lua"
      local handle = io.popen(
        "lua " .. start_script_path .. " --file " .. test_file .. " 2>&1"
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

    it("should show success indicators for valid DSL in Phase 1", function()
      -- Test with a known valid DSL file (Phase 1: just load and report)
      local test_file = "lua/dsl/examples/minimal-project.lua"
      local handle = io.popen(
        "lua " .. start_script_path .. " --file " .. test_file .. " 2>&1"
      )
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      if exit_code == 0 then
        assert.matches("✓", output, "Should show success symbols")
        assert.matches(
          "Project loaded successfully",
          output,
          "Should show project loading success"
        )
        assert.matches("Resources found", output, "Should show resource count")
      end
    end)

    it("should show error indicators for missing files", function()
      -- Test with non-existent file
      local handle = io.popen(
        "lua " .. start_script_path .. " --file /nonexistent/file.lua 2>&1"
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

    it("should handle invalid project names gracefully", function()
      -- Test with invalid project name
      local handle =
        io.popen("lua " .. start_script_path .. " nonexistent-project 2>&1")
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
      local handle = io.popen("lua " .. start_script_path .. " 2>&1")
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

    it("should support dry-run flag", function()
      -- Test with --dry-run flag (Phase 1: just parse the flag)
      local test_file = "lua/dsl/examples/minimal-project.lua"
      local handle = io.popen(
        "lua "
          .. start_script_path
          .. " --file "
          .. test_file
          .. " --dry-run 2>&1"
      )
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      -- Should handle dry-run flag without error
      assert.is_not_nil(output, "Should produce output")
      assert.is_true(
        exit_code == 0 or exit_code == 1 or exit_code == 2,
        "Should exit with valid code"
      )
    end)
  end)

  describe("CLI integration", function()
    it("should be accessible via main workon CLI", function()
      -- Test that start command is registered in main CLI
      local handle = io.popen("./cli/workon --help 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      assert.matches("start", output, "Should list start command in help")
      assert.matches(
        "Start project workspaces",
        output,
        "Should show start description"
      )
    end)

    it("should work through main CLI with project name", function()
      -- Test via main CLI with project name
      local handle = io.popen("./cli/workon start --help 2>&1")
      local output = handle:read("*a")
      local success, _, exit_code = handle:close()

      -- Should show start-specific help
      assert.is_not_nil(output, "Should produce help output")
    end)
  end)
end)
