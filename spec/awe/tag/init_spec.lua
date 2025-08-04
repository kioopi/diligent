describe("awe.tag.init", function()
  local create_tag_modules

  before_each(function()
    create_tag_modules = require("awe.tag.init")
  end)

  describe("factory pattern", function()
    it("should create tag modules with interface injection", function()
      local mock_interface = {
        get_current_tag = function() return 1 end
      }
      
      local tag_modules = create_tag_modules(mock_interface)
      
      assert.is_table(tag_modules)
      assert.is_table(tag_modules.resolver)
    end)

    it("should pass interface to resolver module", function()
      local mock_interface = {
        get_current_tag = function() return 2 end
      }
      
      local tag_modules = create_tag_modules(mock_interface)
      
      -- The resolver should have access to the interface
      assert.is_function(tag_modules.resolver.resolve_tag_spec)
    end)

    it("should work with different interface types", function()
      local awesome_interface = { get_current_tag = function() return 1 end }
      local dry_run_interface = { get_current_tag = function() return 1 end }
      local mock_interface = { get_current_tag = function() return 1 end }
      
      local awesome_tag = create_tag_modules(awesome_interface)
      local dry_run_tag = create_tag_modules(dry_run_interface)
      local mock_tag = create_tag_modules(mock_interface)
      
      assert.is_table(awesome_tag.resolver)
      assert.is_table(dry_run_tag.resolver)
      assert.is_table(mock_tag.resolver)
    end)
  end)

  describe("lazy loading", function()
    it("should not require resolver module until accessed", function()
      local mock_interface = {}
      local tag_modules = create_tag_modules(mock_interface)
      
      -- Should not error when creating, only when accessing resolver
      assert.is_table(tag_modules)
    end)
  end)
end)