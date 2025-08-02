local assert = require("luassert")

-- Mock AwesomeWM functions for testing
local mock_awesome

-- Mock tag object
local function create_mock_tag(name, index, screen)
  return {
    name = name,
    index = index,
    screen = screen or mock_awesome.screen.focused(),
  }
end

-- Initialize mock AwesomeWM
local function init_mock_awesome()
  mock_awesome = {
    tags = {},
    screen = {
      focused = function()
        return {
          selected_tag = {
            index = 3, -- default to tag 3 for testing
          },
          tags = mock_awesome.tags,
        }
      end,
    },
  }
end

-- Reset mock state before each test
local function reset_mock_awesome()
  init_mock_awesome()
  mock_awesome.tags = {
    create_mock_tag("1", 1),
    create_mock_tag("2", 2),
    create_mock_tag("3", 3),
    create_mock_tag("4", 4),
    create_mock_tag("5", 5),
    create_mock_tag("6", 6),
    create_mock_tag("7", 7),
    create_mock_tag("8", 8),
    create_mock_tag("9", 9),
  }
end

describe("tag_mapper", function()
  local tag_mapper

  before_each(function()
    -- Clean module cache to get fresh instance
    package.loaded["tag_mapper"] = nil
    reset_mock_awesome()

    -- Mock AwesomeWM dependencies
    _G.awesome = mock_awesome
    _G.awful = {
      screen = mock_awesome.screen,
      tag = {
        find_by_name = function(name, screen)
          for _, tag in ipairs(screen.tags) do
            if tag.name == name then
              return tag
            end
          end
          return nil
        end,
        add = function(name, props)
          local screen = props.screen or mock_awesome.screen.focused()
          local new_tag = create_mock_tag(name, #screen.tags + 1, screen)
          table.insert(screen.tags, new_tag)
          return new_tag
        end,
      },
    }

    tag_mapper = require("tag_mapper")
  end)

  after_each(function()
    -- Clean up globals
    _G.awesome = nil
    _G.awful = nil
  end)

  describe("resolve_tag", function()
    it("should resolve relative offset 0 to current tag", function()
      -- Current tag is 3 (from mock), offset 0 should return tag 3
      local success, result = tag_mapper.resolve_tag(0, 3)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal(3, result.index)
    end)

    it("should resolve relative offset 1 to current tag + 1", function()
      -- Current tag is 3, offset 1 should return tag 4
      local success, result = tag_mapper.resolve_tag(1, 3)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal(4, result.index)
    end)

    it("should resolve relative offset 2 to current tag + 2", function()
      -- Current tag is 3, offset 2 should return tag 5
      local success, result = tag_mapper.resolve_tag(2, 3)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal(5, result.index)
    end)

    it("should handle overflow by placing on tag 9", function()
      -- Current tag is 8, offset 2 would be 10, should overflow to 9
      local success, result = tag_mapper.resolve_tag(2, 8)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal(9, result.index)
    end)

    it("should resolve digit string to absolute numeric tag", function()
      local success, result = tag_mapper.resolve_tag("5", 3)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal(5, result.index)
    end)

    it("should resolve digit string with overflow to tag 9", function()
      local success, result = tag_mapper.resolve_tag("15", 3)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal(9, result.index)
    end)

    it("should resolve named tag that exists", function()
      -- Add a named tag to our mock
      local editor_tag = create_mock_tag("editor", 10)
      table.insert(mock_awesome.tags, editor_tag)

      local success, result = tag_mapper.resolve_tag("editor", 3)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal("editor", result.name)
      assert.are.equal(10, result.index)
    end)

    it("should create named tag if it doesn't exist", function()
      local success, result = tag_mapper.resolve_tag("logs", 3)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal("logs", result.name)
    end)

    it("should handle negative offsets by using tag 1", function()
      local success, result = tag_mapper.resolve_tag(-2, 1)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal(1, result.index)
    end)

    it("should handle nil tag spec", function()
      local success, result = tag_mapper.resolve_tag(nil, 3)

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("tag spec is required", result)
    end)

    it("should handle invalid base tag", function()
      local success, result = tag_mapper.resolve_tag(0, nil)

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("base tag is required", result)
    end)

    it("should handle invalid base tag type", function()
      local success, result = tag_mapper.resolve_tag(0, "not a number")

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("base tag must be a number", result)
    end)
  end)

  describe("create_project_tag", function()
    it("should create project tag with given name", function()
      local success, result = tag_mapper.create_project_tag("test-project")

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal("test-project", result.name)
    end)

    it("should not create duplicate project tag", function()
      -- Create first project tag
      local success1, result1 =
        tag_mapper.create_project_tag("existing-project")
      assert.is_true(success1)

      -- Try to create same project tag again - should return existing one
      local success2, result2 =
        tag_mapper.create_project_tag("existing-project")
      assert.is_true(success2)
      assert.are.equal(result1.name, result2.name)
    end)

    it("should handle empty project name", function()
      local success, result = tag_mapper.create_project_tag("")

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("project name is required", result)
    end)

    it("should handle nil project name", function()
      local success, result = tag_mapper.create_project_tag(nil)

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("project name is required", result)
    end)

    it("should handle non-string project name", function()
      local success, result = tag_mapper.create_project_tag(123)

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("project name must be a string", result)
    end)
  end)

  describe("get_current_tag", function()
    it("should return current selected tag index", function()
      local result = tag_mapper.get_current_tag()

      assert.are.equal(3, result) -- from mock
    end)

    it("should handle missing screen", function()
      -- Mock no focused screen
      mock_awesome.screen.focused = function()
        return nil
      end

      local result = tag_mapper.get_current_tag()

      assert.are.equal(1, result) -- fallback to tag 1
    end)

    it("should handle missing selected tag", function()
      -- Mock screen with no selected tag
      mock_awesome.screen.focused = function()
        return { selected_tag = nil, tags = mock_awesome.tags }
      end

      local result = tag_mapper.get_current_tag()

      assert.are.equal(1, result) -- fallback to tag 1
    end)
  end)

  describe("integration tests", function()
    it("should resolve multiple tag specs correctly", function()
      local base_tag = 2
      local tag_specs = {
        { spec = 0, expected_index = 2 }, -- relative: current
        { spec = 1, expected_index = 3 }, -- relative: current + 1
        { spec = "5", expected_index = 5 }, -- absolute: tag 5
        { spec = "editor", expected_name = "editor" }, -- named tag
      }

      for _, test_case in ipairs(tag_specs) do
        local success, result = tag_mapper.resolve_tag(test_case.spec, base_tag)

        assert.is_true(success)
        assert.is_table(result)

        if test_case.expected_index then
          assert.are.equal(test_case.expected_index, result.index)
        end

        if test_case.expected_name then
          assert.are.equal(test_case.expected_name, result.name)
        end
      end
    end)

    it("should handle edge cases for overflow", function()
      local test_cases = {
        { base = 8, offset = 2, expected = 9 }, -- 8 + 2 = 10 -> 9
        { base = 9, offset = 1, expected = 9 }, -- 9 + 1 = 10 -> 9
        { base = 7, offset = 5, expected = 9 }, -- 7 + 5 = 12 -> 9
      }

      for _, test_case in ipairs(test_cases) do
        local success, result =
          tag_mapper.resolve_tag(test_case.offset, test_case.base)

        assert.is_true(success)
        assert.is_table(result)
        assert.are.equal(test_case.expected, result.index)
      end
    end)
  end)
end)
