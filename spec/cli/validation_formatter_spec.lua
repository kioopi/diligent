local assert = require("luassert")
local validation_formatter = require("cli.validation_formatter")

describe("CLI Validation Formatter", function()
  describe("format_validation_results", function()
    it("should format successful validation", function()
      local dsl = {
        name = "test-project",
        resources = {
          editor = {
            type = "app",
            cmd = "nvim",
            tag = 0,
          },
        },
      }

      local lines = validation_formatter.format_validation_results(dsl)

      assert.is_table(lines)
      assert.is_true(#lines > 0)

      -- Check that it contains expected success indicators
      local output = table.concat(lines, "\n")
      assert.matches("DSL syntax valid", output)
      assert.matches("Required fields present", output)
      assert.matches('Project name: "test%-project"', output)
      assert.matches("Resource 'editor': app helper valid", output)
    end)

    it("should format project with hooks", function()
      local dsl = {
        name = "test-project",
        resources = {},
        hooks = {
          start = "echo start",
          stop = "echo stop",
        },
      }

      local lines = validation_formatter.format_validation_results(dsl)
      local output = table.concat(lines, "\n")

      assert.matches("Hooks configured", output)
      assert.matches("start", output)
      assert.matches("stop", output)
    end)

    it("should handle empty resources", function()
      local dsl = {
        name = "test-project",
        resources = {},
      }

      local lines = validation_formatter.format_validation_results(dsl)
      local output = table.concat(lines, "\n")

      assert.matches("DSL syntax valid", output)
      assert.matches('Project name: "test%-project"', output)
      assert.matches("Validation failed", output) -- Empty resources is invalid
    end)

    it("should handle nil DSL", function()
      local lines = validation_formatter.format_validation_results(nil)

      assert.is_table(lines)
      assert.is_true(#lines > 0)
    end)
  end)

  describe("format_tag_description", function()
    it("should format relative tag offset 0", function()
      local desc = validation_formatter.format_tag_description(0)

      assert.are.equal(" (tag: relative offset 0)", desc)
    end)

    it("should format positive relative tag offset", function()
      local desc = validation_formatter.format_tag_description(2)

      assert.are.equal(" (tag: relative offset +2)", desc)
    end)

    it("should format negative relative tag offset", function()
      local desc = validation_formatter.format_tag_description(-1)

      assert.are.equal(" (tag: relative offset -1)", desc)
    end)

    it("should format absolute tag", function()
      local desc = validation_formatter.format_tag_description("5")

      assert.are.equal(" (tag: absolute tag 5)", desc)
    end)

    it("should format named tag", function()
      local desc = validation_formatter.format_tag_description("editor")

      assert.are.equal(' (tag: named "editor")', desc)
    end)

    it("should handle nil tag", function()
      local desc = validation_formatter.format_tag_description(nil)

      assert.are.equal("", desc)
    end)
  end)

  describe("format_resource_list", function()
    it("should format app resources with tags", function()
      local resources = {
        {
          name = "editor",
          type = "app",
          valid = true,
          tag = 0,
        },
        {
          name = "browser",
          type = "app",
          valid = true,
          tag = "3",
        },
      }

      local lines = validation_formatter.format_resource_list(resources)

      assert.is_table(lines)
      assert.are.equal(2, #lines)
      assert.matches(
        "Resource 'editor': app helper valid %(tag: relative offset 0%)",
        lines[1]
      )
      assert.matches(
        "Resource 'browser': app helper valid %(tag: absolute tag 3%)",
        lines[2]
      )
    end)

    it("should handle empty resource list", function()
      local lines = validation_formatter.format_resource_list({})

      assert.is_table(lines)
      assert.are.equal(0, #lines)
    end)

    it("should handle nil resource list", function()
      local lines = validation_formatter.format_resource_list(nil)

      assert.is_table(lines)
      assert.are.equal(0, #lines)
    end)
  end)

  describe("format_hooks_info", function()
    it("should format hooks list", function()
      local hooks = {
        start = "echo start",
        stop = "echo stop",
        pre_start = "echo pre",
      }

      local line = validation_formatter.format_hooks_info(hooks)

      assert.is_string(line)
      assert.matches("Hooks configured:", line)
      assert.matches("pre_start", line)
      assert.matches("start", line)
      assert.matches("stop", line)
    end)

    it("should handle empty hooks", function()
      local line = validation_formatter.format_hooks_info({})

      assert.is_nil(line)
    end)

    it("should handle nil hooks", function()
      local line = validation_formatter.format_hooks_info(nil)

      assert.is_nil(line)
    end)
  end)

  describe("generate_summary_line", function()
    it("should generate summary for successful validation", function()
      local summary = {
        valid = true,
        resource_count = 3,
        has_hooks = true,
        errors = {},
      }

      local line = validation_formatter.generate_summary_line(summary)

      assert.matches("Validation passed:", line)
      assert.matches("6 checks passed", line) -- 2 basic + 3 resources + 1 hooks
      assert.matches("0 errors", line)
    end)

    it("should generate summary for failed validation", function()
      local summary = {
        valid = false,
        resource_count = 2,
        has_hooks = false,
        errors = { "error 1", "error 2" },
      }

      local line = validation_formatter.generate_summary_line(summary)

      assert.matches("Validation failed:", line)
      assert.matches("2 errors", line)
    end)
  end)
end)
