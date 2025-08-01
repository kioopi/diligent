local assert = require("luassert")
local validate_args = require("cli.validate_args")

describe("CLI Validate Args", function()
  describe("validate_parsed_args", function()
    it("should accept project name only", function()
      local args = {
        PROJECT_NAME = "test-project",
        file = nil,
      }

      local success, result = validate_args.validate_parsed_args(args)

      assert.is_true(success)
      assert.are.equal("project", result.input_type)
      assert.are.equal("test-project", result.project_name)
      assert.is_nil(result.file_path)
    end)

    it("should accept file path only", function()
      local args = {
        PROJECT_NAME = nil,
        file = "/path/to/project.lua",
      }

      local success, result = validate_args.validate_parsed_args(args)

      assert.is_true(success)
      assert.are.equal("file", result.input_type)
      assert.are.equal("/path/to/project.lua", result.file_path)
      assert.is_nil(result.project_name)
    end)

    it("should reject both project name and file path", function()
      local args = {
        PROJECT_NAME = "test-project",
        file = "/path/to/project.lua",
      }

      local success, error_msg = validate_args.validate_parsed_args(args)

      assert.is_false(success)
      assert.matches(
        "Cannot use both project name and %-%-file option",
        error_msg
      )
    end)

    it("should reject neither project name nor file path", function()
      local args = {
        PROJECT_NAME = nil,
        file = nil,
      }

      local success, error_msg = validate_args.validate_parsed_args(args)

      assert.is_false(success)
      assert.matches(
        "Must provide either project name or %-%-file option",
        error_msg
      )
    end)

    it("should handle empty project name", function()
      local args = {
        PROJECT_NAME = "",
        file = nil,
      }

      local success, error_msg = validate_args.validate_parsed_args(args)

      assert.is_false(success)
      assert.matches(
        "Must provide either project name or %-%-file option",
        error_msg
      )
    end)

    it("should handle empty file path", function()
      local args = {
        PROJECT_NAME = nil,
        file = "",
      }

      local success, error_msg = validate_args.validate_parsed_args(args)

      assert.is_false(success)
      assert.matches(
        "Must provide either project name or %-%-file option",
        error_msg
      )
    end)
  end)

  describe("get_error_type", function()
    it("should return MISSING_INPUT for no arguments", function()
      local args = {
        PROJECT_NAME = nil,
        file = nil,
      }

      local error_type = validate_args.get_error_type(args)

      assert.are.equal(validate_args.ERROR_MISSING_INPUT, error_type)
    end)

    it("should return CONFLICTING_INPUT for both arguments", function()
      local args = {
        PROJECT_NAME = "test",
        file = "/path/to/file.lua",
      }

      local error_type = validate_args.get_error_type(args)

      assert.are.equal(validate_args.ERROR_CONFLICTING_INPUT, error_type)
    end)

    it("should return nil for valid arguments", function()
      local args = {
        PROJECT_NAME = "test",
        file = nil,
      }

      local error_type = validate_args.get_error_type(args)

      assert.is_nil(error_type)
    end)
  end)

  describe("constants", function()
    it("should define error type constants", function()
      assert.is_not_nil(validate_args.ERROR_MISSING_INPUT)
      assert.is_not_nil(validate_args.ERROR_CONFLICTING_INPUT)
      assert.are_not.equal(
        validate_args.ERROR_MISSING_INPUT,
        validate_args.ERROR_CONFLICTING_INPUT
      )
    end)

    it("should define input type constants", function()
      assert.is_not_nil(validate_args.INPUT_TYPE_PROJECT)
      assert.is_not_nil(validate_args.INPUT_TYPE_FILE)
      assert.are_not.equal(
        validate_args.INPUT_TYPE_PROJECT,
        validate_args.INPUT_TYPE_FILE
      )
    end)
  end)
end)
