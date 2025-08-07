local assert = require("luassert")

describe("CLI Error Display Integration", function()
  local mock_interface
  local start_handler
  local awe
  local error_formatter

  before_each(function()
    _G._TEST = true
    mock_interface = require("awe.interfaces.mock_interface")
    mock_interface.reset()
    start_handler = require("diligent.handlers.start")
    awe = require("awe").create(mock_interface)

    -- Load the rich error formatter
    local formatter_factory = require("diligent.error.formatter")
    error_formatter = formatter_factory.create(mock_interface)
  end)

  teardown(function()
    _G._TEST = nil
  end)

  describe("Enhanced Error Response Format Detection", function()
    it(
      "should detect enhanced error response format vs simple format",
      function()
        -- This test will fail initially because CLI doesn't detect enhanced format
        local enhanced_response = {
          project_name = "test-project",
          error_type = "COMPLETE_FAILURE",
          errors = {
            {
              phase = "tag_resolution",
              resource_id = "editor",
              error = {
                type = "TAG_OVERFLOW",
                message = "Tag overflow: resolved to tag 9",
                suggestions = { 'Use absolute tag "9"' },
              },
            },
          },
          metadata = {
            total_attempted = 1,
            success_count = 0,
            error_count = 1,
          },
        }

        -- Function we need to implement: detect_response_format
        local cli_utils = require("cli.response_formatter") -- This doesn't exist yet
        local format_type = cli_utils.detect_response_format(enhanced_response)

        assert.equals(
          "enhanced",
          format_type,
          "Should detect enhanced response format"
        )
      end
    )

    it("should detect simple error response format", function()
      local simple_response = {
        error = "Tag resolution failed: Invalid tag",
        failed_resource = "editor",
        project_name = "test-project",
      }

      local cli_utils = require("cli.response_formatter") -- This doesn't exist yet
      local format_type = cli_utils.detect_response_format(simple_response)

      assert.equals(
        "simple",
        format_type,
        "Should detect simple response format"
      )
    end)
  end)

  describe("Rich CLI Error Formatting", function()
    it("should format single tag resolution error with suggestions", function()
      local enhanced_response = {
        project_name = "test-project",
        error_type = "COMPLETE_FAILURE",
        errors = {
          {
            phase = "tag_resolution",
            resource_id = "editor",
            error = {
              type = "TAG_OVERFLOW",
              message = "Tag overflow: resolved to tag 9",
              context = {
                base_tag = 2,
                resolved_index = 11,
                final_index = 9,
              },
              suggestions = {
                'Consider using absolute tag "9" instead',
                "Check if relative offset +9 was intended",
              },
            },
          },
        },
        metadata = {
          total_attempted = 1,
          success_count = 0,
          error_count = 1,
        },
      }

      -- This will fail because CLI doesn't use rich formatter yet
      local cli_utils = require("cli.response_formatter")
      local formatted_output =
        cli_utils.format_enhanced_error_response(enhanced_response)

      -- Expect rich formatting with symbols and suggestions
      assert.matches("✗", formatted_output, "Should contain error symbol")
      assert.matches(
        "TAG RESOLUTION ERRORS:",
        formatted_output,
        "Should group errors by phase"
      )
      assert.matches(
        "editor.*Tag overflow",
        formatted_output,
        "Should show resource and error"
      )
      assert.matches(
        "Consider using absolute tag",
        formatted_output,
        "Should show suggestions"
      )
      assert.matches(
        "•",
        formatted_output,
        "Should format suggestions with bullets"
      )
    end)

    it("should format partial success with mixed errors", function()
      local partial_response = {
        project_name = "mixed-test",
        error_type = "PARTIAL_FAILURE",
        errors = {
          {
            phase = "spawning",
            resource_id = "browser",
            error = {
              type = "SPAWN_FAILURE",
              message = "Command not found: firefox-nightly",
              context = { command = "firefox-nightly" },
              suggestions = {
                "Check if 'firefox-nightly' is installed",
                "Verify command name spelling",
              },
            },
          },
        },
        partial_success = {
          spawned_resources = {
            {
              name = "editor",
              pid = 12345,
              command = "gedit",
            },
          },
          total_spawned = 1,
        },
        metadata = {
          total_attempted = 2,
          success_count = 1,
          error_count = 1,
        },
      }

      local cli_utils = require("cli.response_formatter")
      local formatted_output =
        cli_utils.format_enhanced_error_response(partial_response)

      -- Expect both error and success sections
      assert.matches(
        "SPAWNING ERRORS:",
        formatted_output,
        "Should show spawning errors section"
      )
      assert.matches(
        "✗.*browser.*Command not found",
        formatted_output,
        "Should show spawn error"
      )
      assert.matches(
        "PARTIAL SUCCESS:",
        formatted_output,
        "Should show partial success section"
      )
      assert.matches(
        "✓.*editor.*PID.*12345",
        formatted_output,
        "Should show successful spawn"
      )
      assert.matches(
        "Check if.*installed",
        formatted_output,
        "Should show spawn error suggestions"
      )
    end)

    it("should format multiple error types with grouping", function()
      local multi_error_response = {
        project_name = "multi-error-test",
        error_type = "COMPLETE_FAILURE",
        errors = {
          {
            phase = "tag_resolution",
            resource_id = "editor",
            error = {
              type = "TAG_OVERFLOW",
              message = "Tag overflow: resolved to tag 9",
            },
          },
          {
            phase = "tag_resolution",
            resource_id = "browser",
            error = {
              type = "TAG_SPEC_INVALID",
              message = "Invalid tag specification",
            },
          },
          {
            phase = "spawning",
            resource_id = "terminal",
            error = {
              type = "SPAWN_FAILURE",
              message = "Permission denied",
            },
          },
        },
        metadata = {
          total_attempted = 3,
          success_count = 0,
          error_count = 3,
        },
      }

      local cli_utils = require("cli.response_formatter")
      local formatted_output =
        cli_utils.format_enhanced_error_response(multi_error_response)

      -- Expect grouped display
      assert.matches(
        "TAG RESOLUTION ERRORS:",
        formatted_output,
        "Should group tag resolution errors"
      )
      assert.matches(
        "SPAWNING ERRORS:",
        formatted_output,
        "Should group spawning errors"
      )

      -- Expect all errors shown
      assert.matches(
        "✗.*editor.*Tag overflow",
        formatted_output,
        "Should show editor tag error"
      )
      assert.matches(
        "✗.*browser.*Invalid tag",
        formatted_output,
        "Should show browser tag error"
      )
      assert.matches(
        "✗.*terminal.*Permission denied",
        formatted_output,
        "Should show terminal spawn error"
      )
    end)
  end)

  describe("Backwards Compatibility", function()
    it("should handle simple error responses with basic formatting", function()
      local simple_response = {
        error = "Tag resolution failed: Invalid tag specification",
        failed_resource = "editor",
        project_name = "test-project",
      }

      local cli_utils = require("cli.response_formatter")
      local formatted_output =
        cli_utils.format_simple_error_response(simple_response)

      -- Should use basic formatting for simple responses
      assert.matches(
        "Failed to start.*test%-project",
        formatted_output,
        "Should show project failure"
      )
      assert.matches(
        "Tag resolution failed",
        formatted_output,
        "Should show error message"
      )
      assert.matches(
        "editor",
        formatted_output,
        "Should mention failed resource"
      )
    end)

    it("should handle success responses with resource details", function()
      local success_response = {
        status = "success",
        project_name = "success-test",
        total_spawned = 2,
        spawned_resources = {
          { name = "editor", pid = 12345, command = "gedit" },
          { name = "browser", pid = 12346, command = "firefox" },
        },
        tag_operations = {
          created_tags = {},
          assignments = {},
          total_created = 0,
        },
      }

      local cli_utils = require("cli.response_formatter")
      local formatted_output =
        cli_utils.format_success_response(success_response)

      -- Should show success details
      assert.matches(
        "Started.*success%-test.*successfully",
        formatted_output,
        "Should show success message"
      )
      assert.matches(
        "Spawned.*2.*resources",
        formatted_output,
        "Should show spawn count"
      )
      assert.matches(
        "✓.*editor.*PID.*12345",
        formatted_output,
        "Should show editor details"
      )
      assert.matches(
        "✓.*browser.*PID.*12346",
        formatted_output,
        "Should show browser details"
      )
    end)
  end)

  describe("CLI Integration with Handler", function()
    it("should process enhanced error responses end-to-end", function()
      -- Create a scenario that will generate an enhanced error response
      mock_interface.set_current_tag_index(2)

      -- Mock tag_mapper to return structured error
      local original_tag_mapper = package.loaded["tag_mapper"]
      package.loaded["tag_mapper"] = {
        get_current_tag = function(interface)
          return 2
        end,
        resolve_tags_for_project = function(resources, base_tag, interface)
          return nil,
            {
              type = "TAG_OVERFLOW",
              category = "validation",
              resource_id = "editor",
              message = "Tag overflow: resolved to tag 9",
              context = {
                base_tag = 2,
                resolved_index = 11,
                original_spec = 9,
              },
              suggestions = {
                'Consider using absolute tag "9"',
                "Check if you intended a relative offset",
              },
            }
        end,
      }

      -- Force handler to reload with mocked tag_mapper
      local original_start_handler = package.loaded["diligent.handlers.start"]
      package.loaded["diligent.handlers.start"] = nil
      start_handler = require("diligent.handlers.start")

      local start_request = {
        project_name = "integration-test",
        resources = {
          {
            name = "editor",
            command = "gedit",
            tag_spec = 9, -- This will cause overflow
          },
        },
      }

      -- Execute through handler to get enhanced response
      local handler = start_handler.create(awe)
      local success, response = handler.execute(start_request)

      -- Should get enhanced response format
      assert.is_false(success, "Should fail due to tag overflow")
      assert.equals(
        "COMPLETE_FAILURE",
        response.error_type,
        "Should be complete failure"
      )
      assert.equals(1, #response.errors, "Should have one error")
      assert.equals(
        "tag_resolution",
        response.errors[1].phase,
        "Should be tag resolution error"
      )

      -- Now test CLI formatting (this will fail until we implement it)
      local cli_utils = require("cli.response_formatter")
      local formatted = cli_utils.format_enhanced_error_response(response)

      assert.matches(
        "TAG RESOLUTION ERRORS:",
        formatted,
        "CLI should format with rich display"
      )
      assert.matches(
        "✗.*system.*Critical tag mapper error.*Tag overflow",
        formatted,
        "Should show detailed error"
      )
      assert.matches(
        "Check tag_mapper module integrity",
        formatted,
        "Should show suggestions"
      )

      -- Restore original modules
      package.loaded["tag_mapper"] = original_tag_mapper
      package.loaded["diligent.handlers.start"] = original_start_handler
    end)
  end)
end)
