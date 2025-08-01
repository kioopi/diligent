local assert = require("luassert")
local project_loader = require("cli.project_loader")

describe("CLI Project Loader", function()
  describe("load_by_file_path", function()
    it("should load valid DSL file", function()
      local file_path = "lua/dsl/examples/minimal-project.lua"

      local success, result = project_loader.load_by_file_path(file_path)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal("minimal-project", result.name)
    end)

    it("should return file not found error for missing file", function()
      local file_path = "/nonexistent/file.lua"

      local success, error_msg = project_loader.load_by_file_path(file_path)

      assert.is_false(success)
      assert.matches("File not found", error_msg)
    end)

    it("should return validation error for invalid DSL", function()
      -- Create a temporary invalid DSL file for testing
      local temp_file = "/tmp/invalid_test.lua"
      local file = io.open(temp_file, "w")
      file:write("return { invalid_structure = true }")
      file:close()

      local success, error_msg = project_loader.load_by_file_path(temp_file)

      -- Clean up
      os.remove(temp_file)

      assert.is_false(success)
      assert.is_string(error_msg)
      assert.does_not_match("File not found", error_msg)
    end)

    it("should handle nil file path", function()
      local success, error_msg = project_loader.load_by_file_path(nil)

      assert.is_false(success)
      assert.matches("file path is required", error_msg)
    end)

    it("should handle empty file path", function()
      local success, error_msg = project_loader.load_by_file_path("")

      assert.is_false(success)
      assert.matches("file path is required", error_msg)
    end)
  end)

  describe("load_by_project_name", function()
    it("should return project not found error for missing project", function()
      local project_name = "nonexistent-project"

      local success, error_msg =
        project_loader.load_by_project_name(project_name)

      assert.is_false(success)
      assert.matches("Project not found", error_msg)
    end)

    it("should handle nil project name", function()
      local success, error_msg = project_loader.load_by_project_name(nil)

      assert.is_false(success)
      assert.matches("project name is required", error_msg)
    end)

    it("should handle empty project name", function()
      local success, error_msg = project_loader.load_by_project_name("")

      assert.is_false(success)
      assert.matches("project name is required", error_msg)
    end)
  end)

  describe("get_error_type", function()
    it("should return FILE_NOT_FOUND for file path errors", function()
      local error_type =
        project_loader.get_error_type("File not found: /test.lua")

      assert.are.equal(project_loader.ERROR_FILE_NOT_FOUND, error_type)
    end)

    it("should return PROJECT_NOT_FOUND for project name errors", function()
      local error_type =
        project_loader.get_error_type("Project not found: test-project")

      assert.are.equal(project_loader.ERROR_PROJECT_NOT_FOUND, error_type)
    end)

    it("should return VALIDATION_ERROR for other errors", function()
      local error_type =
        project_loader.get_error_type("syntax error: unexpected token")

      assert.are.equal(project_loader.ERROR_VALIDATION_ERROR, error_type)
    end)

    it("should handle nil error message", function()
      local error_type = project_loader.get_error_type(nil)

      assert.are.equal(project_loader.ERROR_VALIDATION_ERROR, error_type)
    end)
  end)

  describe("file_exists", function()
    it("should return true for existing file", function()
      local exists =
        project_loader.file_exists("lua/dsl/examples/minimal-project.lua")

      assert.is_true(exists)
    end)

    it("should return false for non-existing file", function()
      local exists = project_loader.file_exists("/nonexistent/file.lua")

      assert.is_false(exists)
    end)

    it("should return false for nil path", function()
      local exists = project_loader.file_exists(nil)

      assert.is_false(exists)
    end)

    it("should return false for empty path", function()
      local exists = project_loader.file_exists("")

      assert.is_false(exists)
    end)
  end)

  describe("constants", function()
    it("should define error type constants", function()
      assert.is_not_nil(project_loader.ERROR_FILE_NOT_FOUND)
      assert.is_not_nil(project_loader.ERROR_PROJECT_NOT_FOUND)
      assert.is_not_nil(project_loader.ERROR_VALIDATION_ERROR)

      -- Ensure they are different
      assert.are_not.equal(
        project_loader.ERROR_FILE_NOT_FOUND,
        project_loader.ERROR_PROJECT_NOT_FOUND
      )
      assert.are_not.equal(
        project_loader.ERROR_FILE_NOT_FOUND,
        project_loader.ERROR_VALIDATION_ERROR
      )
      assert.are_not.equal(
        project_loader.ERROR_PROJECT_NOT_FOUND,
        project_loader.ERROR_VALIDATION_ERROR
      )
    end)
  end)
end)
