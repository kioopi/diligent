local assert = require("luassert")

describe("diligent.error.formatter", function()
  local formatter

  before_each(function()
    package.loaded["diligent.error.formatter"] = nil
    local formatter_factory = require("diligent.error.formatter")
    formatter = formatter_factory.create()
  end)

  describe("format_tag_error_for_cli", function()
    it("should format tag overflow errors for CLI", function()
      local error_obj = {
        type = "TAG_OVERFLOW",
        resource_id = "editor",
        tag_spec = 9,
        message = "Tag overflow: resolved index 11 exceeds maximum 9",
        context = {
          base_tag = 2,
          resolved_index = 11,
          final_index = 9
        },
        suggestions = {
          "Consider using absolute tag \"9\" instead", 
          "Check if relative offset +9 was intended"
        }
      }

      local formatted = formatter.format_tag_error_for_cli(error_obj)

      assert.matches("editor", formatted)
      assert.matches("Tag overflow", formatted)
      assert.matches("11.*9", formatted) -- shows overflow: 11 → 9
      assert.matches("absolute tag", formatted)
      assert.matches("•", formatted) -- bullet points for suggestions
    end)

    it("should format invalid tag spec errors for CLI", function()
      local error_obj = {
        type = "TAG_SPEC_INVALID",
        resource_id = "browser",
        tag_spec = true,
        message = "Invalid tag specification: must be number or string",
        suggestions = {
          "Provide tag as number (relative offset) or string (absolute/named)",
          "Check DSL syntax for tag specification"
        }
      }

      local formatted = formatter.format_tag_error_for_cli(error_obj)

      assert.matches("browser", formatted)
      assert.matches("Invalid tag", formatted)
      assert.matches("number or string", formatted)
    end)

    it("should handle missing suggestions gracefully", function()
      local error_obj = {
        type = "TAG_OVERFLOW",
        resource_id = "editor",
        message = "Tag overflow"
        -- no suggestions
      }

      local formatted = formatter.format_tag_error_for_cli(error_obj)

      assert.matches("editor", formatted)
      assert.matches("Tag overflow", formatted)
      -- Should not crash, should still produce readable output
    end)
  end)

  describe("format_multiple_errors_for_cli", function()
    it("should group errors by phase and format nicely", function()
      local errors = {
        {
          phase = "tag_resolution",
          resource_id = "editor",
          error = {
            type = "TAG_OVERFLOW",
            message = "Tag overflow: 11 → 9",
            suggestions = {"Use absolute tag \"9\""}
          }
        },
        {
          phase = "tag_resolution", 
          resource_id = "browser",
          error = {
            type = "TAG_SPEC_INVALID",
            message = "Invalid tag spec: boolean",
            suggestions = {"Use number or string"}
          }
        },
        {
          phase = "spawning",
          resource_id = "terminal",
          error = {
            type = "COMMAND_NOT_FOUND",
            message = "Command 'alacritty' not found",
            suggestions = {"Install alacritty package"}
          }
        }
      }

      local formatted = formatter.format_multiple_errors_for_cli(errors)

      -- Should have clear section headers
      assert.matches("TAG RESOLUTION ERRORS", formatted)
      assert.matches("SPAWNING ERRORS", formatted)

      -- Should show all resources
      assert.matches("editor", formatted)
      assert.matches("browser", formatted) 
      assert.matches("terminal", formatted)

      -- Should show error details
      assert.matches("Tag overflow", formatted)
      assert.matches("Invalid tag spec", formatted)
      assert.matches("Command.*not found", formatted)

      -- Should show suggestions with bullet points
      local bullet_count = select(2, formatted:gsub("•", ""))
      assert.is_true(bullet_count >= 3, "Should have at least 3 bullet points for suggestions")
    end)

    it("should handle single phase errors", function()
      local errors = {
        {
          phase = "tag_resolution",
          resource_id = "editor",
          error = {type = "TAG_OVERFLOW", message = "Overflow"}
        },
        {
          phase = "tag_resolution",
          resource_id = "browser", 
          error = {type = "TAG_SPEC_INVALID", message = "Invalid"}
        }
      }

      local formatted = formatter.format_multiple_errors_for_cli(errors)

      assert.matches("TAG RESOLUTION ERRORS", formatted)
      assert.not_matches("SPAWNING ERRORS", formatted)
    end)
  end)

  describe("format_partial_success_for_cli", function()
    it("should format partial success information", function()
      local partial_success = {
        spawned_resources = {
          {name = "terminal", pid = 12345},
          {name = "editor", pid = 12346}
        },
        total_spawned = 2
      }

      local formatted = formatter.format_partial_success_for_cli(partial_success)

      assert.matches("PARTIAL SUCCESS", formatted)
      assert.matches("terminal.*12345", formatted)
      assert.matches("editor.*12346", formatted) 
      assert.matches("✓", formatted) -- success checkmarks
    end)

    it("should handle empty partial success", function()
      local partial_success = {
        spawned_resources = {},
        total_spawned = 0
      }

      local result = formatter.format_partial_success_for_cli(partial_success)
      
      assert.is_nil(result) -- Should not format anything for empty success
    end)
  end)

  describe("format_dry_run_warnings", function()
    it("should format dry-run warnings with context", function()
      local warnings = {
        {
          type = "overflow",
          resource_id = "browser",
          original_index = 11,
          final_index = 9,
          suggestion = "Use absolute tag \"9\" for clarity"
        },
        {
          type = "tag_creation",
          resource_id = "terminal", 
          tag_name = "workspace",
          suggestion = "Tag \"workspace\" will be created"
        }
      }

      local formatted = formatter.format_dry_run_warnings(warnings)

      assert.matches("WARNINGS", formatted)
      assert.matches("browser", formatted)
      assert.matches("overflow.*11.*9", formatted)
      assert.matches("terminal", formatted)
      assert.matches("workspace.*created", formatted)
      assert.matches("⚠", formatted) -- warning symbols
    end)

    it("should handle no warnings", function()
      local result = formatter.format_dry_run_warnings({})
      
      assert.is_nil(result)
    end)
  end)
end)