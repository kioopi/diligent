local assert = require("luassert")

-- Import the start handler to access spawn_resources function once implemented
local start_handler = require("diligent.handlers.start")

describe("spawn_resources function", function()
  local mock_awe_module
  local mock_resolved_tags
  local mock_resources

  before_each(function()
    -- Mock awe_module with spawn functionality
    mock_awe_module = {
      spawn = {
        spawner = {
          spawn_with_properties = function(command, tag, properties)
            -- Default mock behavior - successful spawn
            if command == "test-app" then
              return 1234, "test-snid", nil
            elseif command == "failing-app" then
              return nil, nil, "Command not found"
            else
              return 2345, "other-snid", nil
            end
          end,
        },
      },
    }

    -- Mock resolved tags
    mock_resolved_tags = {
      ["test-resource"] = { id = 1, name = "test-tag" },
      ["failing-resource"] = { id = 2, name = "fail-tag" },
      ["success-resource"] = { id = 3, name = "success-tag" },
    }

    -- Mock resources
    mock_resources = {
      {
        name = "test-resource",
        command = "test-app",
        working_dir = "/tmp",
        reuse = false,
        tag_spec = "relative:+1",
      },
      {
        name = "failing-resource",
        command = "failing-app",
        working_dir = "/tmp",
        reuse = true,
        tag_spec = "named:dev",
      },
    }
  end)

  describe("when spawn_resources function exists", function()
    it("should have correct function signature", function()
      local handler = start_handler.create(mock_awe_module)

      -- This test will fail initially because spawn_resources doesn't exist yet
      assert.is_not_nil(handler.spawn_resources)
      assert.is_function(handler.spawn_resources)
    end)
  end)

  describe("successful spawning scenarios", function()
    it("should return success for all successful spawns", function()
      local handler = start_handler.create(mock_awe_module)

      local success_resources = {
        {
          name = "success-resource",
          command = "test-app",
          working_dir = "/tmp",
          reuse = false,
          tag_spec = "relative:+1",
        },
      }

      local success_tags = {
        ["success-resource"] = { id = 1, name = "test-tag" },
      }

      local success, result, metadata = handler.spawn_resources(
        success_tags,
        success_resources,
        mock_awe_module
      )

      assert.is_true(success)
      assert.is_table(result)
      assert.equals(1, #result)
      assert.equals("success-resource", result[1].name)
      assert.equals(1234, result[1].pid)
      assert.equals("test-snid", result[1].snid)
      assert.equals("test-app", result[1].command)

      -- Verify metadata structure
      assert.is_table(metadata)
      assert.equals(1, metadata.total_attempted)
      assert.equals(1, metadata.success_count)
      assert.equals(0, metadata.error_count)
      assert.is_table(metadata.spawn_results)
      assert.equals(1, #metadata.spawn_results)
    end)

    it(
      "should return success with partial spawning (mixed success/failure)",
      function()
        local handler = start_handler.create(mock_awe_module)

        local success, result, metadata = handler.spawn_resources(
          mock_resolved_tags,
          mock_resources,
          mock_awe_module
        )

        assert.is_true(success) -- Should return true if ANY resource spawns
        assert.is_table(result)
        assert.equals(1, #result) -- Only successful spawn
        assert.equals("test-resource", result[1].name)

        -- Verify metadata for partial success
        assert.equals(2, metadata.total_attempted)
        assert.equals(1, metadata.success_count)
        assert.equals(1, metadata.error_count)
        assert.is_table(metadata.errors)
        assert.equals(1, #metadata.errors)
        assert.equals("SPAWN_FAILURE", metadata.errors[1].type)
      end
    )
  end)

  describe("failure scenarios", function()
    it("should return failure when all spawns fail", function()
      local handler = start_handler.create(mock_awe_module)

      local failing_resources = {
        {
          name = "failing-resource",
          command = "failing-app",
          working_dir = "/tmp",
          reuse = true,
          tag_spec = "named:dev",
        },
      }

      local failing_tags = {
        ["failing-resource"] = { id = 2, name = "fail-tag" },
      }

      local success, result, metadata = handler.spawn_resources(
        failing_tags,
        failing_resources,
        mock_awe_module
      )

      assert.is_false(success)
      assert.is_table(result) -- Should be error object
      assert.is_table(metadata)
      assert.equals(1, metadata.total_attempted)
      assert.equals(0, metadata.success_count)
      assert.equals(1, metadata.error_count)
    end)

    it("should handle missing resolved tag gracefully", function()
      local handler = start_handler.create(mock_awe_module)

      local incomplete_tags = {} -- Empty resolved tags

      local success, result, metadata = handler.spawn_resources(
        incomplete_tags,
        mock_resources,
        mock_awe_module
      )

      assert.is_false(success)
      assert.is_table(metadata)
      assert.equals(2, metadata.total_attempted)
      assert.equals(0, metadata.success_count)
      assert.equals(2, metadata.error_count)
    end)
  end)

  describe("metadata collection", function()
    it("should collect comprehensive spawn results and timing", function()
      local handler = start_handler.create(mock_awe_module)

      local success, result, metadata = handler.spawn_resources(
        mock_resolved_tags,
        mock_resources,
        mock_awe_module
      )

      -- Verify comprehensive metadata
      assert.is_table(metadata.spawn_results)
      assert.equals(2, #metadata.spawn_results)

      -- Check successful spawn result
      local success_result = metadata.spawn_results[1]
      assert.is_true(success_result.success)
      assert.equals("test-resource", success_result.resource_name)
      assert.equals(1234, success_result.pid)

      -- Check failed spawn result
      local fail_result = metadata.spawn_results[2]
      assert.is_false(fail_result.success)
      assert.equals("failing-resource", fail_result.resource_name)
      assert.is_table(fail_result.error)
    end)

    it("should create structured error objects for spawn failures", function()
      local handler = start_handler.create(mock_awe_module)

      local failing_resources = {
        {
          name = "failing-resource",
          command = "failing-app",
          working_dir = "/tmp",
          reuse = true,
          tag_spec = "named:dev",
        },
      }

      local failing_tags = {
        ["failing-resource"] = { id = 2, name = "fail-tag" },
      }

      local success, result, metadata = handler.spawn_resources(
        failing_tags,
        failing_resources,
        mock_awe_module
      )

      assert.is_table(metadata.errors)
      local error_obj = metadata.errors[1]
      assert.equals("SPAWN_FAILURE", error_obj.type)
      assert.equals("execution", error_obj.category)
      assert.equals("failing-resource", error_obj.resource_id)
      assert.is_string(error_obj.message)
      assert.is_table(error_obj.context)
      assert.is_table(error_obj.suggestions)
      assert.is_table(error_obj.metadata)
      assert.equals("spawning", error_obj.metadata.phase)
    end)
  end)
end)
