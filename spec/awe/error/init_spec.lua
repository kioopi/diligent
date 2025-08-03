local assert = require("luassert")

describe("awe.error.init", function()
  local error_factory

  before_each(function()
    -- Clear module cache to ensure clean state
    package.loaded["awe.error.init"] = nil
    package.loaded["awe.error.classifier"] = nil
    package.loaded["awe.error.reporter"] = nil
    package.loaded["awe.error.formatter"] = nil
  end)

  describe("factory pattern", function()
    it("should create error handler with default interface", function()
      error_factory = require("awe.error.init")
      local error_handler = error_factory.create()

      assert.is_not_nil(error_handler)
      assert.is_not_nil(error_handler.classifier)
      assert.is_not_nil(error_handler.reporter)
      assert.is_not_nil(error_handler.formatter)
    end)

    it("should create error handler with custom interface", function()
      local mock_interface = {
        type = "mock",
      }

      error_factory = require("awe.error.init")
      local error_handler = error_factory.create(mock_interface)

      assert.is_not_nil(error_handler)
      assert.is_not_nil(error_handler.classifier)
      assert.is_not_nil(error_handler.reporter)
      assert.is_not_nil(error_handler.formatter)
    end)

    it("should pass interface to all sub-modules", function()
      local mock_interface = {
        type = "test_interface",
      }

      error_factory = require("awe.error.init")
      local error_handler = error_factory.create(mock_interface)

      -- This test will verify that the interface is properly injected
      -- when we implement the actual modules
      assert.is_not_nil(error_handler.classifier)
      assert.is_not_nil(error_handler.reporter)
      assert.is_not_nil(error_handler.formatter)
    end)

    it("should create independent instances", function()
      local interface1 = { type = "interface1" }
      local interface2 = { type = "interface2" }

      error_factory = require("awe.error.init")
      local handler1 = error_factory.create(interface1)
      local handler2 = error_factory.create(interface2)

      -- Instances should be independent
      assert.is_not.equal(handler1, handler2)
      assert.is_not.equal(handler1.classifier, handler2.classifier)
    end)

    it("should handle nil interface gracefully", function()
      error_factory = require("awe.error.init")

      assert.has_no.errors(function()
        local error_handler = error_factory.create(nil)
        assert.is_not_nil(error_handler)
      end)
    end)

    it("should expose all required error handling modules", function()
      error_factory = require("awe.error.init")
      local error_handler = error_factory.create()

      -- Verify all expected modules are present
      assert.is_function(error_handler.classifier.classify_error)
      assert.is_function(error_handler.reporter.create_error_report)
      assert.is_function(error_handler.formatter.format_error_for_user)
    end)
  end)
end)
