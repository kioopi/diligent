local assert = require("luassert")

describe("awe.interfaces.mock_interface", function()
  local mock_interface

  before_each(function()
    -- Clean module cache to get fresh instance
    package.loaded["awe.interfaces.mock_interface"] = nil
    mock_interface = require("awe").interfaces.mock_interface
  end)

  describe("get_screen_context", function()
    it("should return mock screen context", function()
      local context = mock_interface.get_screen_context()

      assert.is_table(context)
      assert.is_table(context.screen)
      assert.is_number(context.current_tag_index)
      assert.is_table(context.available_tags)
      assert.is_number(context.tag_count)

      -- Should have reasonable mock defaults
      assert.is_truthy(context.current_tag_index >= 1)
      assert.is_truthy(context.tag_count >= 1)
    end)

    it("should be deterministic for testing", function()
      local context1 = mock_interface.get_screen_context()
      local context2 = mock_interface.get_screen_context()

      -- Should return consistent values for testing
      assert.are.equal(context1.current_tag_index, context2.current_tag_index)
      assert.are.equal(context1.tag_count, context2.tag_count)
    end)
  end)

  describe("find_tag_by_name", function()
    it("should find predefined test tag", function()
      local tag = mock_interface.find_tag_by_name("test")

      assert.is_table(tag)
      assert.are.equal("test", tag.name)
      assert.is_number(tag.index)
    end)

    it("should return nil for unknown tags", function()
      local tag = mock_interface.find_tag_by_name("unknown")

      assert.is_nil(tag)
    end)

    it("should handle nil and empty tag names", function()
      assert.is_nil(mock_interface.find_tag_by_name(nil))
      assert.is_nil(mock_interface.find_tag_by_name(""))
    end)
  end)

  describe("create_named_tag", function()
    it("should create mock tag with given name", function()
      local tag = mock_interface.create_named_tag("new-tag")

      assert.is_table(tag)
      assert.are.equal("new-tag", tag.name)
      assert.is_number(tag.index)
    end)

    it("should handle invalid tag names", function()
      local tag1 = mock_interface.create_named_tag("")
      local tag2 = mock_interface.create_named_tag(nil)

      -- Should handle gracefully (return nil or reasonable default)
      -- Implementation can decide the exact behavior
      assert.is_truthy(tag1 == nil or type(tag1) == "table")
      assert.is_truthy(tag2 == nil or type(tag2) == "table")
    end)

    it("should provide consistent mock behavior", function()
      local tag1 = mock_interface.create_named_tag("consistent")
      local tag2 = mock_interface.create_named_tag("consistent")

      -- Mock should behave consistently
      assert.is_table(tag1)
      assert.is_table(tag2)
      assert.are.equal(tag1.name, tag2.name)
    end)
  end)

  describe("interface contract compatibility", function()
    it("should implement same basic interface as other interfaces", function()
      -- Core interface functions should exist
      assert.is_function(mock_interface.get_screen_context)
      assert.is_function(mock_interface.find_tag_by_name)
      assert.is_function(mock_interface.create_named_tag)
    end)

    it("should provide mock-appropriate responses", function()
      -- All functions should return reasonable mock data
      local context = mock_interface.get_screen_context()
      local found_tag = mock_interface.find_tag_by_name("test")
      local created_tag = mock_interface.create_named_tag("mock-tag")

      assert.is_table(context)
      assert.is_table(found_tag)
      assert.is_table(created_tag)
    end)
  end)
end)
