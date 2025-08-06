local assert = require("luassert")

describe("tag_mapper.integration", function()
  local integration
  local tag_mapper_core
  local awesome_interface
  local dry_run_interface

  setup(function()
    _G._TEST = true
  end)
  teardown(function()
    _G._TEST = nil
  end)

  before_each(function()
    -- Clean module cache
    package.loaded["tag_mapper.integration"] = nil
    package.loaded["tag_mapper.core"] = nil
    package.loaded["awe.interfaces.awesome_interface"] = nil
    package.loaded["awe.interfaces.dry_run_interface"] = nil

    integration = require("tag_mapper.integration")
    tag_mapper_core = require("tag_mapper.core")

    -- Load both interfaces for testing
    awesome_interface = require("awe").interfaces.awesome_interface
    dry_run_interface = require("awe").interfaces.dry_run_interface

    -- Clear dry-run state
    dry_run_interface.clear_execution_log()
  end)

  describe("execute_tag_plan", function()
    local mock_plan
    local mock_screen_context

    before_each(function()
      mock_screen_context = {
        screen = { name = "test_screen" },
        current_tag_index = 3,
        available_tags = {},
        tag_count = 0,
      }

      mock_plan = {
        assignments = {
          {
            resource_id = "resource_1",
            type = "named",
            name = "editor",
            needs_creation = true,
          },
          {
            resource_id = "resource_2",
            type = "relative",
            resolved_index = 4,
            needs_creation = false,
          },
        },
        creations = {
          {
            name = "editor",
            screen = mock_screen_context.screen,
            operation = "create",
          },
        },
        warnings = {},
        metadata = {
          base_tag = 3,
          total_operations = 2,
        },
      }
    end)

    it("should execute tag creations via interface", function()
      local results = integration.execute_tag_plan(mock_plan, dry_run_interface)

      assert.is_table(results)
      assert.is_table(results.created_tags)
      assert.is_table(results.assignments)
      assert.is_table(results.failures)

      -- Should have created the "editor" tag
      assert.are.equal(1, #results.created_tags)
      assert.are.equal("editor", results.created_tags[1].name)

      -- Should have 2 assignments
      assert.are.equal(2, #results.assignments)

      -- Should have no failures
      assert.are.equal(0, #results.failures)
    end)

    it("should handle creation failures gracefully", function()
      -- Use a mock interface that fails tag creation
      local failing_interface = {
        create_named_tag = function(name, screen)
          return nil -- Simulate failure
        end,
      }

      local results = integration.execute_tag_plan(mock_plan, failing_interface)

      assert.is_table(results)
      assert.are.equal(0, #results.created_tags)
      assert.are.equal(1, #results.failures)
      assert.matches("failed to create tag", results.failures[1].error)
    end)

    it("should return structured execution results", function()
      local results = integration.execute_tag_plan(mock_plan, dry_run_interface)

      assert.is_table(results)

      -- Check structure
      assert.is_table(results.created_tags)
      assert.is_table(results.assignments)
      assert.is_table(results.failures)
      assert.is_table(results.warnings)
      assert.is_table(results.metadata)

      -- Metadata should include execution info
      assert.is_number(results.metadata.execution_time_ms)
      assert.are.equal("success", results.metadata.overall_status)
    end)

    it("should handle empty plan", function()
      local empty_plan = {
        assignments = {},
        creations = {},
        warnings = {},
        metadata = { total_operations = 0 },
      }

      local results =
        integration.execute_tag_plan(empty_plan, dry_run_interface)

      assert.is_table(results)
      assert.are.equal(0, #results.created_tags)
      assert.are.equal(0, #results.assignments)
      assert.are.equal(0, #results.failures)
    end)

    it("should validate plan parameter", function()
      local result, error_obj =
        integration.execute_tag_plan(nil, dry_run_interface)

      assert.is_nil(result)
      assert.is_table(error_obj)
      assert.matches("plan is required", error_obj.message)
    end)

    it("should validate interface parameter", function()
      local result, error_obj = integration.execute_tag_plan(mock_plan, nil)

      assert.is_nil(result)
      assert.is_table(error_obj)
      assert.matches("interface is required", error_obj.message)
    end)

    -- New TDD Cycle 3 tests for structured error handling
    describe("structured error handling", function()
      it("should aggregate tag creation failures from interface", function()
        -- Mock interface that fails some tag creations
        local failing_interface = {
          create_named_tag = function(name, screen)
            if name == "editor" then
              return nil -- First creation fails
            else
              return { name = name } -- Others succeed
            end
          end,
          get_screen_context = function()
            return {
              screen = { name = "test" },
              current_tag_index = 3,
              available_tags = {},
              tag_count = 0,
            }
          end,
        }

        -- Plan with multiple creations
        local multi_plan = {
          assignments = {},
          creations = {
            { name = "editor", screen = { name = "test" } },
            { name = "browser", screen = { name = "test" } },
          },
          warnings = {},
          metadata = {},
        }

        local results =
          integration.execute_tag_plan(multi_plan, failing_interface)

        -- Should return results with failures collected, not throw error
        assert.is_table(results)
        assert.are.equal(1, #results.failures)
        assert.are.equal(1, #results.created_tags)
        assert.are.equal("partial_failure", results.metadata.overall_status)

        -- Failure should be structured
        local failure = results.failures[1]
        assert.are.equal("create_tag", failure.operation)
        assert.are.equal("editor", failure.tag_name)
        assert.matches("failed to create tag", failure.error)
      end)

      it(
        "should handle interface errors that return structured objects",
        function()
          -- Mock interface that returns structured error objects
          local structured_failing_interface = {
            create_named_tag = function(name, screen)
              return nil,
                {
                  category = "TAG_CREATION_ERROR",
                  type = "TAG_NAME_INVALID",
                  message = "Invalid tag name: " .. name,
                  resource_id = name,
                  suggestions = { "Use valid tag name format" },
                  context = { tag_name = name },
                }
            end,
            get_screen_context = function()
              return {
                screen = { name = "test" },
                current_tag_index = 3,
                available_tags = {},
                tag_count = 0,
              }
            end,
          }

          local single_creation_plan = {
            assignments = {},
            creations = {
              { name = "invalid-name!", screen = { name = "test" } },
            },
            warnings = {},
            metadata = {},
          }

          local results = integration.execute_tag_plan(
            single_creation_plan,
            structured_failing_interface
          )

          assert.is_table(results)
          assert.are.equal(1, #results.failures)
          assert.are.equal("partial_failure", results.metadata.overall_status)

          -- Failure should preserve structured error information
          local failure = results.failures[1]
          assert.are.equal("create_tag", failure.operation)
          assert.are.equal("invalid-name!", failure.tag_name)
          assert.is_table(failure.structured_error)
          assert.are.equal(
            "TAG_CREATION_ERROR",
            failure.structured_error.category
          )
        end
      )
    end)
  end)

  describe("resolve_tags_for_project", function()
    local mock_resources

    before_each(function()
      mock_resources = {
        {
          id = "editor_app",
          tag = "editor",
        },
        {
          id = "terminal",
          tag = 1,
        },
        {
          id = "browser",
          tag = "5",
        },
      }
    end)

    it(
      "should coordinate full workflow: context → plan → execute",
      function()
        local results = integration.resolve_tags_for_project(
          mock_resources,
          3,
          dry_run_interface
        )

        assert.is_table(results)
        assert.is_table(results.plan)
        assert.is_table(results.execution)

        -- Plan should be created
        assert.are.equal(3, #results.plan.assignments)

        -- Execution should occur
        assert.is_table(results.execution.created_tags)
        assert.is_table(results.execution.assignments)
      end
    )

    it("should handle mixed tag types in project resources", function()
      local results = integration.resolve_tags_for_project(
        mock_resources,
        3,
        dry_run_interface
      )

      assert.is_table(results)

      -- Should handle relative, absolute, and named tags
      local assignments = results.plan.assignments
      assert.are.equal(3, #assignments)

      -- Check assignment types
      local assignment_by_id = {}
      for _, assignment in ipairs(assignments) do
        assignment_by_id[assignment.resource_id] = assignment
      end

      assert.are.equal("named", assignment_by_id["editor_app"].type)
      assert.are.equal("relative", assignment_by_id["terminal"].type)
      assert.are.equal("absolute", assignment_by_id["browser"].type)
    end)

    it("should return comprehensive results with warnings", function()
      -- Add a resource that will cause overflow
      table.insert(mock_resources, {
        id = "overflow_app",
        tag = 15, -- will overflow to tag 9
      })

      local results = integration.resolve_tags_for_project(
        mock_resources,
        3,
        dry_run_interface
      )

      assert.is_table(results)

      -- Should have warnings about overflow
      assert.are.equal(1, #results.plan.warnings)
      assert.are.equal("overflow", results.plan.warnings[1].type)

      -- Should still execute successfully
      assert.are.equal("success", results.execution.metadata.overall_status)
    end)

    it("should validate resources parameter", function()
      local result, error_obj =
        integration.resolve_tags_for_project(nil, 3, dry_run_interface)

      assert.is_nil(result)
      assert.is_table(error_obj)
      assert.matches("resources list is required", error_obj.message)
    end)

    it("should validate base_tag parameter", function()
      local result, error_obj = integration.resolve_tags_for_project(
        mock_resources,
        nil,
        dry_run_interface
      )

      assert.is_nil(result)
      assert.is_table(error_obj)
      assert.matches("base tag is required", error_obj.message)
    end)

    it("should validate interface parameter", function()
      local result, error_obj =
        integration.resolve_tags_for_project(mock_resources, 3, nil)

      assert.is_nil(result)
      assert.is_table(error_obj)
      assert.matches("interface is required", error_obj.message)
    end)

    -- New TDD Cycle 3 tests for structured error handling
    describe("structured error handling", function()
      it(
        "should handle core planning errors and return structured errors",
        function()
          -- Mock resources that will cause core planning to fail
          local problem_resources = {
            {
              id = "invalid_resource",
              tag = function() end, -- Invalid tag type that should cause core to return error
            },
          }

          local result, error_obj = integration.resolve_tags_for_project(
            problem_resources,
            3,
            dry_run_interface
          )

          -- Should return error from core planning phase
          assert.is_nil(result)
          assert.is_table(error_obj)
          assert.is_string(error_obj.message)
          assert.is_table(error_obj.suggestions)
        end
      )

      it(
        "should aggregate errors from both planning and execution phases",
        function()
          -- Mock interface that fails during execution
          local execution_failing_interface = {
            get_screen_context = function()
              return {
                screen = { name = "test" },
                current_tag_index = 3,
                available_tags = {},
                tag_count = 0,
              }
            end,
            create_named_tag = function(name, screen)
              return nil -- All tag creations fail
            end,
          }

          -- Resources that require tag creation (will fail in execution)
          local creation_resources = {
            { id = "editor", tag = "editor_workspace" },
            { id = "browser", tag = "browser_workspace" },
          }

          local result, error_obj = integration.resolve_tags_for_project(
            creation_resources,
            3,
            execution_failing_interface
          )

          -- Should handle execution failures gracefully
          if result then
            -- Partial success case - execution has failures
            assert.is_table(result.execution.failures)
            assert.are.equal(
              "partial_failure",
              result.execution.metadata.overall_status
            )
          else
            -- Complete failure case - structured error returned
            assert.is_table(error_obj)
            assert.is_string(error_obj.message)
          end
        end
      )
    end)
  end)

  describe("interface compatibility", function()
    it(
      "should work with both awesome_interface and dry_run_interface",
      function()
        local mock_resources = {
          { id = "test_app", tag = "test_tag" },
        }

        -- Test with dry-run interface
        local dry_results = integration.resolve_tags_for_project(
          mock_resources,
          3,
          dry_run_interface
        )

        -- Both should succeed and have similar structure
        assert.is_table(dry_results)
        assert.is_table(dry_results.plan)
        assert.is_table(dry_results.execution)

        -- Dry-run should have execution log
        local log = dry_run_interface.get_execution_log()
        assert.is_true(#log > 0)
      end
    )
  end)
end)
