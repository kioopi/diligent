local assert = require("luassert")

describe("diligent.error.classifier", function()
  local classifier

  before_each(function()
    package.loaded["diligent.error.classifier"] = nil
    local classifier_factory = require("diligent.error.classifier")
    classifier = classifier_factory.create()
  end)

  describe("ERROR_TYPES constants", function()
    it("should include all original error types", function()
      local ERROR_TYPES = classifier.ERROR_TYPES
      
      assert.are.equal("COMMAND_NOT_FOUND", ERROR_TYPES.COMMAND_NOT_FOUND)
      assert.are.equal("PERMISSION_DENIED", ERROR_TYPES.PERMISSION_DENIED)
      assert.are.equal("INVALID_COMMAND", ERROR_TYPES.INVALID_COMMAND)
      assert.are.equal("TIMEOUT", ERROR_TYPES.TIMEOUT)
      assert.are.equal("TAG_RESOLUTION_FAILED", ERROR_TYPES.TAG_RESOLUTION_FAILED)
    end)

    it("should include new tag resolution error types", function()
      local ERROR_TYPES = classifier.ERROR_TYPES
      
      assert.are.equal("TAG_SPEC_INVALID", ERROR_TYPES.TAG_SPEC_INVALID)
      assert.are.equal("TAG_OVERFLOW", ERROR_TYPES.TAG_OVERFLOW)
      assert.are.equal("TAG_NAME_INVALID", ERROR_TYPES.TAG_NAME_INVALID)
      assert.are.equal("MULTIPLE_TAG_ERRORS", ERROR_TYPES.MULTIPLE_TAG_ERRORS)
    end)
  end)

  describe("tag overflow classification", function()
    it("should detect tag overflow errors", function()
      local test_cases = {
        "Tag overflow: resolved index 11 exceeds maximum 9",
        "tag overflow detected: 15 -> 9",
        "Tag index overflow: capped at 9"
      }

      for _, message in ipairs(test_cases) do
        local error_type, user_message = classifier.classify_error(message)
        assert.are.equal(classifier.ERROR_TYPES.TAG_OVERFLOW, error_type, 
          "Failed to classify: " .. message)
        assert.matches("overflow", user_message:lower())
      end
    end)
  end)

  describe("tag spec validation classification", function()
    it("should detect invalid tag specifications", function()
      local test_cases = {
        "Invalid tag specification: must be number or string",
        "tag spec is invalid: got boolean",
        "Invalid tag spec type: table"
      }

      for _, message in ipairs(test_cases) do
        local error_type, user_message = classifier.classify_error(message)
        assert.are.equal(classifier.ERROR_TYPES.TAG_SPEC_INVALID, error_type,
          "Failed to classify: " .. message)
        assert.matches("specification", user_message:lower())
      end
    end)
  end)

  describe("tag name validation classification", function()
    it("should detect invalid tag names", function()
      local test_cases = {
        "Invalid tag name format: must start with letter",
        "tag name validation failed: empty string",
        "Invalid tag name: contains invalid characters"
      }

      for _, message in ipairs(test_cases) do
        local error_type, user_message = classifier.classify_error(message)
        assert.are.equal(classifier.ERROR_TYPES.TAG_NAME_INVALID, error_type,
          "Failed to classify: " .. message)
        assert.matches("name", user_message:lower())
      end
    end)
  end)

  describe("multiple errors classification", function()
    it("should detect aggregated error messages", function()
      local test_cases = {
        "Multiple tag resolution errors: 3 resources failed",
        "2 errors occurred during tag processing",
        "Multiple errors in tag resolution"
      }

      for _, message in ipairs(test_cases) do
        local error_type, user_message = classifier.classify_error(message)
        assert.are.equal(classifier.ERROR_TYPES.MULTIPLE_TAG_ERRORS, error_type,
          "Failed to classify: " .. message)
        assert.matches("multiple", user_message:lower())
      end
    end)
  end)

  describe("fallback classification", function()
    it("should handle unknown tag resolution errors", function()
      local error_type, user_message = classifier.classify_error(
        "Some unknown tag resolution problem"
      )
      
      -- Should classify as general tag resolution failure
      assert.are.equal(classifier.ERROR_TYPES.TAG_RESOLUTION_FAILED, error_type)
      assert.matches("tag", user_message:lower())
    end)
  end)
end)