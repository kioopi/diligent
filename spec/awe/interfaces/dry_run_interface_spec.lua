local assert = require("luassert")

describe("awe.interfaces.dry_run_interface", function()
  local dry_run_interface

  setup(function() _G._TEST = true end)
  teardown(function() _G._TEST = nil end)

  before_each(function()
    -- Clean module cache to get fresh instance
    package.loaded["awe.interfaces.dry_run_interface"] = nil
    dry_run_interface = require("awe").interfaces.dry_run_interface

    -- Clear execution log for test isolation
    dry_run_interface.clear_execution_log()
  end)

  describe("get_screen_context", function()
    it("should return simulated screen context", function()
      local context = dry_run_interface.get_screen_context()

      assert.is_table(context)
      assert.is_not_nil(context.screen)
      assert.is_number(context.current_tag_index)
      assert.is_table(context.available_tags)
      assert.is_number(context.tag_count)

      -- Should have reasonable defaults
      assert.are.equal(1, context.current_tag_index)
      assert.are.equal(9, context.tag_count)
    end)

    it("should handle custom screen parameter", function()
      local custom_screen = {
        name = "test_screen",
        selected_tag = { index = 5 },
        tags = { { name = "1", index = 1 }, { name = "2", index = 2 } },
      }

      local context = dry_run_interface.get_screen_context(custom_screen)

      assert.is_table(context)
      assert.are.equal(custom_screen, context.screen)
      assert.are.equal(5, context.current_tag_index)
      assert.are.equal(2, context.tag_count)
    end)

    it("should not error on missing screen", function()
      local context = dry_run_interface.get_screen_context(nil)

      assert.is_table(context)
      assert.is_not_nil(context.screen)
      -- Should provide fallback defaults
    end)
  end)

  describe("find_tag_by_name", function()
    it("should simulate finding existing tag", function()
      -- First simulate creating a tag so it can be found
      local created_tag = dry_run_interface.create_named_tag("editor")

      local found_tag = dry_run_interface.find_tag_by_name("editor")

      assert.is_table(found_tag)
      assert.are.equal("editor", found_tag.name)
    end)

    it("should return nil for non-existent tag", function()
      local tag = dry_run_interface.find_tag_by_name("nonexistent")

      assert.is_nil(tag)
    end)

    it("should handle empty or nil tag name", function()
      assert.is_nil(dry_run_interface.find_tag_by_name(""))
      assert.is_nil(dry_run_interface.find_tag_by_name(nil))
    end)
  end)

  describe("create_named_tag", function()
    it("should simulate creating new named tag", function()
      local tag = dry_run_interface.create_named_tag("new-project")

      assert.is_table(tag)
      assert.are.equal("new-project", tag.name)
      assert.is_not_nil(tag.index) -- Should assign a simulated index
    end)

    it("should track created tags for later finding", function()
      dry_run_interface.create_named_tag("trackable")

      local found_tag = dry_run_interface.find_tag_by_name("trackable")

      assert.is_table(found_tag)
      assert.are.equal("trackable", found_tag.name)
    end)

    it("should handle duplicate tag creation", function()
      dry_run_interface.create_named_tag("duplicate")
      local tag2 = dry_run_interface.create_named_tag("duplicate")

      -- Should return existing tag instead of creating new one
      assert.is_table(tag2)
      assert.are.equal("duplicate", tag2.name)
    end)

    it("should handle invalid tag name", function()
      local tag1 = dry_run_interface.create_named_tag("")
      local tag2 = dry_run_interface.create_named_tag(nil)

      assert.is_nil(tag1)
      assert.is_nil(tag2)
    end)
  end)

  describe("get_execution_log", function()
    it("should return empty log initially", function()
      local log = dry_run_interface.get_execution_log()

      assert.is_table(log)
      assert.are.equal(0, #log)
    end)

    it("should record tag creation operations", function()
      dry_run_interface.create_named_tag("logged-project")

      local log = dry_run_interface.get_execution_log()

      assert.is_table(log)
      assert.are.equal(1, #log)
      assert.are.equal("create_tag", log[1].operation)
      assert.are.equal("logged-project", log[1].tag_name)
    end)

    it("should record tag lookup operations", function()
      dry_run_interface.find_tag_by_name("search-target")

      local log = dry_run_interface.get_execution_log()

      assert.is_table(log)
      assert.are.equal(1, #log)
      assert.are.equal("find_tag", log[1].operation)
      assert.are.equal("search-target", log[1].tag_name)
    end)

    it("should accumulate multiple operations", function()
      dry_run_interface.create_named_tag("project1")
      dry_run_interface.create_named_tag("project2")
      dry_run_interface.find_tag_by_name("project1")

      local log = dry_run_interface.get_execution_log()

      assert.are.equal(3, #log)
    end)
  end)

  describe("clear_execution_log", function()
    it("should clear the execution log", function()
      dry_run_interface.create_named_tag("to-be-cleared")

      -- Verify log has entries
      local log_before = dry_run_interface.get_execution_log()
      assert.are.equal(1, #log_before)

      -- Clear and verify empty
      dry_run_interface.clear_execution_log()
      local log_after = dry_run_interface.get_execution_log()
      assert.are.equal(0, #log_after)
    end)
  end)

  describe("interface contract compatibility", function()
    it("should implement same interface as awesome_interface", function()
      -- These functions should exist and be callable
      assert.is_function(dry_run_interface.get_screen_context)
      assert.is_function(dry_run_interface.find_tag_by_name)
      assert.is_function(dry_run_interface.create_named_tag)

      -- Additional dry-run specific functions
      assert.is_function(dry_run_interface.get_execution_log)
      assert.is_function(dry_run_interface.clear_execution_log)
    end)
  end)
end)
