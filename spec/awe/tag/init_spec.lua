describe("awe.tag.init (deprecated)", function()
  local create_tag_modules

  before_each(function()
    create_tag_modules = require("awe.tag.init")
  end)

  describe("backward compatibility", function()
    it("should create empty tag modules for backward compatibility", function()
      local mock_interface = {
        get_current_tag = function()
          return 1
        end,
      }

      local tag_modules = create_tag_modules(mock_interface)

      assert.is_table(tag_modules)
      -- Resolver functionality has been moved to tag_mapper
      assert.is_nil(tag_modules.resolver)
    end)

    it("should work with different interface types", function()
      local awesome_interface = {}
      local dry_run_interface = {}
      local mock_interface = {}

      local awesome_tag = create_tag_modules(awesome_interface)
      local dry_run_tag = create_tag_modules(dry_run_interface)
      local mock_tag = create_tag_modules(mock_interface)

      -- All should return empty tables (deprecated module)
      assert.is_table(awesome_tag)
      assert.is_table(dry_run_tag)
      assert.is_table(mock_tag)
    end)
  end)

  describe("deprecation notice", function()
    it("should not crash when called", function()
      local mock_interface = {}
      local tag_modules = create_tag_modules(mock_interface)

      -- Should not error when creating - module exists for compatibility
      assert.is_table(tag_modules)
    end)
  end)
end)
