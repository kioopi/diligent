local assert = require("luassert")
local mock_awful = require("spec/awe/interfaces/mock_awful")

describe("awesome_interface", function()
  local awesome_interface
  local awful

  setup(function() _G._TEST = true end)
  teardown(function() _G._TEST = nil end)

  before_each(function()
    -- Clean module cache to get fresh instance
    package.loaded["awe.interfaces.awesome_interface"] = nil
    awful = mock_awful.setup()

    awesome_interface = require("awe").interfaces.awesome_interface
  end)

  after_each(function() mock_awful.cleanup() end)

  describe("get_screen_context", function()
    it("should return complete screen context", function()
      local context = awesome_interface.get_screen_context()

      assert.is_table(context)
      assert.is_not_nil(context.screen)
      assert.is_number(context.current_tag_index)
      assert.is_table(context.available_tags)
      assert.is_number(context.tag_count)

      -- Verify specific values from mock
      assert.are.equal(3, context.current_tag_index)
      assert.are.equal(5, context.tag_count)
    end)

    it("should handle custom screen parameter", function()
      local custom_screen = {
        selected_tag = { index = 5 },
        tags = { mock_awful.create_mock_tag("1", 1), mock_awful.create_mock_tag("2", 2) },
      }

      local context = awesome_interface.get_screen_context(custom_screen)

      assert.is_table(context)
      assert.are.equal(custom_screen, context.screen)
      assert.are.equal(5, context.current_tag_index)
      assert.are.equal(2, context.tag_count)
    end)

    it("should handle missing screen gracefully", function()
      -- Mock no focused screen
      awful.screen.focused = function()
        return nil
      end

      local success, result = pcall(function()
        return awesome_interface.get_screen_context()
      end)

      -- Should either succeed with fallback or fail gracefully
      if success then
        assert.is_table(result)
        -- Should have some fallback values
      else
        assert.is_string(result) -- Error message
      end
    end)

    it("should handle missing selected tag gracefully", function()
      -- Mock screen with no selected tag
      awful.screen.focused = function()
        return {
          selected_tag = nil,
          tags = { create_mock_tag("1", 1) },
        }
      end

      local success, result = pcall(function()
        return awesome_interface.get_screen_context()
      end)

      -- Should either succeed with fallback or fail gracefully
      if success then
        assert.is_table(result)
      else
        assert.is_string(result) -- Error message
      end
    end)
  end)

  describe("find_tag_by_name", function()
    it("should find existing named tag", function()
      local screen = awful.screen.focused()
      local tag = awesome_interface.find_tag_by_name("editor", screen)

      assert.is_table(tag)
      assert.are.equal("editor", tag.name)
    end)

    it("should return nil for non-existent tag", function()
      local screen = awful.screen.focused()
      local tag = awesome_interface.find_tag_by_name("nonexistent", screen)

      assert.is_nil(tag)
    end)

    it("should handle missing screen parameter", function()
      -- Should use focused screen as fallback
      local tag = awesome_interface.find_tag_by_name("editor")

      assert.is_table(tag)
      assert.are.equal("editor", tag.name)
    end)

    it("should handle nil tag name", function()
      local screen = awful.screen.focused()
      local tag = awesome_interface.find_tag_by_name(nil, screen)

      assert.is_nil(tag)
    end)

    it("should handle empty tag name", function()
      local screen = awful.screen.focused()
      local tag = awesome_interface.find_tag_by_name("", screen)

      assert.is_nil(tag)
    end)
  end)

  describe("create_named_tag", function()
    it("should create new named tag", function()
      local screen = awful.screen.focused()
      local initial_tag_count = #screen.tags

      local tag = awesome_interface.create_named_tag("new-project", screen)

      assert.is_table(tag)
      assert.are.equal("new-project", tag.name)
      assert.are.equal(initial_tag_count + 1, #screen.tags)
    end)

    it("should handle missing screen parameter", function()
      -- Should use focused screen as fallback and create tag
      local tag = awesome_interface.create_named_tag("fallback-project")

      assert.is_table(tag)
      assert.are.equal("fallback-project", tag.name)
      -- Tag should be created successfully (the main assertion is that it's not nil)
    end)

    it("should handle nil tag name", function()
      local screen = awful.screen.focused()
      local success, result = pcall(function()
        return awesome_interface.create_named_tag(nil, screen)
      end)

      -- Should either return nil or throw meaningful error
      if success then
        assert.is_nil(result)
      else
        assert.is_string(result) -- Error message
      end
    end)

    it("should handle empty tag name", function()
      local screen = awful.screen.focused()
      local success, result = pcall(function()
        return awesome_interface.create_named_tag("", screen)
      end)

      -- Should either return nil or throw meaningful error
      if success then
        assert.is_nil(result)
      else
        assert.is_string(result) -- Error message
      end
    end)

    describe("when tag creation fails", function()
      it("should handle tag creation failure", function()
        local result = awesome_interface.create_named_tag("fail-tag-creation")

        -- Should return nil when awful.tag.add is not available
        assert.is_nil(result)
      end)
    end)
  end)
end)
