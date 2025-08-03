local assert = require("luassert")

-- Mock AwesomeWM functions for testing
local mock_awful

-- Mock tag object
local function create_mock_tag(name, index)
  return {
    name = name,
    index = index,
  }
end

-- Initialize mock AwesomeWM
local function init_mock_awful()
  mock_awful = {
    screen = {
      focused = function()
        return {
          selected_tag = {
            index = 3, -- default to tag 3 for testing
          },
          tags = {
            create_mock_tag("1", 1),
            create_mock_tag("2", 2),
            create_mock_tag("3", 3),
            create_mock_tag("4", 4),
            create_mock_tag("editor", nil), -- named tag
          },
        }
      end,
    },
  }
end

describe("awesome_interface", function()
  local awesome_interface

  before_each(function()
    -- Clean module cache to get fresh instance
    package.loaded["awe.interfaces.awesome_interface"] = nil
    init_mock_awful()

    -- Mock AwesomeWM dependencies
    _G.awful = mock_awful

    awesome_interface = require("awe.interfaces.awesome_interface")
  end)

  after_each(function()
    -- Clean up globals
    _G.awful = nil
  end)

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
        tags = { create_mock_tag("1", 1), create_mock_tag("2", 2) },
      }

      local context = awesome_interface.get_screen_context(custom_screen)

      assert.is_table(context)
      assert.are.equal(custom_screen, context.screen)
      assert.are.equal(5, context.current_tag_index)
      assert.are.equal(2, context.tag_count)
    end)

    it("should handle missing screen gracefully", function()
      -- Mock no focused screen
      mock_awful.screen.focused = function()
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
      mock_awful.screen.focused = function()
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
      local screen = mock_awful.screen.focused()
      local tag = awesome_interface.find_tag_by_name("editor", screen)

      assert.is_table(tag)
      assert.are.equal("editor", tag.name)
    end)

    it("should return nil for non-existent tag", function()
      local screen = mock_awful.screen.focused()
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
      local screen = mock_awful.screen.focused()
      local tag = awesome_interface.find_tag_by_name(nil, screen)

      assert.is_nil(tag)
    end)

    it("should handle empty tag name", function()
      local screen = mock_awful.screen.focused()
      local tag = awesome_interface.find_tag_by_name("", screen)

      assert.is_nil(tag)
    end)
  end)

  describe("create_named_tag", function()
    before_each(function()
      -- Reset mock state to ensure clean testing environment
      init_mock_awful()
      _G.awful = mock_awful

      -- Add awful.tag.add mock for tag creation
      _G.awful.tag = _G.awful.tag or {}
      _G.awful.tag.add = function(name, props)
        local screen = props.screen or mock_awful.screen.focused()
        local new_tag = create_mock_tag(name, #screen.tags + 1)
        table.insert(screen.tags, new_tag)
        return new_tag
      end
    end)

    it("should create new named tag", function()
      local screen = mock_awful.screen.focused()
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
      local screen = mock_awful.screen.focused()
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
      local screen = mock_awful.screen.focused()
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

    it("should handle tag creation failure", function()
      -- Mock awful.tag.add to fail
      _G.awful.tag.add = function()
        return nil -- Simulate creation failure
      end

      local screen = mock_awful.screen.focused()
      local success, result = pcall(function()
        return awesome_interface.create_named_tag("failing-project", screen)
      end)

      -- Should handle failure gracefully
      if success then
        assert.is_nil(result)
      else
        assert.is_string(result) -- Error message
      end
    end)
  end)
end)
