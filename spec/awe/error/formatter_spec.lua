local assert = require("luassert")

describe("awe.error.formatter", function()
  local formatter_factory, formatter

  setup(function()
    _G._TEST = true
  end)
  teardown(function()
    _G._TEST = nil
  end)

  before_each(function()
    -- Clear module cache
    package.loaded["awe.error.formatter"] = nil

    formatter_factory = require("awe.error.formatter")
    formatter = formatter_factory.create()
  end)

  describe("factory pattern", function()
    it("should create formatter with default interface", function()
      assert.is_not_nil(formatter)
      assert.is_function(formatter.format_error_for_user)
    end)

    it("should create formatter with custom interface", function()
      local mock_interface = { type = "mock" }
      local custom_formatter = formatter_factory.create(mock_interface)

      assert.is_not_nil(custom_formatter)
      assert.is_function(custom_formatter.format_error_for_user)
    end)
  end)

  describe("format_error_for_user function", function()
    it("should format complete error report", function()
      local error_report = {
        app_name = "firefox",
        user_message = "Command not found in PATH",
        suggestions = {
          "Check if 'firefox' is installed",
          "Verify the command name is spelled correctly",
          "Add the application's directory to your PATH",
        },
      }

      local formatted = formatter.format_error_for_user(error_report)

      assert.is_string(formatted)
      assert.matches("✗ Failed to spawn firefox", formatted)
      assert.matches("Error: Command not found in PATH", formatted)
      assert.matches("Suggestions:", formatted)
      assert.matches("• Check if 'firefox' is installed", formatted)
      assert.matches(
        "• Verify the command name is spelled correctly",
        formatted
      )
      assert.matches(
        "• Add the application's directory to your PATH",
        formatted
      )
    end)

    it("should handle missing app_name gracefully", function()
      local error_report = {
        user_message = "Some error occurred",
      }

      local formatted = formatter.format_error_for_user(error_report)

      assert.matches("✗ Failed to spawn application", formatted)
      assert.matches("Error: Some error occurred", formatted)
    end)

    it("should handle empty suggestions", function()
      local error_report = {
        app_name = "testapp",
        user_message = "Test error",
        suggestions = {},
      }

      local formatted = formatter.format_error_for_user(error_report)

      assert.matches("✗ Failed to spawn testapp", formatted)
      assert.matches("Error: Test error", formatted)
      assert.not_matches("Suggestions:", formatted)
    end)

    it("should handle missing suggestions field", function()
      local error_report = {
        app_name = "testapp",
        user_message = "Test error",
      }

      local formatted = formatter.format_error_for_user(error_report)

      assert.matches("✗ Failed to spawn testapp", formatted)
      assert.matches("Error: Test error", formatted)
      assert.not_matches("Suggestions:", formatted)
    end)

    it("should handle nil error report", function()
      local formatted = formatter.format_error_for_user(nil)

      assert.equals("Unknown error occurred", formatted)
    end)

    it("should format multiline output correctly", function()
      local error_report = {
        app_name = "vim",
        user_message = "Permission denied",
        suggestions = { "Check permissions", "Run with sudo" },
      }

      local formatted = formatter.format_error_for_user(error_report)
      local lines = {}
      for line in formatted:gmatch("[^\n]+") do
        table.insert(lines, line)
      end

      assert.truthy(#lines >= 4) -- At least app line, error line, suggestions header, suggestions
      assert.matches("✗ Failed to spawn vim", lines[1])
      assert.matches("Error: Permission denied", lines[2])
      assert.matches("Suggestions:", lines[3])
      assert.matches("• Check permissions", lines[4])
    end)

    it("should handle special characters in app name", function()
      local error_report = {
        app_name = "app-with-dashes_and_underscores",
        user_message = "Test error",
      }

      local formatted = formatter.format_error_for_user(error_report)

      assert.matches(
        "✗ Failed to spawn app%-with%-dashes_and_underscores",
        formatted
      )
    end)

    it("should handle long suggestion lists", function()
      local suggestions = {}
      for i = 1, 10 do
        table.insert(suggestions, "Suggestion number " .. i)
      end

      local error_report = {
        app_name = "testapp",
        user_message = "Test error",
        suggestions = suggestions,
      }

      local formatted = formatter.format_error_for_user(error_report)

      -- Should include all suggestions
      for i = 1, 10 do
        assert.matches("• Suggestion number " .. i, formatted)
      end
    end)
  end)
end)
