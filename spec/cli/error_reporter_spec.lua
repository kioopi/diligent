local assert = require("luassert")
local error_reporter = require("cli.error_reporter")

describe("CLI Error Reporter", function()
  local mock_cli_printer
  local captured_error_calls

  before_each(function()
    -- Reset captured calls
    captured_error_calls = {}

    -- Mock cli_printer to prevent output during tests
    mock_cli_printer = {
      error = function(msg)
        table.insert(captured_error_calls, msg)
      end,
      success = function(msg)
        -- Not used by error_reporter, but included for completeness
      end,
      info = function(msg)
        -- Not used by error_reporter, but included for completeness
      end,
    }

    -- Inject mock into package cache
    package.loaded.cli_printer = mock_cli_printer

    -- Clear error_reporter from cache to ensure it uses our mock
    package.loaded["cli.error_reporter"] = nil
    error_reporter = require("cli.error_reporter")
  end)

  after_each(function()
    -- Clean up mocks
    package.loaded.cli_printer = nil
    package.loaded["cli.error_reporter"] = nil
  end)
  describe("report_error", function()
    it("should return proper exit code for validation errors", function()
      local exit_code = error_reporter.report_error(
        "syntax error: invalid token",
        error_reporter.ERROR_VALIDATION
      )

      assert.are.equal(error_reporter.EXIT_VALIDATION_ERROR, exit_code)
    end)

    it("should return proper exit code for file not found", function()
      local exit_code = error_reporter.report_error(
        "file not found",
        error_reporter.ERROR_FILE_NOT_FOUND
      )

      assert.are.equal(error_reporter.EXIT_FILE_NOT_FOUND, exit_code)
    end)

    it("should return proper exit code for argument errors", function()
      local exit_code = error_reporter.report_error(
        "invalid arguments",
        error_reporter.ERROR_INVALID_ARGS
      )

      assert.are.equal(error_reporter.EXIT_INVALID_ARGS, exit_code)
    end)

    it("should handle nil error message", function()
      local exit_code =
        error_reporter.report_error(nil, error_reporter.ERROR_VALIDATION)

      assert.are.equal(error_reporter.EXIT_VALIDATION_ERROR, exit_code)
    end)

    it("should handle unknown error type", function()
      local exit_code =
        error_reporter.report_error("unknown error", "unknown_type")

      assert.are.equal(error_reporter.EXIT_VALIDATION_ERROR, exit_code) -- Default to validation error
    end)
  end)

  describe("report_and_exit", function()
    -- Note: These tests can't actually test os.exit() behavior in unit tests
    -- They just verify the function exists and accepts the right parameters

    it("should accept valid error parameters", function()
      -- This test just verifies the function signature
      assert.has_no.errors(function()
        -- We can't actually call this in tests since it would exit
        assert.is_function(error_reporter.report_and_exit)
      end)
    end)
  end)

  describe("get_exit_code", function()
    it("should return correct exit code for validation errors", function()
      local exit_code =
        error_reporter.get_exit_code(error_reporter.ERROR_VALIDATION)

      assert.are.equal(error_reporter.EXIT_VALIDATION_ERROR, exit_code)
    end)

    it("should return correct exit code for file not found", function()
      local exit_code =
        error_reporter.get_exit_code(error_reporter.ERROR_FILE_NOT_FOUND)

      assert.are.equal(error_reporter.EXIT_FILE_NOT_FOUND, exit_code)
    end)

    it("should return correct exit code for project not found", function()
      local exit_code =
        error_reporter.get_exit_code(error_reporter.ERROR_PROJECT_NOT_FOUND)

      assert.are.equal(error_reporter.EXIT_FILE_NOT_FOUND, exit_code) -- Same as file not found
    end)

    it("should return correct exit code for invalid arguments", function()
      local exit_code =
        error_reporter.get_exit_code(error_reporter.ERROR_INVALID_ARGS)

      assert.are.equal(error_reporter.EXIT_INVALID_ARGS, exit_code)
    end)

    it("should return default exit code for unknown error type", function()
      local exit_code = error_reporter.get_exit_code("unknown_error_type")

      assert.are.equal(error_reporter.EXIT_VALIDATION_ERROR, exit_code)
    end)
  end)

  describe("format_error_message", function()
    it("should format simple error message", function()
      local formatted = error_reporter.format_error_message("test error")

      assert.is_string(formatted)
      assert.matches("test error", formatted)
    end)

    it("should handle nil message", function()
      local formatted = error_reporter.format_error_message(nil)

      assert.is_string(formatted)
      assert.matches("Unknown error", formatted)
    end)

    it("should handle empty message", function()
      local formatted = error_reporter.format_error_message("")

      assert.is_string(formatted)
      assert.matches("Unknown error", formatted)
    end)

    it("should format validation errors with context", function()
      local formatted = error_reporter.format_error_message(
        "syntax error",
        error_reporter.ERROR_VALIDATION
      )

      assert.is_string(formatted)
      assert.matches("Validation failed", formatted)
      assert.matches("syntax error", formatted)
    end)

    it("should format file not found errors", function()
      local formatted = error_reporter.format_error_message(
        "file.lua not found",
        error_reporter.ERROR_FILE_NOT_FOUND
      )

      assert.is_string(formatted)
      assert.matches("file.lua not found", formatted)
    end)
  end)

  describe("constants", function()
    it("should define error type constants", function()
      assert.is_not_nil(error_reporter.ERROR_VALIDATION)
      assert.is_not_nil(error_reporter.ERROR_FILE_NOT_FOUND)
      assert.is_not_nil(error_reporter.ERROR_PROJECT_NOT_FOUND)
      assert.is_not_nil(error_reporter.ERROR_INVALID_ARGS)

      -- Ensure they are different
      local constants = {
        error_reporter.ERROR_VALIDATION,
        error_reporter.ERROR_FILE_NOT_FOUND,
        error_reporter.ERROR_PROJECT_NOT_FOUND,
        error_reporter.ERROR_INVALID_ARGS,
      }

      for i = 1, #constants do
        for j = i + 1, #constants do
          assert.are_not.equal(constants[i], constants[j])
        end
      end
    end)

    it("should define exit code constants", function()
      assert.is_not_nil(error_reporter.EXIT_SUCCESS)
      assert.is_not_nil(error_reporter.EXIT_VALIDATION_ERROR)
      assert.is_not_nil(error_reporter.EXIT_FILE_NOT_FOUND)
      assert.is_not_nil(error_reporter.EXIT_INVALID_ARGS)

      -- Check they follow Unix conventions
      assert.are.equal(0, error_reporter.EXIT_SUCCESS)
      assert.are.equal(1, error_reporter.EXIT_VALIDATION_ERROR)
      assert.are.equal(2, error_reporter.EXIT_FILE_NOT_FOUND)
      assert.are.equal(1, error_reporter.EXIT_INVALID_ARGS)
    end)
  end)
end)
