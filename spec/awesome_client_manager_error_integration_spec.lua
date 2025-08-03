local assert = require("luassert")

describe("awesome_client_manager error integration", function()
  local acm

  before_each(function()
    -- Mock the AwesomeWM dependencies for testing
    package.loaded["awful"] = {
      spawn = function(cmd, props)
        return 1234, "snid"
      end,
      screen = {
        focused = function()
          return { index = 1, tags = {}, selected_tag = { index = 1 } }
        end,
      },
      tag = {
        add = function(name, props)
          return { name = name, index = 1 }
        end,
      },
      placement = {},
    }
    _G.client = {
      get = function()
        return {}
      end,
    }

    -- Clear module cache to ensure clean state
    package.loaded["awesome_client_manager"] = nil

    acm = require("awesome_client_manager")
  end)

  after_each(function()
    -- Clean up global state
    package.loaded["awful"] = nil
    _G.client = nil
  end)

  describe("error handling integration", function()
    it("should provide spawn_with_error_reporting function", function()
      assert.is_function(acm.spawn_with_error_reporting)
    end)

    it("should use new error classification system", function()
      -- Mock awful.spawn to return an error for this test
      package.loaded["awful"].spawn = function(cmd, props)
        return "No such file or directory" -- Return error string
      end

      local result = acm.spawn_with_error_reporting("nonexistent_app", "0", {})

      assert.is_table(result)
      assert.is_false(result.success)
      assert.is_not_nil(result.error_report)
      assert.is_string(result.error_report.error_type)
      assert.is_string(result.error_report.user_message)
      assert.is_table(result.error_report.suggestions)
    end)

    it("should format errors using new formatter", function()
      local error_report = {
        app_name = "test_app",
        user_message = "Test error message",
        suggestions = { "Test suggestion 1", "Test suggestion 2" },
      }

      -- Test that format_error_for_user function still works
      local formatted = acm.format_error_for_user(error_report)

      assert.is_string(formatted)
      assert.matches("✗ Failed to spawn test_app", formatted)
      assert.matches("Error: Test error message", formatted)
      assert.matches("• Test suggestion 1", formatted)
    end)

    it(
      "should maintain ERROR_TYPES constants for backward compatibility",
      function()
        assert.is_string(acm.ERROR_TYPES.COMMAND_NOT_FOUND)
        assert.is_string(acm.ERROR_TYPES.PERMISSION_DENIED)
        assert.is_string(acm.ERROR_TYPES.INVALID_COMMAND)
        assert.is_string(acm.ERROR_TYPES.TIMEOUT)
        assert.is_string(acm.ERROR_TYPES.DEPENDENCY_FAILED)
        assert.is_string(acm.ERROR_TYPES.TAG_RESOLUTION_FAILED)
        assert.is_string(acm.ERROR_TYPES.UNKNOWN)
      end
    )

    it("should classify errors using new classification system", function()
      local error_type, user_message =
        acm.classify_error("No such file or directory")

      assert.equals(acm.ERROR_TYPES.COMMAND_NOT_FOUND, error_type)
      assert.equals("Command not found in PATH", user_message)
    end)

    it("should create error reports using new reporting system", function()
      local report =
        acm.create_error_report("firefox", "+2", "Permission denied", {})

      assert.is_table(report)
      assert.equals("firefox", report.app_name)
      assert.equals("+2", report.tag_spec)
      assert.equals(acm.ERROR_TYPES.PERMISSION_DENIED, report.error_type)
      assert.equals("Permission denied", report.original_message)
      assert.is_table(report.suggestions)
    end)

    it("should get error suggestions using new suggestion system", function()
      local suggestions =
        acm.get_error_suggestions(acm.ERROR_TYPES.COMMAND_NOT_FOUND, "firefox")

      assert.is_table(suggestions)
      assert.truthy(#suggestions >= 3)
      assert.matches(
        "Check if 'firefox' is installed",
        table.concat(suggestions, " ")
      )
    end)

    it("should create spawn summaries using new aggregation system", function()
      local spawn_results = {
        { success = true, app_name = "app1" },
        {
          success = false,
          app_name = "app2",
          error_report = { error_type = "COMMAND_NOT_FOUND" },
        },
      }

      local summary = acm.create_spawn_summary(spawn_results)

      assert.is_table(summary)
      assert.equals(2, summary.total_attempts)
      assert.equals(1, summary.successful)
      assert.equals(1, summary.failed)
      assert.equals(0.5, summary.success_rate)
    end)

    it("should maintain all existing public API functions", function()
      -- Client tracking functions
      assert.is_function(acm.get_client_info)
      assert.is_function(acm.read_process_env)
      assert.is_function(acm.get_client_properties)
      assert.is_function(acm.find_by_pid)
      assert.is_function(acm.find_by_env)
      assert.is_function(acm.find_by_property)
      assert.is_function(acm.find_by_name_or_class)
      assert.is_function(acm.set_client_property)
      assert.is_function(acm.get_all_tracked_clients)

      -- Spawning functions
      assert.is_function(acm.resolve_tag_spec)
      assert.is_function(acm.build_spawn_properties)
      assert.is_function(acm.build_command_with_env)
      assert.is_function(acm.spawn_with_properties)
      assert.is_function(acm.spawn_simple)
      assert.is_function(acm.wait_and_set_properties)

      -- Error handling functions (delegated to new modules)
      assert.is_function(acm.classify_error)
      assert.is_function(acm.create_error_report)
      assert.is_function(acm.get_error_suggestions)
      assert.is_function(acm.create_spawn_summary)
      assert.is_function(acm.format_error_for_user)
      assert.is_function(acm.spawn_with_error_reporting)
    end)
  end)
end)
