local assert = require("luassert")
local tag_mapper = require("tag_mapper")

describe("tag_mapper fallback strategy", function()
  local mock_interface
  local mock_screen

  before_each(function()
    mock_screen = {
      tags = {
        { index = 1, name = "1" },
        { index = 2, name = "2" },
        { index = 3, name = "3" },
      },
    }

    mock_interface = {
      get_screen = function()
        return mock_screen
      end,
      get_current_tag_index = function()
        return 2
      end,
      get_screen_context = function()
        return {
          screen = mock_screen,
          current_tag_index = 2,
          available_tags = mock_screen.tags,
          tag_count = #mock_screen.tags,
        }
      end,
      create_named_tag = function(name)
        -- Simulate tag creation failure for testing
        return nil, "Tag creation failed: " .. name
      end,
      find_tag_by_name = function(name)
        -- Return nil to simulate tag not found
        return nil
      end,
    }
  end)

  describe("when individual tag resolution fails", function()
    it("should use current_tag fallback for relative tag failure", function()
      local resources = {
        { name = "vim", tag_spec = function() end }, -- Invalid tag spec type should trigger fallback
      }

      -- This should succeed with fallback, not fail
      local success, result =
        tag_mapper.resolve_tags_for_project(resources, 2, mock_interface)

      assert.is_true(success, "should succeed with fallback strategy")
      assert.is_not_nil(
        result.resolved_tags["vim"],
        "should have resolved tag for vim"
      )
      assert.equals(
        2,
        result.resolved_tags["vim"].index,
        "should fallback to current_tag"
      )

      -- Should have error in metadata
      assert.is_table(
        result.tag_operations.errors,
        "should have errors array in metadata"
      )
      assert.is_true(
        #result.tag_operations.errors > 0,
        "should have at least one error in metadata"
      )
      assert.equals(
        "vim",
        result.tag_operations.errors[1].resource_id,
        "should identify failed resource"
      )
    end)

    it("should use current_tag fallback for absolute tag failure", function()
      local resources = {
        { name = "browser", tag_spec = "invalid string" }, -- Named tag that will be treated as such
      }

      local success, result =
        tag_mapper.resolve_tags_for_project(resources, 2, mock_interface)

      assert.is_true(success, "should succeed with fallback strategy")
      assert.is_not_nil(
        result.resolved_tags["browser"],
        "should have resolved tag for browser"
      )
      -- This will be treated as a named tag and get current_tag fallback when creation fails
      assert.equals(
        2,
        result.resolved_tags["browser"].index,
        "should fallback to current_tag"
      )
      assert.equals(
        "invalid string",
        result.resolved_tags["browser"].name,
        "should preserve tag name"
      )
    end)

    it(
      "should use current_tag fallback for named tag creation failure",
      function()
        local resources = {
          { name = "editor", tag_spec = "nonexistent_tag" },
        }

        local success, result =
          tag_mapper.resolve_tags_for_project(resources, 2, mock_interface)

        assert.is_true(success, "should succeed with fallback strategy")
        assert.is_not_nil(
          result.resolved_tags["editor"],
          "should have resolved tag for editor"
        )
        -- For named tags that fail creation, fallback to current_tag
        assert.equals(
          2,
          result.resolved_tags["editor"].index,
          "should fallback to current_tag"
        )
        assert.equals(
          "nonexistent_tag",
          result.resolved_tags["editor"].name,
          "should preserve tag name"
        )

        -- Execution should have failure information for tag creation
        -- (Note: core errors are for resolution failures, execution failures are separate)
        assert.is_table(result.tag_operations.created_tags)
      end
    )
  end)

  describe("parameter validation", function()
    it("should fail when base_tag is nil", function()
      local resources = {
        { name = "app", tag_spec = 1 },
      }

      local success, result =
        tag_mapper.resolve_tags_for_project(resources, nil, mock_interface)

      assert.is_false(success, "should fail with nil base_tag")
      assert.is_string(result, "should return error message")
    end)
  end)

  describe("error collection and metadata", function()
    it("should succeed even when all individual resolutions fail", function()
      local resources = {
        { name = "app1", tag_spec = function() end },
        { name = "app2", tag_spec = {} },
      }

      local success, result =
        tag_mapper.resolve_tags_for_project(resources, 2, mock_interface)

      assert.is_true(success, "should succeed with all fallbacks")
      assert.is_table(result.resolved_tags, "should have resolved tags")
      assert.is_not_nil(
        result.resolved_tags["app1"],
        "should have fallback for app1"
      )
      assert.is_not_nil(
        result.resolved_tags["app2"],
        "should have fallback for app2"
      )

      -- Both should fallback to current_tag (index 2)
      assert.equals(
        2,
        result.resolved_tags["app1"].index,
        "app1 should fallback to current_tag"
      )
      assert.equals(
        2,
        result.resolved_tags["app2"].index,
        "app2 should fallback to current_tag"
      )
    end)
  end)

  describe("critical system errors (should still fail)", function()
    it("should fail when interface is invalid", function()
      local resources = { { name = "app", tag_spec = 1 } }

      local success, result = tag_mapper.resolve_tags_for_project(
        resources,
        1,
        nil -- Invalid interface
      )

      -- This should be one of the few cases that still fails
      assert.is_false(success, "should fail on critical system error")
      assert.is_string(result, "should return error message")
    end)

    it("should fail when resources are invalid", function()
      local success, result = tag_mapper.resolve_tags_for_project(
        nil,
        1,
        mock_interface -- Invalid resources
      )

      assert.is_false(success, "should fail on invalid input")
      assert.is_string(result, "should return error message")
    end)
  end)
end)
