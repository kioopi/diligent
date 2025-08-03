local assert = require("luassert")

describe("awe.error.classifier", function()
  local classifier_factory, classifier

  before_each(function()
    -- Clear module cache
    package.loaded["awe.error.classifier"] = nil

    classifier_factory = require("awe.error.classifier")
    classifier = classifier_factory.create()
  end)

  describe("factory pattern", function()
    it("should create classifier with default interface", function()
      assert.is_not_nil(classifier)
      assert.is_function(classifier.classify_error)
    end)

    it("should create classifier with custom interface", function()
      local mock_interface = { type = "mock" }
      local custom_classifier = classifier_factory.create(mock_interface)

      assert.is_not_nil(custom_classifier)
      assert.is_function(custom_classifier.classify_error)
    end)
  end)

  describe("ERROR_TYPES constants", function()
    it("should expose all error type constants", function()
      assert.is_string(classifier.ERROR_TYPES.COMMAND_NOT_FOUND)
      assert.is_string(classifier.ERROR_TYPES.PERMISSION_DENIED)
      assert.is_string(classifier.ERROR_TYPES.INVALID_COMMAND)
      assert.is_string(classifier.ERROR_TYPES.TIMEOUT)
      assert.is_string(classifier.ERROR_TYPES.DEPENDENCY_FAILED)
      assert.is_string(classifier.ERROR_TYPES.TAG_RESOLUTION_FAILED)
      assert.is_string(classifier.ERROR_TYPES.UNKNOWN)
    end)

    it("should have unique error type values", function()
      local error_types = classifier.ERROR_TYPES
      local values = {}

      for _, value in pairs(error_types) do
        assert.is_nil(values[value], "Duplicate error type: " .. value)
        values[value] = true
      end
    end)
  end)

  describe("classify_error function", function()
    it("should classify command not found errors", function()
      local error_type, user_message =
        classifier.classify_error("No such file or directory")

      assert.equals(classifier.ERROR_TYPES.COMMAND_NOT_FOUND, error_type)
      assert.equals("Command not found in PATH", user_message)
    end)

    it("should classify permission denied errors", function()
      local error_type, user_message =
        classifier.classify_error("Permission denied")

      assert.equals(classifier.ERROR_TYPES.PERMISSION_DENIED, error_type)
      assert.equals("Insufficient permissions to execute", user_message)
    end)

    it("should classify invalid command errors", function()
      local error_type, user_message =
        classifier.classify_error("no command to execute")

      assert.equals(classifier.ERROR_TYPES.INVALID_COMMAND, error_type)
      assert.equals("Empty or invalid command", user_message)
    end)

    it("should classify empty string as invalid command", function()
      local error_type, user_message = classifier.classify_error("   ")

      assert.equals(classifier.ERROR_TYPES.INVALID_COMMAND, error_type)
      assert.equals("Empty or invalid command", user_message)
    end)

    it("should classify timeout errors", function()
      local error_type, user_message =
        classifier.classify_error("Operation timeout occurred")

      assert.equals(classifier.ERROR_TYPES.TIMEOUT, error_type)
      assert.equals("Operation timed out", user_message)
    end)

    it("should classify tag resolution errors", function()
      local error_type, user_message =
        classifier.classify_error("Tag resolution failed: invalid spec")

      assert.equals(classifier.ERROR_TYPES.TAG_RESOLUTION_FAILED, error_type)
      assert.equals("Could not resolve tag specification", user_message)
    end)

    it("should classify unknown errors", function()
      local error_type, user_message =
        classifier.classify_error("Some unknown error message")

      assert.equals(classifier.ERROR_TYPES.UNKNOWN, error_type)
      assert.matches("Unclassified error:", user_message)
    end)

    it("should handle nil error message", function()
      local error_type, user_message = classifier.classify_error(nil)

      assert.equals(classifier.ERROR_TYPES.UNKNOWN, error_type)
      assert.equals("No error message provided", user_message)
    end)

    it("should handle non-string error message", function()
      local error_type, user_message = classifier.classify_error(123)

      assert.equals(classifier.ERROR_TYPES.UNKNOWN, error_type)
      assert.equals("No error message provided", user_message)
    end)

    it("should be case insensitive for classification", function()
      local error_type1 = classifier.classify_error("PERMISSION DENIED")
      local error_type2 = classifier.classify_error("permission denied")
      local error_type3 = classifier.classify_error("Permission Denied")

      assert.equals(error_type1, error_type2)
      assert.equals(error_type2, error_type3)
      assert.equals(classifier.ERROR_TYPES.PERMISSION_DENIED, error_type1)
    end)

    it("should handle partial matches in error messages", function()
      local error_type = classifier.classify_error(
        "Failed to spawn: no such file or directory: /usr/bin/nonexistent"
      )

      assert.equals(classifier.ERROR_TYPES.COMMAND_NOT_FOUND, error_type)
    end)
  end)
end)
