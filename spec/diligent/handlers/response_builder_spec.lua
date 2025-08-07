local assert = require("luassert")

describe("Response Builder", function()
  local start_handler
  local awe
  local mock_interface
  local build_combined_response

  setup(function()
    _G._TEST = true
    mock_interface = require("awe.interfaces.mock_interface")
    start_handler = require("diligent.handlers.start")
    awe = require("awe").create(mock_interface)

    -- Create handler to access build_combined_response function
    local handler = start_handler.create(awe)
    build_combined_response = handler.build_combined_response
  end)

  before_each(function()
    mock_interface.reset()
  end)

  teardown(function()
    _G._TEST = nil
  end)

  describe("build_combined_response", function()
    it("should build success response when all resources spawn", function()
      local tag_metadata = {
        tag_operations = {
          created_tags = { { name = "editor", tag = { index = 2 } } },
          assignments = {
            { resource_id = "vim", resolved_index = 1 },
            { resource_id = "browser", resolved_index = 2 },
          },
          warnings = {},
          total_created = 1,
        },
        errors = {},
      }

      local spawn_metadata = {
        result = {
          {
            name = "vim",
            pid = 1234,
            snid = "snid1",
            command = "vim",
            tag_spec = "1",
          },
          {
            name = "browser",
            pid = 5678,
            snid = "snid2",
            command = "firefox",
            tag_spec = "editor",
          },
        },
        success_count = 2,
        error_count = 0,
        errors = {},
      }

      local payload = {
        project_name = "test-project",
        resources = {
          { name = "vim", command = "vim", tag_spec = "1" },
          { name = "browser", command = "firefox", tag_spec = "editor" },
        },
      }

      local success, response =
        build_combined_response(tag_metadata, spawn_metadata, payload)

      assert.is_true(success, "Should return success when all resources spawn")
      assert.equals("test-project", response.project_name)
      assert.equals(2, response.total_spawned)
      assert.equals(2, #response.spawned_resources)
      assert.equals("vim", response.spawned_resources[1].name)
      assert.equals("browser", response.spawned_resources[2].name)
      assert.is_table(response.tag_operations)
      assert.equals(1, response.tag_operations.total_created)
      assert.is_nil(
        response.warnings,
        "Should not have warnings when no errors"
      )
    end)

    it(
      "should build success response with warnings for partial failures",
      function()
        local tag_metadata = {
          tag_operations = {
            created_tags = {},
            assignments = {
              { resource_id = "vim", resolved_index = 1 },
              { resource_id = "bad-app", resolved_index = 2 },
            },
            warnings = {},
            total_created = 0,
          },
          errors = {
            {
              type = "TAG_FALLBACK_USED",
              resource_id = "bad-app",
              message = "Used fallback tag due to resolution failure",
            },
          },
        }

        local spawn_metadata = {
          result = {
            {
              name = "vim",
              pid = 1234,
              snid = "snid1",
              command = "vim",
              tag_spec = "1",
            },
          },
          success_count = 1,
          error_count = 1,
          errors = {
            {
              type = "SPAWN_FAILURE",
              resource_id = "bad-app",
              message = "Command not found: bad-cmd",
            },
          },
        }

        local payload = {
          project_name = "partial-test",
          resources = {
            { name = "vim", command = "vim", tag_spec = "1" },
            { name = "bad-app", command = "bad-cmd", tag_spec = "2" },
          },
        }

        local success, response =
          build_combined_response(tag_metadata, spawn_metadata, payload)

        assert.is_true(
          success,
          "Should return success when some resources spawn"
        )
        assert.equals("partial-test", response.project_name)
        assert.equals(1, response.total_spawned)
        assert.equals(1, #response.spawned_resources)
        assert.equals("vim", response.spawned_resources[1].name)

        -- Should include warnings for errors
        assert.is_table(response.warnings)
        assert.is_table(response.warnings.tag_errors)
        assert.is_table(response.warnings.spawn_errors)
        assert.equals(1, #response.warnings.tag_errors)
        assert.equals(1, #response.warnings.spawn_errors)
      end
    )

    it("should build failure response when no resources spawn", function()
      local tag_metadata = {
        tag_operations = {
          created_tags = {},
          assignments = {},
          warnings = {},
          total_created = 0,
        },
        errors = {
          {
            type = "TAG_OVERFLOW",
            resource_id = "vim",
            message = "Tag overflow: resolved to tag 9",
          },
        },
      }

      local spawn_metadata = {
        result = {},
        success_count = 0,
        error_count = 2,
        errors = {
          {
            type = "SPAWN_FAILURE",
            resource_id = "vim",
            message = "Command not found: vim",
          },
          {
            type = "SPAWN_FAILURE",
            resource_id = "browser",
            message = "Command not found: firefox",
          },
        },
      }

      local payload = {
        project_name = "failure-test",
        resources = {
          { name = "vim", command = "vim", tag_spec = "8" },
          { name = "browser", command = "firefox", tag_spec = "2" },
        },
      }

      local success, response =
        build_combined_response(tag_metadata, spawn_metadata, payload)

      assert.is_false(success, "Should return failure when no resources spawn")
      assert.equals("failure-test", response.project_name)
      assert.equals("COMPLETE_FAILURE", response.error_type)
      assert.is_table(response.errors)
      assert.equals(3, #response.errors) -- 1 tag error + 2 spawn errors

      -- Check error structure
      local tag_error = response.errors[1]
      assert.equals("tag_resolution", tag_error.phase)
      assert.equals("vim", tag_error.resource_id)
      assert.equals("TAG_OVERFLOW", tag_error.error.type)

      local spawn_error1 = response.errors[2]
      assert.equals("spawning", spawn_error1.phase)
      assert.equals("vim", spawn_error1.resource_id)

      -- Check metadata
      assert.is_table(response.metadata)
      assert.equals(2, response.metadata.total_attempted)
      assert.equals(0, response.metadata.success_count)
      assert.equals(3, response.metadata.error_count)
    end)

    it("should handle empty resources gracefully", function()
      local tag_metadata = {
        tag_operations = {
          created_tags = {},
          assignments = {},
          warnings = {},
          total_created = 0,
        },
        errors = {},
      }

      local spawn_metadata = {
        result = {},
        success_count = 0,
        error_count = 0,
        errors = {},
      }

      local payload = {
        project_name = "empty-test",
        resources = {},
      }

      local success, response =
        build_combined_response(tag_metadata, spawn_metadata, payload)

      assert.is_true(success, "Should succeed with empty resources")
      assert.equals("empty-test", response.project_name)
      assert.equals(0, response.total_spawned)
      assert.equals(0, #response.spawned_resources)
      assert.is_table(response.tag_operations)
      assert.is_nil(
        response.warnings,
        "Should not have warnings with empty resources"
      )
    end)

    it("should properly format tag resolution errors", function()
      local tag_metadata = {
        tag_operations = {
          created_tags = {},
          assignments = {},
          warnings = {},
          total_created = 0,
        },
        errors = {
          {
            type = "TAG_SPEC_INVALID",
            resource_id = "app1",
            message = "Invalid tag specification",
            context = { tag_spec = {} },
          },
          {
            type = "TAG_CREATION_FAILED",
            resource_id = "app2",
            message = "Failed to create named tag",
            context = { tag_name = "workspace" },
          },
        },
      }

      local spawn_metadata = {
        result = {},
        success_count = 0,
        error_count = 0,
        errors = {},
      }

      local payload = {
        project_name = "tag-error-test",
        resources = {
          { name = "app1", command = "cmd1", tag_spec = {} },
          { name = "app2", command = "cmd2", tag_spec = "workspace" },
        },
      }

      local success, response =
        build_combined_response(tag_metadata, spawn_metadata, payload)

      assert.is_false(success, "Should fail when all tag resolutions fail")
      assert.equals("COMPLETE_FAILURE", response.error_type)
      assert.equals(2, #response.errors)

      -- Both errors should be tagged as tag_resolution phase
      for i, error_obj in ipairs(response.errors) do
        assert.equals("tag_resolution", error_obj.phase)
        assert.is_table(error_obj.error)
        assert.is_string(error_obj.error.message)
      end
    end)

    it("should combine tag and spawn errors correctly", function()
      local tag_metadata = {
        tag_operations = {
          created_tags = {},
          assignments = { { resource_id = "good-app", resolved_index = 1 } },
          warnings = {},
          total_created = 0,
        },
        errors = {
          {
            type = "TAG_FALLBACK_USED",
            resource_id = "bad-tag-app",
            message = "Used fallback tag",
          },
        },
      }

      local spawn_metadata = {
        result = {
          {
            name = "good-app",
            pid = 1234,
            snid = "snid1",
            command = "good-cmd",
            tag_spec = "1",
          },
        },
        success_count = 1,
        error_count = 1,
        errors = {
          {
            type = "SPAWN_FAILURE",
            resource_id = "bad-spawn-app",
            message = "Command not found",
          },
        },
      }

      local payload = {
        project_name = "mixed-error-test",
        resources = {
          { name = "good-app", command = "good-cmd", tag_spec = "1" },
          { name = "bad-tag-app", command = "cmd2", tag_spec = "invalid" },
          { name = "bad-spawn-app", command = "bad-cmd", tag_spec = "2" },
        },
      }

      local success, response =
        build_combined_response(tag_metadata, spawn_metadata, payload)

      assert.is_true(success, "Should succeed because one app spawned")
      assert.equals("mixed-error-test", response.project_name)
      assert.equals(1, response.total_spawned)

      -- Should have warnings with both tag and spawn errors
      assert.is_table(response.warnings)
      assert.equals(1, #response.warnings.tag_errors)
      assert.equals(1, #response.warnings.spawn_errors)

      -- Tag error
      assert.equals("TAG_FALLBACK_USED", response.warnings.tag_errors[1].type)
      assert.equals("bad-tag-app", response.warnings.tag_errors[1].resource_id)

      -- Spawn error
      assert.equals("SPAWN_FAILURE", response.warnings.spawn_errors[1].type)
      assert.equals(
        "bad-spawn-app",
        response.warnings.spawn_errors[1].resource_id
      )
    end)
  end)
end)
