local assert = require("luassert")

describe("tag_mapper.core", function()
  local tag_mapper_core

  before_each(function()
    -- Clean module cache to get fresh instance
    package.loaded["tag_mapper.core"] = nil
    tag_mapper_core = require("tag_mapper.core")
  end)

  describe("resolve_tag_specification", function()
    local mock_screen_context

    before_each(function()
      -- Create mock screen context (what awesome_interface would provide)
      mock_screen_context = {
        screen = { name = "mock_screen" },
        current_tag_index = 3,
        available_tags = {
          { name = "1", index = 1 },
          { name = "2", index = 2 },
          { name = "3", index = 3 },
          { name = "4", index = 4 },
          { name = "5", index = 5 },
          { name = "6", index = 6 },
          { name = "7", index = 7 },
          { name = "8", index = 8 },
          { name = "9", index = 9 },
          { name = "editor", index = nil }, -- named tag
        },
        tag_count = 10,
      }
    end)

    it("should resolve relative offset 0 to base tag", function()
      local result, metadata = assert.success(
        tag_mapper_core.resolve_tag_specification(0, 3, mock_screen_context)
      )

      assert.are.equal("relative", result.type)
      assert.are.equal(3, result.resolved_index)
      assert.is_false(result.overflow)
      assert.is_nil(result.name)
      assert.is_table(metadata)
    end)

    it("should resolve relative offset 1 to base tag + 1", function()
      local result, metadata = assert.success(
        tag_mapper_core.resolve_tag_specification(1, 3, mock_screen_context)
      )

      assert.are.equal("relative", result.type)
      assert.are.equal(4, result.resolved_index)
      assert.is_false(result.overflow)
      assert.is_table(metadata)
    end)

    it("should resolve relative offset 2 to base tag + 2", function()
      local result, metadata = assert.success(
        tag_mapper_core.resolve_tag_specification(2, 3, mock_screen_context)
      )

      assert.is_table(metadata)
      assert.are.equal("relative", result.type)
      assert.are.equal(5, result.resolved_index)
      assert.is_false(result.overflow)
    end)

    it("should handle negative offsets by using tag 1", function()
      local result = assert.success(
        tag_mapper_core.resolve_tag_specification(-2, 1, mock_screen_context)
      )

      assert.are.equal("relative", result.type)
      assert.are.equal(1, result.resolved_index)
      assert.is_false(result.overflow)
    end)

    it("should detect overflow and cap at tag 9", function()
      local result, meta = assert.success(
        tag_mapper_core.resolve_tag_specification(2, 8, mock_screen_context)
      )

      assert.is_table(result)
      assert.is_table(meta)
      assert.are.equal("relative", result.type)
      assert.are.equal(9, result.resolved_index)
      assert.is_true(result.overflow)
      assert.are.equal(10, result.original_index) -- 8 + 2 = 10
    end)

    it("should resolve digit string to absolute numeric tag", function()
      local result = assert.success(
        tag_mapper_core.resolve_tag_specification("5", 3, mock_screen_context)
      )

      assert.is_table(result)
      assert.are.equal("absolute", result.type)
      assert.are.equal(5, result.resolved_index)
      assert.is_false(result.overflow)
    end)

    it("should resolve digit string with overflow to tag 9", function()
      local result = assert.success(
        tag_mapper_core.resolve_tag_specification("15", 3, mock_screen_context)
      )

      assert.is_table(result)
      assert.are.equal("absolute", result.type)
      assert.are.equal(9, result.resolved_index)
      assert.is_true(result.overflow)
      assert.are.equal(15, result.original_index)
    end)

    it("should resolve named tag that exists in screen context", function()
      local result = assert.success(
        tag_mapper_core.resolve_tag_specification(
          "editor",
          3,
          mock_screen_context
        )
      )

      assert.is_table(result)
      assert.are.equal("named", result.type)
      assert.are.equal("editor", result.name)
      assert.is_false(result.overflow)
      assert.is_nil(result.resolved_index) -- named tags don't have numeric indices
    end)

    it("should resolve named tag that doesn't exist", function()
      local result = assert.success(
        tag_mapper_core.resolve_tag_specification(
          "logs",
          3,
          mock_screen_context
        )
      )

      assert.is_table(result)
      assert.are.equal("named", result.type)
      assert.are.equal("logs", result.name)
      assert.is_false(result.overflow)
      assert.is_true(result.needs_creation)
    end)

    it("should handle nil tag spec", function()
      local error_obj = assert.no.success(
        tag_mapper_core.resolve_tag_specification(nil, 3, mock_screen_context)
      )

      assert.is_nil(result)
      assert.is_table(error_obj)
      assert.matches("tag spec is required", error_obj.message)
    end)

    it("should handle nil base tag", function()
      local error_obj = assert.no.success(
        tag_mapper_core.resolve_tag_specification(0, nil, mock_screen_context)
      )

      assert.is_nil(result)
      assert.is_table(error_obj)
      assert.matches("base tag is required", error_obj.message)
    end)

    it("should handle nil screen context", function()
      local error_obj =
        assert.no.success(tag_mapper_core.resolve_tag_specification(0, 3, nil))

      assert.is_nil(result)
      assert.is_table(error_obj)
      assert.matches("screen context is required", error_obj.message)
    end)

    it("should handle invalid tag spec type", function()
      local error_obj = assert.no.success(
        tag_mapper_core.resolve_tag_specification({}, 3, mock_screen_context)
      )

      assert.is_nil(result)
      assert.is_table(error_obj)
      assert.matches("invalid tag spec type", error_obj.message)
    end)
  end)

  describe("plan_tag_operations", function()
    local mock_screen_context
    local mock_resources

    before_each(function()
      -- Create mock screen context
      mock_screen_context = {
        screen = { name = "mock_screen" },
        current_tag_index = 3,
        available_tags = {
          { name = "1", index = 1 },
          { name = "2", index = 2 },
          { name = "3", index = 3 },
          { name = "4", index = 4 },
          { name = "5", index = 5 },
          { name = "editor", index = nil }, -- existing named tag
        },
        tag_count = 6,
      }

      -- Create mock resources with new format
      mock_resources = {
        {
          name = "resource_1",
          tag_spec = 0, -- relative: current tag
        },
        {
          name = "resource_2",
          tag_spec = 1, -- relative: current tag + 1
        },
        {
          name = "resource_3",
          tag_spec = "5", -- absolute: tag 5
        },
        {
          name = "resource_4",
          tag_spec = "editor", -- existing named tag
        },
        {
          name = "resource_5",
          tag_spec = "logs", -- new named tag
        },
      }
    end)

    it("should create operation plan for mixed tag types", function()
      local plan = assert.success(
        tag_mapper_core.plan_tag_operations(
          mock_resources,
          mock_screen_context,
          3
        )
      )

      assert.is_table(plan)
      assert.is_table(plan.assignments)
      assert.is_table(plan.creations)
      assert.is_table(plan.warnings)
      assert.is_table(plan.metadata)

      -- Should have 5 assignments (one per resource)
      assert.are.equal(5, #plan.assignments)

      -- Should have 1 creation (for "logs" tag)
      assert.are.equal(1, #plan.creations)

      -- Verify specific assignments
      local assignment_by_resource = {}
      for _, assignment in ipairs(plan.assignments) do
        assignment_by_resource[assignment.resource_id] = assignment
      end

      -- resource_1: tag 0 + base 3 = tag 3
      assert.are.equal(3, assignment_by_resource["resource_1"].resolved_index)
      assert.are.equal("relative", assignment_by_resource["resource_1"].type)

      -- resource_2: tag 1 + base 3 = tag 4
      assert.are.equal(4, assignment_by_resource["resource_2"].resolved_index)
      assert.are.equal("relative", assignment_by_resource["resource_2"].type)

      -- resource_3: absolute tag 5
      assert.are.equal(5, assignment_by_resource["resource_3"].resolved_index)
      assert.are.equal("absolute", assignment_by_resource["resource_3"].type)

      -- resource_4: existing named tag "editor"
      assert.are.equal("editor", assignment_by_resource["resource_4"].name)
      assert.are.equal("named", assignment_by_resource["resource_4"].type)
      assert.is_false(assignment_by_resource["resource_4"].needs_creation)

      -- resource_5: new named tag "logs"
      assert.are.equal("logs", assignment_by_resource["resource_5"].name)
      assert.are.equal("named", assignment_by_resource["resource_5"].type)
      assert.is_true(assignment_by_resource["resource_5"].needs_creation)

      -- Verify creation plan
      assert.are.equal("logs", plan.creations[1].name)
      assert.are.equal(mock_screen_context.screen, plan.creations[1].screen)
    end)

    it("should handle overflow warnings", function()
      local overflow_resources = {
        {
          name = "overflow_1",
          tag_spec = 8, -- base 3 + 8 = 11, should overflow to 9
        },
        {
          name = "overflow_2",
          tag_spec = "15", -- absolute 15, should overflow to 9
        },
      }

      local plan = assert.success(
        tag_mapper_core.plan_tag_operations(
          overflow_resources,
          mock_screen_context,
          3
        )
      )

      assert.is_table(plan)

      -- Should have 2 warnings (one per overflow)
      assert.are.equal(2, #plan.warnings)

      -- Check overflow assignments still resolve to tag 9
      local assignment_by_resource = {}
      for _, assignment in ipairs(plan.assignments) do
        assignment_by_resource[assignment.resource_id] = assignment
      end

      assert.are.equal(9, assignment_by_resource["overflow_1"].resolved_index)
      assert.is_true(assignment_by_resource["overflow_1"].overflow)
      assert.are.equal(11, assignment_by_resource["overflow_1"].original_index)

      assert.are.equal(9, assignment_by_resource["overflow_2"].resolved_index)
      assert.is_true(assignment_by_resource["overflow_2"].overflow)
      assert.are.equal(15, assignment_by_resource["overflow_2"].original_index)
    end)

    it("should handle empty resource list", function()
      local plan = assert.success(
        tag_mapper_core.plan_tag_operations({}, mock_screen_context, 3)
      )

      assert.is_table(plan)
      assert.are.equal(0, #plan.assignments)
      assert.are.equal(0, #plan.creations)
      assert.are.equal(0, #plan.warnings)
      assert.are.equal(0, plan.metadata.total_operations)
    end)

    it("should optimize duplicate tag creations", function()
      local duplicate_resources = {
        {
          name = "resource_1",
          tag_spec = "project_logs",
        },
        {
          name = "resource_2",
          tag_spec = "project_logs", -- same tag name
        },
      }

      local plan = assert.success(
        tag_mapper_core.plan_tag_operations(
          duplicate_resources,
          mock_screen_context,
          3
        )
      )

      assert.is_table(plan)

      -- Should have 2 assignments
      assert.are.equal(2, #plan.assignments)

      -- Should have only 1 creation (duplicates optimized away)
      assert.are.equal(1, #plan.creations)
      assert.are.equal("project_logs", plan.creations[1].name)
    end)

    it("should handle nil resources", function()
      local error_obj = assert.no.success(
        tag_mapper_core.plan_tag_operations(nil, mock_screen_context, 3)
      )

      assert.matches("resources list is required", error_obj.message)
    end)

    it("should handle nil screen context", function()
      local error_obj = assert.no.success(
        tag_mapper_core.plan_tag_operations(mock_resources, nil, 3)
      )

      assert.matches("screen context is required", error_obj.message)
    end)

    it("should handle nil base tag", function()
      local error_obj = assert.no.success(
        tag_mapper_core.plan_tag_operations(
          mock_resources,
          mock_screen_context,
          nil
        )
      )

      assert.matches("base tag is required", error_obj.message)
    end)
  end)

  -- NEW: Tests for return-based error handling (TDD Cycle 2)
  describe("resolve_tag_specification error handling", function()
    local mock_screen_context

    before_each(function()
      mock_screen_context = {
        screen = { name = "mock_screen" },
        current_tag_index = 3,
        available_tags = {},
        tag_count = 9,
      }
    end)

    it("should return error object for nil tag_spec", function()
      local error_obj = assert.no.success(
        tag_mapper_core.resolve_tag_specification(nil, 3, mock_screen_context)
      )

      assert.are.equal("TAG_SPEC_INVALID", error_obj.type)
      assert.matches("tag spec is required", error_obj.message)
      assert.is_table(error_obj.suggestions)
      assert.is_table(error_obj.context)
    end)

    it("should return error object for nil base_tag", function()
      local error_obj = assert.no.success(
        tag_mapper_core.resolve_tag_specification(2, nil, mock_screen_context)
      )

      assert.are.equal("TAG_SPEC_INVALID", error_obj.type)
      assert.matches("base tag is required", error_obj.message)
      assert.is_table(error_obj.suggestions)
    end)

    it("should return error object for invalid base_tag type", function()
      local error_obj = assert.no.success(
        tag_mapper_core.resolve_tag_specification(
          2,
          "invalid",
          mock_screen_context
        )
      )

      assert.are.equal("TAG_SPEC_INVALID", error_obj.type)
      assert.matches("base tag must be a number", error_obj.message)
    end)

    it("should return error object for nil screen_context", function()
      local error_obj =
        assert.no.success(tag_mapper_core.resolve_tag_specification(2, 3, nil))

      assert.are.equal("TAG_SPEC_INVALID", error_obj.type)
      assert.matches("screen context is required", error_obj.message)
    end)

    it("should return error object for invalid tag_spec type", function()
      local error_obj = assert.no.success(
        tag_mapper_core.resolve_tag_specification(
          { invalid = true },
          3,
          mock_screen_context
        )
      )

      assert.are.equal("TAG_SPEC_INVALID", error_obj.type)
      assert.matches("invalid tag spec type", error_obj.message)
      assert.is_table(error_obj.suggestions)

      -- Should suggest valid tag spec formats
      local has_format_suggestion = false
      for _, suggestion in ipairs(error_obj.suggestions) do
        if suggestion:match("number.*or.*string") then
          has_format_suggestion = true
          break
        end
      end
      assert.is_true(has_format_suggestion)
    end)
  end)

  describe("plan_tag_operations error handling", function()
    local mock_screen_context

    before_each(function()
      mock_screen_context = {
        screen = { name = "mock_screen" },
        current_tag_index = 3,
        available_tags = {},
        tag_count = 9,
      }
    end)

    it("should return error object for nil resources", function()
      local error_obj = assert.no.success(
        tag_mapper_core.plan_tag_operations(nil, mock_screen_context, 3)
      )

      assert.is_nil(result)
      assert.is_table(error_obj)
      assert.are.equal("TAG_SPEC_INVALID", error_obj.type)
      assert.matches("resources list is required", error_obj.message)
    end)

    it("should return error object for nil screen_context", function()
      local error_obj =
        assert.no.success(tag_mapper_core.plan_tag_operations({}, nil, 3))

      assert.are.equal("TAG_SPEC_INVALID", error_obj.type)
      assert.matches("screen context is required", error_obj.message)
    end)

    it("should return error object for nil base_tag", function()
      local error_obj = assert.no.success(
        tag_mapper_core.plan_tag_operations({}, mock_screen_context, nil)
      )

      assert.are.equal("TAG_SPEC_INVALID", error_obj.type)
      assert.matches("base tag is required", error_obj.message)
    end)

    it(
      "should handle individual resource errors and continue processing",
      function()
        local resources = {
          { name = "valid", tag_spec = 1 },
          { name = "invalid", tag_spec = { bad = "spec" } },
          { name = "also_valid", tag_spec = 2 },
        }

        local success, result =
          tag_mapper_core.plan_tag_operations(resources, mock_screen_context, 3)

        -- Should return partial plan with error information
        if success then
          -- Should have assignments for valid resources
          assert.is_table(result.assignments)
          -- Should have error information for invalid resource
          assert.is_table(result.errors)
          assert.is_true(#result.errors > 0)
        else
          -- Or return aggregated error if critical failure
          assert.is_table(result)
          assert.matches("invalid.*resource", result.message:lower())
        end
      end
    )
  end)
end)
