local assert = require("luassert")

local tag_mapper = require("tag_mapper")

describe("tag_mapper", function()
  local mock_interface

  setup(function()
    _G._TEST = true
  end)
  teardown(function()
    _G._TEST = nil
  end)

  before_each(function()
    -- Clean module cache to get fresh instance
    package.loaded["tag_mapper"] = nil

    mock_interface = require("awe").interfaces.mock_interface
  end)

  after_each(function()
    mock_interface.reset()
  end)

  describe("resolve_tag", function()
    it("should resolve relative offset 0 to current tag", function()
      -- Current tag is 3 (from mock), offset 0 should return tag 3
      local success, result = tag_mapper.resolve_tag(0, 3, mock_interface)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal(3, result.index)
    end)

    it("should resolve relative offset 1 to current tag + 1", function()
      -- Current tag is 3, offset 1 should return tag 4
      local success, result = tag_mapper.resolve_tag(1, 3, mock_interface)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal(4, result.index)
    end)

    it("should resolve relative offset 2 to current tag + 2", function()
      -- Current tag is 3, offset 2 should return tag 5
      local success, result = tag_mapper.resolve_tag(2, 3, mock_interface)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal(5, result.index)
    end)

    it(
      "should resolve relative tags from current tag (bug fix verification)",
      function()
        -- BUG FIX TEST: User on tag 2 + offset 2 = tag 4 (not tag 3)
        -- This verifies the fix where relative tags resolve from user's current tag,
        -- not hardcoded tag 1 as in the original bug
        local success, result = tag_mapper.resolve_tag(2, 2, mock_interface)

        assert.is_true(success)
        assert.is_table(result)
        assert.are.equal(4, result.index)
        assert.are.equal("4", result.name)
      end
    )

    it("should handle different base tag scenarios", function()
      -- Additional verification with different starting positions

      -- User on tag 1 + offset 3 = tag 4
      local success1, result1 = tag_mapper.resolve_tag(3, 1, mock_interface)
      assert.is_true(success1)
      assert.are.equal(4, result1.index)

      -- User on tag 5 + offset 1 = tag 6
      local success2, result2 = tag_mapper.resolve_tag(1, 5, mock_interface)
      assert.is_true(success2)
      assert.are.equal(6, result2.index)
    end)

    it("should handle overflow by placing on tag 9", function()
      -- Current tag is 8, offset 2 would be 10, should overflow to 9
      local success, result = tag_mapper.resolve_tag(2, 8, mock_interface)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal(9, result.index)
    end)

    it("should resolve digit string to absolute numeric tag", function()
      local success, result = tag_mapper.resolve_tag("5", 3, mock_interface)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal(5, result.index)
    end)

    it("should resolve digit string with overflow to tag 9", function()
      local success, result = tag_mapper.resolve_tag("15", 3, mock_interface)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal(9, result.index)
    end)

    it("should resolve named tag that exists", function()
      -- Use a tag that exists in mock_interface ("test" has index 2)
      local success, result = tag_mapper.resolve_tag("test", 3, mock_interface)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal("test", result.name)
      assert.are.equal(2, result.index)
    end)

    it("should create named tag if it doesn't exist", function()
      local success, result = tag_mapper.resolve_tag("logs", 3, mock_interface)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal("logs", result.name)
    end)

    it("should handle negative offsets by using tag 1", function()
      local success, result = tag_mapper.resolve_tag(-2, 1, mock_interface)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal(1, result.index)
    end)

    it("should handle nil tag spec", function()
      local success, result = tag_mapper.resolve_tag(nil, 3, mock_interface)

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("tag spec is required", result)
    end)

    it("should handle invalid base tag", function()
      local success, result = tag_mapper.resolve_tag(0, nil, mock_interface)

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("base tag is required", result)
    end)

    it("should handle invalid base tag type", function()
      local success, result =
        tag_mapper.resolve_tag(0, "not a number", mock_interface)

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("base tag must be a number", result)
    end)
  end)

  describe("create_project_tag", function()
    it("should create project tag with given name", function()
      local success, result =
        tag_mapper.create_project_tag("test-project", mock_interface)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal("test-project", result.name)
    end)

    it("should not create duplicate project tag", function()
      -- Create first project tag
      local success1, result1 =
        tag_mapper.create_project_tag("existing-project", mock_interface)
      assert.is_true(success1)

      -- Try to create same project tag again - should return existing one
      local success2, result2 =
        tag_mapper.create_project_tag("existing-project", mock_interface)
      assert.is_true(success2)
      assert.are.equal(result1.name, result2.name)
    end)

    it("should handle empty project name", function()
      local success, result = tag_mapper.create_project_tag("", mock_interface)

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("project name is required", result)
    end)

    it("should handle nil project name", function()
      local success, result = tag_mapper.create_project_tag(nil, mock_interface)

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("project name is required", result)
    end)

    it("should handle non-string project name", function()
      local success, result = tag_mapper.create_project_tag(123, mock_interface)

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("project name must be a string", result)
    end)
  end)

  describe("get_current_tag", function()
    it("should return current selected tag index", function()
      mock_interface.set_current_tag_index(3)
      local result = tag_mapper.get_current_tag(mock_interface)

      assert.are.equal(3, result) -- from mock_interface.get_screen_context()
    end)

    it("should handle missing screen", function()
      -- Mock no focused screen
      mock_interface.set_screen_context()

      local result = tag_mapper.get_current_tag(mock_interface)

      assert.are.equal(1, result) -- fallback to tag 1
    end)

    it("should handle missing selected tag", function()
      mock_interface.set_current_tag_index(nil)

      local result = tag_mapper.get_current_tag(mock_interface)

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
        local success, result =
          tag_mapper.resolve_tag(test_case.spec, base_tag, mock_interface)

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
        local success, result = tag_mapper.resolve_tag(
          test_case.offset,
          test_case.base,
          mock_interface
        )

        assert.is_true(success)
        assert.is_table(result)
        assert.are.equal(test_case.expected, result.index)
      end
    end)

    it("should handle boundary conditions correctly", function()
      -- Test boundary conditions for 1-9 tag range
      local boundary_cases = {
        -- Edge of range - tag 1
        { base = 1, offset = 0, expected = 1 }, -- current tag 1
        { base = 1, offset = 8, expected = 9 }, -- tag 1 + 8 = tag 9 (max)

        -- Edge of range - tag 9
        { base = 9, offset = 0, expected = 9 }, -- current tag 9
        { base = 9, offset = 1, expected = 9 }, -- tag 9 + 1 = overflow to 9

        -- Mid-range variations
        { base = 4, offset = 3, expected = 7 }, -- tag 4 + 3 = tag 7
        { base = 6, offset = 2, expected = 8 }, -- tag 6 + 2 = tag 8
      }

      for _, test_case in ipairs(boundary_cases) do
        local success, result = tag_mapper.resolve_tag(
          test_case.offset,
          test_case.base,
          mock_interface
        )
        assert.is_true(
          success,
          "Failed for base=" .. test_case.base .. " offset=" .. test_case.offset
        )
        assert.are.equal(
          test_case.expected,
          result.index,
          "Expected "
            .. test_case.expected
            .. " for base="
            .. test_case.base
            .. " offset="
            .. test_case.offset
            .. ", got "
            .. result.index
        )
      end
    end)

    it("should handle mixed tag types in sequence", function()
      -- Test resolving different tag types from the same base
      local base_tag = 3
      local mixed_specs = {
        { spec = 0, type = "relative", expected_index = 3 }, -- current
        { spec = 2, type = "relative", expected_index = 5 }, -- +2
        { spec = "7", type = "absolute", expected_index = 7 }, -- absolute
        { spec = "workspace", type = "named", expected_name = "workspace" },
      }

      for _, test_case in ipairs(mixed_specs) do
        local success, result =
          tag_mapper.resolve_tag(test_case.spec, base_tag, mock_interface)
        assert.is_true(success)

        if test_case.expected_index then
          assert.are.equal(test_case.expected_index, result.index)
        end
        if test_case.expected_name then
          assert.are.equal(test_case.expected_name, result.name)
        end
      end
    end)
  end)

  describe("DSL compatibility wrappers", function()
    describe("validate_tag_spec", function()
      it("should validate valid numeric tag specs", function()
        local success, error = tag_mapper.validate_tag_spec(2)
        assert.is_true(success)
        assert.is_nil(error)
      end)

      it("should validate valid string tag specs", function()
        local success, error = tag_mapper.validate_tag_spec("3")
        assert.is_true(success)
        assert.is_nil(error)
      end)

      it("should validate valid named tag specs", function()
        local success, error = tag_mapper.validate_tag_spec("editor")
        assert.is_true(success)
        assert.is_nil(error)
      end)

      it("should reject invalid tag spec types", function()
        local success, error = tag_mapper.validate_tag_spec(true)
        assert.is_false(success)
        assert.is_string(error)
      end)

      it("should reject nil tag specs", function()
        local success, error = tag_mapper.validate_tag_spec(nil)
        assert.is_false(success)
        assert.is_string(error)
      end)
    end)

    describe("describe_tag_spec", function()
      it("should describe relative tag specs", function()
        assert.are.equal(
          "current tag (relative offset 0)",
          tag_mapper.describe_tag_spec(0)
        )
        assert.are.equal("relative offset +2", tag_mapper.describe_tag_spec(2))
      end)

      it("should describe absolute tag specs", function()
        assert.are.equal("absolute tag 3", tag_mapper.describe_tag_spec("3"))
        assert.are.equal("absolute tag 9", tag_mapper.describe_tag_spec("9"))
      end)

      it("should describe named tag specs", function()
        assert.are.equal(
          "named tag 'editor'",
          tag_mapper.describe_tag_spec("editor")
        )
        assert.are.equal(
          "named tag 'browser'",
          tag_mapper.describe_tag_spec("browser")
        )
      end)

      it("should handle invalid tag specs", function()
        assert.are.equal("invalid tag spec", tag_mapper.describe_tag_spec(nil))
        assert.are.equal(
          "invalid tag spec type: boolean",
          tag_mapper.describe_tag_spec(true)
        )
      end)
    end)
  end)
end)
