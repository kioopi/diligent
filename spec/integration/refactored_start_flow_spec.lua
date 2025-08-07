local assert = require("luassert")
local start_handler = require("diligent.handlers.start")

describe("Integration: Refactored Start Flow", function()
  local mock_awe_module
  local mock_interface
  local handler

  before_each(function()
    -- Create comprehensive mock interface
    mock_interface = {
      get_current_tag = function()
        return 2
      end,
      get_tag = function(index)
        if index == 1 then
          return { name = "tag1", index = 1 }
        elseif index == 2 then
          return { name = "tag2", index = 2 }
        elseif index == 3 then
          return { name = "tag3", index = 3 }
        else
          return nil
        end
      end,
      create_tag = function(tag_name)
        return { name = tag_name, index = 99 }
      end,
      get_screen_context = function()
        return {
          screen_count = 2,
          current_screen = 1,
        }
      end,
      create_named_tag = function(tag_name)
        return { name = tag_name, index = 100 + math.random(1, 50) }
      end,
      find_tag_by_name = function(tag_name)
        -- Return nil to simulate tag not found, triggering fallback behavior
        return nil
      end,
    }

    -- Create comprehensive mock awe module
    mock_awe_module = {
      interface = mock_interface,
      spawn = {
        spawner = {
          spawn_with_properties = function(command, tag, properties)
            -- Simulate different spawn behaviors based on command
            if command == "vim" then
              return 1001, "snid-vim-001", "Spawned vim successfully"
            elseif command == "firefox" then
              return 1002, "snid-firefox-001", "Spawned firefox successfully"
            elseif command == "nonexistent" then
              return nil, nil, "Command not found: nonexistent"
            elseif command == "fails-sometimes" then
              -- Simulate intermittent failures
              local random_fail = math.random(1, 2)
              if random_fail == 1 then
                return 1003, "snid-fails-001", "Spawned successfully"
              else
                return nil, nil, "Random spawn failure"
              end
            else
              return 1000, "snid-default-001", "Default spawn success"
            end
          end,
        },
      },
    }

    handler = start_handler.create(mock_awe_module)
  end)

  describe("End-to-End Integration Scenarios", function()
    it("should handle complete success scenario", function()
      local payload = {
        project_name = "test-project",
        resources = {
          {
            name = "editor",
            tag_spec = "2",
            command = "vim",
            working_dir = "/tmp",
          },
          {
            name = "browser",
            tag_spec = "3",
            command = "firefox",
            working_dir = "/tmp",
          },
        },
      }

      local success, response = handler.execute(payload)

      assert.is_true(success)
      assert.equals("test-project", response.project_name)
      assert.equals(2, response.total_spawned)
      assert.equals(2, #response.spawned_resources)
      assert.is_not_nil(response.tag_operations)

      -- Verify spawned resource structure
      local spawned_resources = response.spawned_resources
      assert.equals("editor", spawned_resources[1].name)
      assert.equals(1001, spawned_resources[1].pid)
      assert.equals("browser", spawned_resources[2].name)
      assert.equals(1002, spawned_resources[2].pid)
    end)

    it("should handle partial success with tag fallbacks", function()
      local payload = {
        project_name = "partial-project",
        resources = {
          {
            name = "editor",
            tag_spec = "2", -- Use simple numeric tag
            command = "vim",
            working_dir = "/tmp",
          },
          {
            name = "broken",
            tag_spec = "2",
            command = "nonexistent",
            working_dir = "/tmp",
          },
          {
            name = "browser",
            tag_spec = "2", -- Use simple numeric tag
            command = "firefox",
            working_dir = "/tmp",
          },
        },
      }

      local success, response = handler.execute(payload)

      -- Should succeed because some resources spawned (vim and firefox)
      assert.is_true(success)
      assert.equals("partial-project", response.project_name)
      assert.equals(2, response.total_spawned) -- vim and firefox should spawn
      assert.is_not_nil(response.warnings)

      -- Should have spawn errors for nonexistent command
      assert.is_not_nil(response.warnings.spawn_errors)
      assert.is_true(#response.warnings.spawn_errors > 0)
    end)

    it("should handle complete failure scenario", function()
      local payload = {
        project_name = "failed-project",
        resources = {
          {
            name = "broken1",
            tag_spec = "2",
            command = "nonexistent",
            working_dir = "/tmp",
          },
          {
            name = "broken2",
            tag_spec = "3",
            command = "nonexistent",
            working_dir = "/tmp",
          },
        },
      }

      local success, response = handler.execute(payload)

      assert.is_false(success)
      assert.equals("failed-project", response.project_name)
      assert.equals("COMPLETE_FAILURE", response.error_type)
      assert.is_not_nil(response.errors)
      assert.equals(2, #response.errors) -- Both spawn failures
      assert.equals(0, response.metadata.success_count)
      assert.equals(2, response.metadata.total_attempted)
    end)

    it("should handle empty resources gracefully", function()
      local payload = {
        project_name = "empty-project",
        resources = {},
      }

      local success, response = handler.execute(payload)

      assert.is_true(success) -- Empty resources should succeed
      assert.equals("empty-project", response.project_name)
      assert.equals(0, response.total_spawned)
      assert.equals(0, #response.spawned_resources)
    end)

    it("should propagate metadata correctly through all phases", function()
      local payload = {
        project_name = "metadata-project",
        resources = {
          {
            name = "editor",
            tag_spec = "2",
            command = "vim",
            working_dir = "/tmp",
          },
          {
            name = "browser",
            tag_spec = "3",
            command = "firefox",
            working_dir = "/tmp",
          },
        },
      }

      local success, response = handler.execute(payload)

      assert.is_true(success)

      -- Verify tag operations metadata is present
      assert.is_not_nil(response.tag_operations)

      -- Should have processed tag operations
      assert.is_not_nil(response.spawned_resources)
      assert.equals(2, #response.spawned_resources)
    end)

    it("should maintain consistent response format across scenarios", function()
      local test_cases = {
        {
          name = "success-case",
          resources = {
            {
              name = "vim",
              tag_spec = "2",
              command = "vim",
              working_dir = "/tmp",
            },
          },
          expected_success = true,
        },
        {
          name = "failure-case",
          resources = {
            {
              name = "broken",
              tag_spec = "2",
              command = "nonexistent",
              working_dir = "/tmp",
            },
          },
          expected_success = false,
        },
        {
          name = "partial-case",
          resources = {
            {
              name = "good",
              tag_spec = "2",
              command = "vim",
              working_dir = "/tmp",
            },
            {
              name = "bad",
              tag_spec = "2",
              command = "nonexistent",
              working_dir = "/tmp",
            },
          },
          expected_success = true,
        },
      }

      for _, test_case in ipairs(test_cases) do
        local payload = {
          project_name = test_case.name,
          resources = test_case.resources,
        }

        local success, response = handler.execute(payload)

        -- Verify consistent response structure
        assert.equals(test_case.expected_success, success)
        assert.equals(test_case.name, response.project_name)

        if success then
          -- Success responses should have these fields
          assert.is_not_nil(response.total_spawned)
          assert.is_not_nil(response.spawned_resources)
          assert.is_not_nil(response.tag_operations)
        else
          -- Failure responses should have these fields
          assert.is_not_nil(response.error_type)
          assert.is_not_nil(response.errors)
          assert.is_not_nil(response.metadata)
        end
      end
    end)

    it("should handle complex project with multiple resources", function()
      local payload = {
        project_name = "complex-project",
        resources = {
          {
            name = "editor",
            tag_spec = "2",
            command = "vim",
            working_dir = "/tmp",
          },
          {
            name = "browser",
            tag_spec = "3",
            command = "firefox",
            working_dir = "/tmp",
          },
          {
            name = "terminal",
            tag_spec = "2",
            command = "default",
            working_dir = "/tmp",
          },
        },
      }

      local success, response = handler.execute(payload)

      assert.is_true(success) -- Should succeed
      assert.equals("complex-project", response.project_name)
      assert.equals(3, response.total_spawned) -- All should spawn

      -- Should have tag operations
      assert.is_not_nil(response.tag_operations)
    end)
  end)

  describe("Error Collection and Propagation", function()
    it("should collect and structure errors from both phases", function()
      local payload = {
        project_name = "error-test",
        resources = {
          {
            name = "good-resource",
            tag_spec = "2",
            command = "vim",
            working_dir = "/tmp",
          },
          {
            name = "spawn-error",
            tag_spec = "2",
            command = "nonexistent",
            working_dir = "/tmp",
          },
        },
      }

      local success, response = handler.execute(payload)

      if success then
        -- Partial success - errors should be in warnings
        assert.is_not_nil(response.warnings)
        assert.is_not_nil(response.warnings.spawn_errors)
        assert.is_true(#response.warnings.spawn_errors > 0)
      else
        -- Complete failure - errors should be in errors array
        assert.is_not_nil(response.errors)
        assert.is_true(#response.errors > 0)

        -- Verify error structure contains phase information
        for _, error_entry in ipairs(response.errors) do
          assert.is_not_nil(error_entry.phase)
          assert.is_not_nil(error_entry.resource_id)
          assert.is_not_nil(error_entry.error)
        end
      end
    end)

    it("should provide detailed error context for debugging", function()
      local payload = {
        project_name = "debug-test",
        resources = {
          {
            name = "debug-resource",
            tag_spec = "2",
            command = "nonexistent",
            working_dir = "/tmp",
          },
        },
      }

      local success, response = handler.execute(payload)

      assert.is_false(success) -- Complete failure
      assert.equals(1, #response.errors)

      local error_entry = response.errors[1]
      assert.equals("spawning", error_entry.phase)
      assert.equals("debug-resource", error_entry.resource_id)

      local error_obj = error_entry.error
      assert.equals("SPAWN_FAILURE", error_obj.type)
      assert.is_not_nil(error_obj.suggestions)
      assert.is_not_nil(error_obj.context)
      assert.is_not_nil(error_obj.metadata)
    end)
  end)

  describe("Performance and Resource Management", function()
    it("should handle large number of resources efficiently", function()
      local resources = {}
      for i = 1, 50 do
        table.insert(resources, {
          name = "resource_" .. i,
          tag_spec = tostring((i % 3) + 1), -- Cycle through tags 1, 2, 3
          command = "default",
          working_dir = "/tmp",
        })
      end

      local payload = {
        project_name = "large-project",
        resources = resources,
      }

      local start_time = os.clock()
      local success, response = handler.execute(payload)
      local execution_time = os.clock() - start_time

      assert.is_true(success)
      assert.equals(50, response.total_spawned)
      assert.is_true(execution_time < 1.0) -- Should complete within 1 second
    end)
  end)
end)
