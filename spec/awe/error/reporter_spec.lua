local assert = require("luassert")

describe("awe.error.reporter", function()
  local reporter_factory, reporter

  before_each(function()
    -- Clear module cache
    package.loaded["awe.error.reporter"] = nil

    reporter_factory = require("awe.error.reporter")
    reporter = reporter_factory.create()
  end)

  describe("factory pattern", function()
    it("should create reporter with default interface", function()
      assert.is_not_nil(reporter)
      assert.is_function(reporter.create_error_report)
      assert.is_function(reporter.get_error_suggestions)
      assert.is_function(reporter.create_spawn_summary)
    end)

    it("should create reporter with custom interface", function()
      local mock_interface = { type = "mock" }
      local custom_reporter = reporter_factory.create(mock_interface)

      assert.is_not_nil(custom_reporter)
      assert.is_function(custom_reporter.create_error_report)
    end)
  end)

  describe("create_error_report function", function()
    it("should create structured error report", function()
      local app_name = "firefox"
      local tag_spec = "+2"
      local error_message = "No such file or directory"
      local context = { config = {} }

      local report =
        reporter.create_error_report(app_name, tag_spec, error_message, context)

      assert.is_table(report)
      assert.is_number(report.timestamp)
      assert.equals(app_name, report.app_name)
      assert.equals(tag_spec, report.tag_spec)
      assert.equals("COMMAND_NOT_FOUND", report.error_type)
      assert.equals(error_message, report.original_message)
      assert.equals("Command not found in PATH", report.user_message)
      assert.equals(context, report.context)
      assert.is_table(report.suggestions)
    end)

    it("should handle missing context", function()
      local report = reporter.create_error_report("app", "tag", "error", nil)

      assert.is_table(report.context)
    end)

    it("should classify error correctly", function()
      local report =
        reporter.create_error_report("app", "tag", "Permission denied")

      assert.equals("PERMISSION_DENIED", report.error_type)
      assert.equals("Insufficient permissions to execute", report.user_message)
    end)

    it("should include suggestions in report", function()
      local report = reporter.create_error_report(
        "firefox",
        "tag",
        "No such file or directory"
      )

      assert.is_table(report.suggestions)
      assert.truthy(#report.suggestions > 0)
      assert.matches(
        "Check if 'firefox' is installed",
        table.concat(report.suggestions, " ")
      )
    end)
  end)

  describe("get_error_suggestions function", function()
    it("should provide suggestions for COMMAND_NOT_FOUND", function()
      local suggestions =
        reporter.get_error_suggestions("COMMAND_NOT_FOUND", "firefox")

      assert.is_table(suggestions)
      assert.truthy(#suggestions >= 3)
      assert.matches(
        "Check if 'firefox' is installed",
        table.concat(suggestions, " ")
      )
      assert.matches("spelled correctly", table.concat(suggestions, " "))
      assert.matches("PATH", table.concat(suggestions, " "))
    end)

    it("should provide suggestions for PERMISSION_DENIED", function()
      local suggestions = reporter.get_error_suggestions("PERMISSION_DENIED")

      assert.is_table(suggestions)
      assert.truthy(#suggestions >= 3)
      assert.matches("permissions", table.concat(suggestions, " "))
    end)

    it("should provide suggestions for INVALID_COMMAND", function()
      local suggestions = reporter.get_error_suggestions("INVALID_COMMAND")

      assert.is_table(suggestions)
      assert.matches("valid command", table.concat(suggestions, " "))
    end)

    it("should provide suggestions for TIMEOUT", function()
      local suggestions = reporter.get_error_suggestions("TIMEOUT")

      assert.is_table(suggestions)
      assert.matches("timeout", table.concat(suggestions, " "))
    end)

    it("should provide suggestions for TAG_RESOLUTION_FAILED", function()
      local suggestions =
        reporter.get_error_suggestions("TAG_RESOLUTION_FAILED")

      assert.is_table(suggestions)
      assert.matches("tag specification", table.concat(suggestions, " "))
    end)

    it("should provide generic suggestions for unknown error types", function()
      local suggestions = reporter.get_error_suggestions("UNKNOWN_TYPE")

      assert.is_table(suggestions)
      assert.matches("application logs", table.concat(suggestions, " "))
    end)
  end)

  describe("create_spawn_summary function", function()
    it("should create summary from empty results", function()
      local summary = reporter.create_spawn_summary({})

      assert.is_table(summary)
      assert.is_number(summary.timestamp)
      assert.equals(0, summary.total_attempts)
      assert.equals(0, summary.successful)
      assert.equals(0, summary.failed)
      assert.equals(0, summary.success_rate)
      assert.is_table(summary.results)
      assert.is_table(summary.error_types)
      assert.is_table(summary.recommendations)
    end)

    it("should count successful and failed attempts", function()
      local spawn_results = {
        { success = true, app_name = "app1" },
        {
          success = false,
          app_name = "app2",
          error_report = { error_type = "COMMAND_NOT_FOUND" },
        },
        { success = true, app_name = "app3" },
      }

      local summary = reporter.create_spawn_summary(spawn_results)

      assert.equals(3, summary.total_attempts)
      assert.equals(2, summary.successful)
      assert.equals(1, summary.failed)
      assert.equals(2 / 3, summary.success_rate)
    end)

    it("should count error types", function()
      local spawn_results = {
        {
          success = false,
          error_report = { error_type = "COMMAND_NOT_FOUND" },
        },
        {
          success = false,
          error_report = { error_type = "COMMAND_NOT_FOUND" },
        },
        {
          success = false,
          error_report = { error_type = "PERMISSION_DENIED" },
        },
      }

      local summary = reporter.create_spawn_summary(spawn_results)

      assert.equals(2, summary.error_types["COMMAND_NOT_FOUND"])
      assert.equals(1, summary.error_types["PERMISSION_DENIED"])
    end)

    it("should generate recommendations based on error patterns", function()
      local spawn_results = {
        {
          success = false,
          error_report = { error_type = "COMMAND_NOT_FOUND" },
        },
        {
          success = false,
          error_report = { error_type = "PERMISSION_DENIED" },
        },
      }

      local summary = reporter.create_spawn_summary(spawn_results)

      assert.is_table(summary.recommendations)
      local rec_text = table.concat(summary.recommendations, " ")
      assert.matches("not be installed", rec_text)
      assert.matches("Permission issues", rec_text)
    end)

    it(
      "should recommend configuration review when failures exceed successes",
      function()
        local spawn_results = {
          { success = false },
          { success = false },
          { success = true },
        }

        local summary = reporter.create_spawn_summary(spawn_results)

        local rec_text = table.concat(summary.recommendations, " ")
        assert.matches("project configuration", rec_text)
      end
    )

    it("should handle missing error reports gracefully", function()
      local spawn_results = {
        { success = false }, -- No error_report field
      }

      local summary = reporter.create_spawn_summary(spawn_results)

      assert.equals(1, summary.error_types["UNKNOWN"])
    end)
  end)
end)
