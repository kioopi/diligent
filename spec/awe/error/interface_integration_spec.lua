local assert = require("luassert")

describe("awe.error interface integration", function()
  local awe

  setup(function() _G._TEST = true end)
  teardown(function() _G._TEST = nil end)

  before_each(function()
    -- Clear module cache
    package.loaded["awe"] = nil
    package.loaded["awe.error.init"] = nil

    awe = require("awe")
  end)

  describe("error module integration with interfaces", function()
    it("should work with awesome_interface", function()
      local error_handler = awe.create(awe.interfaces.awesome_interface).error

      assert.is_not_nil(error_handler)
      assert.is_function(error_handler.classifier.classify_error)
      assert.is_function(error_handler.reporter.create_error_report)
      assert.is_function(error_handler.formatter.format_error_for_user)
    end)

    it("should work with mock_interface", function()
      local error_handler = awe.create(awe.interfaces.mock_interface).error

      assert.is_not_nil(error_handler)
      assert.is_function(error_handler.classifier.classify_error)
      assert.is_function(error_handler.reporter.create_error_report)
      assert.is_function(error_handler.formatter.format_error_for_user)
    end)

    it("should work with dry_run_interface", function()
      local error_handler = awe.create(awe.interfaces.dry_run_interface).error

      assert.is_not_nil(error_handler)
      assert.is_function(error_handler.classifier.classify_error)
      assert.is_function(error_handler.reporter.create_error_report)
      assert.is_function(error_handler.formatter.format_error_for_user)
    end)

    it(
      "should create independent error handlers for different interfaces",
      function()
        local awesome_handler =
          awe.create(awe.interfaces.awesome_interface).error
        local mock_handler = awe.create(awe.interfaces.mock_interface).error

        -- Handlers should be independent instances
        assert.is_not.equal(awesome_handler, mock_handler)
        assert.is_not.equal(awesome_handler.classifier, mock_handler.classifier)
      end
    )
  end)
end)
