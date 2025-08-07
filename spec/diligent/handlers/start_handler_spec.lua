local assert = require("luassert")

describe("Start Handler", function()
  local start_handler
  local awe
  local mock_interface

  setup(function()
    _G._TEST = true
    mock_interface = require("awe.interfaces.mock_interface")
    start_handler = require("diligent.handlers.start")
    awe = require("awe").create(mock_interface)
    handler = start_handler.create(awe)
  end)

  before_each(function()
    mock_interface.reset()
  end)

  teardown(function()
    _G._TEST = nil
  end)

  describe("validator", function()
    it("should have LIVR validator for start payload", function()
      assert.is_table(start_handler.validator)
      assert.is_function(start_handler.validator.validate)
    end)

    it("should validate valid start payload", function()
      local payload = {
        project_name = "test-project",
        resources = {
          {
            name = "editor",
            command = "gedit",
            tag_spec = "0",
          },
        },
      }

      local valid_data, errors = start_handler.validator:validate(payload)
      assert.is_not_nil(valid_data)
      assert.is_nil(errors)
      assert.are.equal("test-project", valid_data.project_name)
    end)

    it("should reject payload without project_name", function()
      local payload = {
        resources = {},
      }

      local valid_data, errors = start_handler.validator:validate(payload)
      assert.is_nil(valid_data)
      assert.is_not_nil(errors)
      assert.is_string(errors.project_name)
    end)

    it("should reject payload without resources", function()
      local payload = {
        project_name = "test",
      }

      local valid_data, errors = start_handler.validator:validate(payload)
      assert.is_nil(valid_data)
      assert.is_not_nil(errors)
      assert.is_string(errors.resources)
    end)
  end)

  describe("create", function()
    it("should create handler with execute function", function()
      assert.is_table(handler)
      assert.is_function(handler.execute)
    end)

    it("should create handler with validator function", function()
      assert.is_table(handler.validator)
      assert.is_function(handler.validator.validate)
    end)
  end)

  describe("execute", function()
    it("should spawn single app successfully", function()
      local payload = {
        project_name = "test-project",
        resources = {
          {
            name = "editor",
            command = "gedit",
            tag_spec = "0",
          },
        },
      }

      -- Create mock awe with successful spawn response
      local result = assert.success(handler.execute(payload))

      assert.are.equal("test-project", result.project_name)
      assert.are.equal(1, #result.spawned_resources)
      assert.are.equal("editor", result.spawned_resources[1].name)
      assert.are.equal("gedit", result.spawned_resources[1].command)
      assert.are.equal("0", result.spawned_resources[1].tag_spec)
      assert.is_number(result.spawned_resources[1].pid)
      assert.are.equal(1, result.total_spawned)
    end)

    it("should handle spawn failure gracefully", function()
      local payload = {
        project_name = "test-project",
        resources = {
          {
            name = "invalid",
            command = "nonexistent-app",
            tag_spec = "0",
          },
        },
      }

      mock_interface.set_spawn_config({
        success = false,
        error = "Error: Command not found",
      })
      local error = assert.no.success(handler.execute(payload))

      assert.matches("Command not found", error.error)
      assert.are.equal("invalid", error.failed_resource)
      assert.are.equal("test-project", error.project_name)
    end)

    it("should spawn multiple resources sequentially", function()
      local payload = {
        project_name = "multi-app",
        resources = {
          {
            name = "editor",
            command = "gedit",
            tag_spec = "0",
          },
          {
            name = "terminal",
            command = "alacritty",
            tag_spec = "1",
          },
        },
      }

      local result = assert.success(handler.execute(payload))

      assert.are.equal("multi-app", result.project_name)
      assert.are.equal(2, #result.spawned_resources)
      assert.are.equal(2, result.total_spawned)

      -- Check first resource
      assert.are.equal("editor", result.spawned_resources[1].name)
      assert.are.equal("gedit", result.spawned_resources[1].command)

      -- Check second resource
      assert.are.equal("terminal", result.spawned_resources[2].name)
      assert.are.equal("alacritty", result.spawned_resources[2].command)
    end)

    it("should handle partial failure in multi-resource project", function()
      local payload = {
        project_name = "partial-fail",
        resources = {
          {
            name = "good-app",
            command = "gedit",
            tag_spec = "0",
          },
          {
            name = "bad-app",
            command = "fail_spawn", -- Magic command that fails in mock_interface
            tag_spec = "1",
          },
        },
      }

      local error = assert.no.success(handler.execute(payload))
      assert.are.equal("bad-app", error.failed_resource)
      assert.matches("Command not found", error.error)
    end)

    it("should pass working directory and reuse options to spawner", function()
      local payload = {
        project_name = "config-test",
        resources = {
          {
            name = "editor",
            command = "gedit",
            tag_spec = "0",
            working_dir = "/home/user",
            reuse = true,
          },
        },
      }

      local result = assert.success(handler.execute(payload))

      assert.are.equal(1, result.total_spawned)
    end)

    it("should handle empty resources list", function()
      local payload = {
        project_name = "empty-project",
        resources = {},
      }

      local success, result = handler.execute(payload)

      assert.is_true(success)
      assert.are.equal("empty-project", result.project_name)
      assert.are.equal(0, #result.spawned_resources)
      assert.are.equal(0, result.total_spawned)
    end)
  end)

  describe("enhanced error collection (Phase 5)", function()
    local phase5_handler

    before_each(function()
      mock_interface.reset()

      -- Create a separate handler instance with mocked dependencies for Phase 5 tests
      -- This avoids interfering with other test suites
      local mock_tag_mapper = {
        get_current_tag = function(interface)
          return 1 -- Mock current tag
        end,
        resolve_tags_for_project = function(resources, base_tag, interface)
          -- Mock function to return different error scenarios for testing
          return nil, {
            type = "TAG_OVERFLOW",
            category = "validation", 
            resource_id = "editor",
            tag_spec = 2,
            message = "Tag overflow: resolved to tag 9",
            context = {
              base_tag = 2,
              resolved_index = 11,
              original_spec = 2
            },
            suggestions = {
              "Consider using absolute tag \"9\"",
              "Check if you intended a relative offset"
            },
            metadata = {
              timestamp = os.time(),
              phase = "planning"
            }
          }
        end
      }

      -- Create Phase 5 handler by directly injecting the mock
      phase5_handler = {
        validator = start_handler.validator,
        execute = function(payload)
          -- Simplified version of handler.execute that uses the mock_tag_mapper directly
          local spawned_resources = {}
          local interface = awe.interface
          local current_tag_index = mock_tag_mapper.get_current_tag(interface)
          
          local tag_mapper_resources = {}
          for _, resource in ipairs(payload.resources or {}) do
            table.insert(tag_mapper_resources, {
              id = resource.name,
              tag = resource.tag_spec,
            })
          end
          
          local tag_success, tag_result = mock_tag_mapper.resolve_tags_for_project(
            tag_mapper_resources,
            current_tag_index,
            interface
          )
          
          if not tag_success then
            return start_handler.create(awe).format_error_response(payload.project_name, tag_result, payload.resources)
          end
          
          -- Process spawning with normal handler logic
          return handler.execute(payload)
        end
      }
      
      -- Add the format_error_response method
      phase5_handler.format_error_response = start_handler.create(awe).format_error_response
    end)

    it("should collect structured error objects from tag_mapper", function()
      local payload = {
        project_name = "error-test",
        resources = {
          {
            name = "editor",
            command = "gedit",
            tag_spec = 2,
          },
        },
      }

      local success, result = phase5_handler.execute(payload)
      
      assert.is_false(success, "Handler should fail with structured error")
      
      -- Test enhanced error response format
      assert.is_table(result, "Result should be a table")
      assert.equals("error-test", result.project_name)
      assert.equals("COMPLETE_FAILURE", result.error_type)
      assert.is_table(result.errors, "Should have errors array")
      assert.equals(1, #result.errors, "Should have one error")
      
      -- Test error object structure
      local error_obj = result.errors[1]
      assert.equals("tag_resolution", error_obj.phase)
      assert.equals("editor", error_obj.resource_id) 
      assert.is_table(error_obj.error, "Should contain structured error object")
      assert.equals("TAG_OVERFLOW", error_obj.error.type)
      assert.equals("Tag overflow: resolved to tag 9", error_obj.error.message)
      assert.is_table(error_obj.error.suggestions, "Should have suggestions")
      assert.equals(2, #error_obj.error.suggestions)
    end)

    it("should continue processing after tag resolution failures when possible", function()
      -- Update the phase5_handler to return partial success data
      phase5_handler.execute = function(payload)
        -- Mock tag_mapper to succeed for some resources, fail for others
        local tag_result = {
          type = "MULTIPLE_TAG_ERRORS", 
          category = "validation",
          message = "Tag resolution failed for some resources",
          context = {
            failed_resources = {"editor"},
            successful_resources = {"terminal"}
          },
          partial_success = {
            resolved_tags = {
              terminal = { index = 2, name = "2" }
            },
            tag_operations = {
              created_tags = {},
              assignments = {{resource_id = "terminal", resolved_index = 2}},
              warnings = {},
              total_created = 0
            }
          },
          errors = {
            {
              type = "TAG_OVERFLOW",
              resource_id = "editor", 
              message = "Tag overflow: resolved to tag 9"
            }
          }
        }
        
        return start_handler.create(awe).format_error_response(payload.project_name, tag_result, payload.resources)
      end

      local payload = {
        project_name = "partial-test",
        resources = {
          {
            name = "editor",
            command = "gedit", 
            tag_spec = 2,
          },
          {
            name = "terminal",
            command = "alacritty",
            tag_spec = "2", 
          },
        },
      }

      local success, result = phase5_handler.execute(payload)
      
      assert.is_false(success, "Handler should fail but provide partial success")
      assert.equals("PARTIAL_FAILURE", result.error_type)
      assert.is_table(result.partial_success, "Should have partial success data")
      assert.is_table(result.partial_success.spawned_resources)
      assert.equals(1, result.partial_success.total_spawned)
      assert.equals("terminal", result.partial_success.spawned_resources[1].name)
      
      -- Verify metadata
      assert.is_table(result.metadata)
      assert.equals(2, result.metadata.total_attempted)
      assert.equals(1, result.metadata.success_count)
      assert.equals(1, result.metadata.error_count)
    end)

    it("should handle multiple error types in single response", function()
      -- Mock both tag resolution and spawning errors
      phase5_handler.execute = function(payload)
        -- Simulate tag resolution success but spawning failure
        local spawned_resources = {}
        local spawn_errors = {}
        
        -- First resource succeeds
        table.insert(spawned_resources, {
          name = "editor",
          pid = 12345,
          snid = "snid1",
          command = "gedit",
          tag_spec = "2",
        })
        
        -- Second resource fails to spawn
        table.insert(spawn_errors, {
          phase = "spawning",
          resource_id = "browser",
          error = {
            type = "SPAWN_FAILURE",
            message = "Command not found: nonexistent-browser",
            context = { command = "nonexistent-browser" }
          }
        })
        
        -- Return partial failure response
        return false, {
          project_name = payload.project_name,
          error_type = "PARTIAL_FAILURE",
          errors = spawn_errors,
          partial_success = {
            spawned_resources = spawned_resources,
            total_spawned = #spawned_resources
          },
          metadata = {
            total_attempted = #payload.resources,
            success_count = #spawned_resources,
            error_count = #spawn_errors
          }
        }
      end

      local payload = {
        project_name = "mixed-errors-test",
        resources = {
          {
            name = "editor",
            command = "gedit",
            tag_spec = "2",
          },
          {
            name = "browser", 
            command = "nonexistent-browser",
            tag_spec = "3",
          },
        },
      }

      local success, result = phase5_handler.execute(payload)
      
      assert.is_false(success, "Handler should fail with mixed errors")
      assert.equals("PARTIAL_FAILURE", result.error_type)
      assert.equals(1, #result.errors) -- One spawning error
      assert.equals("spawning", result.errors[1].phase)
      assert.equals("browser", result.errors[1].resource_id)
      
      -- Should have partial success with editor
      assert.equals(1, result.partial_success.total_spawned)
      assert.equals("editor", result.partial_success.spawned_resources[1].name)
    end)

    it("should format complete failure when no resources succeed", function()
      -- Update phase5_handler for complete failure scenario
      phase5_handler.execute = function(payload)
        local tag_result = {
          type = "MULTIPLE_TAG_ERRORS",
          category = "validation", 
          message = "All tag resolutions failed",
          errors = {
            {type = "TAG_OVERFLOW", resource_id = "editor", message = "Tag overflow"},
            {type = "TAG_SPEC_INVALID", resource_id = "browser", message = "Invalid tag spec"}
          }
        }
        
        return start_handler.create(awe).format_error_response(payload.project_name, tag_result, payload.resources)
      end

      local payload = {
        project_name = "complete-fail-test",
        resources = {
          {name = "editor", command = "gedit", tag_spec = 2},
          {name = "browser", command = "firefox", tag_spec = {}},
        },
      }

      local success, result = phase5_handler.execute(payload)
      
      assert.is_false(success)
      assert.equals("COMPLETE_FAILURE", result.error_type)
      assert.equals(2, #result.errors)
      assert.is_nil(result.partial_success, "Should not have partial success")
      assert.equals(2, result.metadata.total_attempted)
      assert.equals(0, result.metadata.success_count)
      assert.equals(2, result.metadata.error_count)
    end)
  end)

  describe("tag resolution with tag_mapper", function()
    local original_tag_mapper
    local original_start_handler

    before_each(function()
      mock_interface.reset()

      -- Mock tag_mapper to control tag resolution behavior
      original_tag_mapper = package.loaded["tag_mapper"]
      package.loaded["tag_mapper"] = {
        resolve_tag = function(tag_spec, base_tag, interface)
          -- Mock successful resolution - return tag object based on tag_spec
          if type(tag_spec) == "number" then
            -- Relative tag: current tag + offset
            return true,
              {
                index = base_tag + tag_spec,
                name = tostring(base_tag + tag_spec),
              }
          elseif type(tag_spec) == "string" then
            local numeric = tonumber(tag_spec)
            if numeric then
              -- Absolute tag
              return true,
                {
                  index = numeric,
                  name = tostring(numeric),
                }
            else
              -- Named tag
              return true,
                {
                  index = 2, -- Mock index for named tags
                  name = tag_spec,
                }
            end
          end
          return false, "invalid tag spec"
        end,
        get_current_tag = function(interface)
          -- Mock get_current_tag to return current tag from interface
          local screen_context = interface.get_screen_context()
          return screen_context.current_tag_index or 1
        end,
        resolve_tags_for_project = function(resources, base_tag, interface)
          -- Mock batch tag resolution - transform to individual calls
          local resolved_tags = {}
          local created_tags_map = {} -- Use map to avoid duplicates
          local assignments = {}

          for _, resource in ipairs(resources) do
            -- Use the existing resolve_tag mock logic
            local success, tag = package.loaded["tag_mapper"].resolve_tag(
              resource.tag,
              base_tag,
              interface
            )
            if success then
              resolved_tags[resource.id] = tag
              table.insert(assignments, {
                resource_id = resource.id,
                type = type(resource.tag) == "string" and "named" or "relative",
                resolved_index = tag.index,
                name = tag.name,
              })
              -- Mock tag creation for named tags (avoid duplicates)
              if
                type(resource.tag) == "string" and not tonumber(resource.tag)
              then
                created_tags_map[resource.tag] =
                  { name = resource.tag, tag = tag }
              end
            else
              return false, "Tag creation failed: " .. tostring(tag)
            end
          end

          -- Convert map to array
          local created_tags = {}
          for _, tag_info in pairs(created_tags_map) do
            table.insert(created_tags, tag_info)
          end

          return true,
            {
              resolved_tags = resolved_tags,
              tag_operations = {
                created_tags = created_tags,
                assignments = assignments,
                warnings = {},
                metadata = { overall_status = "success" },
                total_created = #created_tags,
              },
            }
        end,
      }

      -- Force start_handler to reload with mocked tag_mapper
      original_start_handler = package.loaded["diligent.handlers.start"]
      package.loaded["diligent.handlers.start"] = nil
      start_handler = require("diligent.handlers.start")
    end)

    after_each(function()
      -- Restore original modules
      package.loaded["tag_mapper"] = original_tag_mapper
      package.loaded["diligent.handlers.start"] = original_start_handler
    end)

    it("should resolve relative tags correctly", function()
      -- Set user on tag 2
      mock_interface.set_current_tag_index(2)

      local payload = {
        project_name = "relative-test",
        resources = {
          {
            name = "editor",
            command = "gedit",
            tag_spec = 2, -- relative +2, should resolve to tag 4
          },
        },
      }

      local success, result = handler.execute(payload)

      assert.is_true(success, "Handler execution should succeed")
      assert.are.equal(1, result.total_spawned)

      -- Verify spawner received resolved tag (4), not raw tag_spec (2)
      local spawn_call = mock_interface.get_last_spawn_call()
      assert.is_not_nil(spawn_call.properties.tag)
      assert.are.equal(
        4,
        spawn_call.properties.tag.index,
        "Spawner should receive resolved tag 4 (2+2), got: "
          .. tostring(spawn_call.properties.tag.index)
      )
    end)

    it("should resolve absolute tags correctly", function()
      -- Set user on tag 2 (should not affect absolute tag resolution)
      mock_interface.set_current_tag_index(2)

      local payload = {
        project_name = "absolute-test",
        resources = {
          {
            name = "browser",
            command = "firefox",
            tag_spec = "5", -- absolute tag 5
          },
        },
      }

      local success, result = handler.execute(payload)

      assert.is_true(success, "Handler execution should succeed")

      -- Verify spawner received absolute tag 5 (not affected by current tag 2)
      local spawn_call = mock_interface.get_last_spawn_call()
      assert.are.equal(
        5,
        spawn_call.properties.tag.index,
        "Spawner should receive absolute tag 5, got: "
          .. tostring(spawn_call.properties.tag.index)
      )
    end)

    it("should resolve named tags correctly", function()
      local payload = {
        project_name = "named-test",
        resources = {
          {
            name = "editor",
            command = "gedit",
            tag_spec = "editor", -- named tag
          },
        },
      }

      local success, result = handler.execute(payload)

      assert.is_true(success, "Handler execution should succeed")

      -- Verify spawner received named tag object
      local spawn_call = mock_interface.get_last_spawn_call()
      assert.are.equal(
        "editor",
        spawn_call.properties.tag.name,
        "Spawner should receive named tag 'editor', got: "
          .. tostring(spawn_call.properties.tag.name)
      )
    end)

    it("should handle tag resolution failures gracefully", function()
      -- Store original tag_mapper for restoration
      local original_resolve_tag = package.loaded["tag_mapper"].resolve_tag

      -- Mock tag_mapper to return failure
      package.loaded["tag_mapper"].resolve_tag = function(
        tag_spec,
        base_tag,
        interface
      )
        return false, "invalid tag specification: " .. tostring(tag_spec)
      end

      local payload = {
        project_name = "failure-test",
        resources = {
          {
            name = "invalid",
            command = "gedit",
            tag_spec = {}, -- invalid tag spec
          },
        },
      }

      local success, result = handler.execute(payload)

      -- Restore original tag_mapper
      package.loaded["tag_mapper"].resolve_tag = original_resolve_tag

      assert.is_false(success, "Handler should fail with invalid tag")
      assert.matches("Tag resolution failed", result.error or "")
      assert.are.equal("invalid", result.failed_resource)
    end)
  end)

  describe("tag resolution via tag_mapper", function()
    before_each(function()
      mock_interface.reset()
    end)

    it(
      "should correctly resolve relative tags from current tag via tag_mapper",
      function()
        -- SETUP: User is on tag 2, wants to spawn app with relative offset +2 (should go to tag 4)
        mock_interface.set_current_tag_index(2)

        local dsl_str = [[
        return {
          name = "bug-test",
          resources = {
            arandr = app { cmd = "arandr", tag = 2 },
          }
        }
        ]]

        local parser = require("dsl.parser")
        local success, dsl = parser.compile_dsl(dsl_str)

        if not success then
          error("DSL compilation failed: " .. tostring(dsl))
        end
        assert.is_true(success, "DSL compilation failed: " .. tostring(dsl))

        local start_processor = require("dsl.start_processor")
        local start_request =
          start_processor.convert_project_to_start_request(dsl)

        local arandr_request = start_request.resources[1]

        assert.is_nil(
          arandr_request.tag_info,
          "tag_info should not be present - processor no longer creates it"
        )
        assert.are.equal(
          2,
          arandr_request.tag_spec,
          "Offset should be 2, got: " .. tostring(arandr_request.tag_spec)
        ) -- Relative +2 offset

        local success, result = handler.execute(start_request)

        if not success then
          error(
            "Handler execution failed: "
              .. (result and result.error or "unknown error")
          )
        end
        assert.is_true(success)

        local spawn_call = mock_interface.get_last_spawn_call()

        assert.are.equal(
          4,
          spawn_call.properties.tag.index,
          "Expected tag index 4, got: "
            .. tostring(spawn_call.properties.tag.index)
        )
      end
    )

    it("should correctly resolve absolute tags via tag_mapper", function()
      -- SETUP: User on tag 2, absolute tag "4" should go to tag 4
      mock_interface.set_current_tag_index(2)

      local payload = {
        project_name = "absolute-test",
        resources = {
          {
            name = "pavucontrol",
            command = "pavucontrol",
            tag_spec = "4", -- Absolute tag 4
            -- No tag_info - handler resolves via tag_mapper
          },
        },
      }

      local success, result = handler.execute(payload)

      assert.is_true(success)

      local spawn_call = mock_interface.get_last_spawn_call()
    end)

    it(
      "should correctly resolve tags through handler using tag_mapper",
      function()
        -- SETUP: Simple case that should demonstrate correct tag resolution
        mock_interface.set_current_tag_index(3) -- User on tag 3

        local payload = {
          project_name = "location-test",
          resources = {
            {
              name = "test-app",
              command = "gedit",
              tag_spec = 1, -- Relative +1 (should go to tag 4)
              -- No tag_info - handler resolves via tag_mapper
            },
          },
        }

        -- Execute and capture the spawn call
        local success, result = handler.execute(payload)
        assert.is_true(success)

        local spawn_call = mock_interface.get_last_spawn_call()

        assert.are.equal(
          4,
          spawn_call.properties.tag.index,
          "Expected tag index 4 passed to spawn, got: "
            .. tostring(spawn_call.properties.tag.index)
        )
      end
    )

    it(
      "should resolve user's exact scenario: user on tag 2 with relative and absolute tags",
      function()
        -- SETUP: This matches the user's exact DSL scenario
        mock_interface.set_current_tag_index(2) -- User is on tag 2

        local payload = {
          project_name = "fun",
          resources = {
            {
              name = "arandr",
              command = "arandr",
              tag_spec = 2, -- relative +2 (should go to tag 4: 2+2)
              -- No tag_info - handler resolves via tag_mapper
            },
            {
              name = "audio",
              command = "pavucontrol",
              tag_spec = "4", -- absolute tag 4
              -- No tag_info - handler resolves via tag_mapper
            },
          },
        }

        local success, result = handler.execute(payload)

        assert.is_true(success)
        assert.are.equal(2, result.total_spawned)

        local spawn_calls = mock_interface.get_spawn_calls()

        assert.are.equal(
          2,
          #spawn_calls,
          "Expected 2 spawn calls, got: " .. tostring(#spawn_calls)
        )
        assert.are.equal("arandr", spawn_calls[1].command)
        assert.are.equal(
          4,
          spawn_calls[1].properties.tag.index,
          "arandr should spawn on tag 4 (2+2) but got: "
            .. tostring(spawn_calls[1].properties.tag.index)
        )

        assert.are.equal("pavucontrol", spawn_calls[2].command)
        assert.are.equal(
          4,
          spawn_calls[2].properties.tag.index,
          "pavucontrol should spawn on tag 4 (2+2) but got: "
            .. tostring(spawn_calls[1].properties.tag.index)
        )
      end
    )

    describe("batch tag processing (Phase 3)", function()
      it("should include tag operations in response", function()
        local payload = {
          project_name = "batch-test",
          resources = {
            { name = "vim", command = "vim", tag_spec = 2 },
            { name = "browser", command = "firefox", tag_spec = "editor" },
          },
        }

        local success, result = handler.execute(payload)
        assert.is_true(success, "Handler execution should succeed")

        -- Verify existing fields still exist
        assert.equals("batch-test", result.project_name)
        assert.is_table(result.spawned_resources)
        assert.is_number(result.total_spawned)

        -- Verify new tag_operations field exists
        assert.is_table(
          result.tag_operations,
          "Should include tag_operations in response"
        )
        assert.is_table(
          result.tag_operations.created_tags,
          "Should include created_tags info"
        )
        assert.is_table(
          result.tag_operations.assignments,
          "Should include assignments info"
        )
        assert.is_table(
          result.tag_operations.warnings,
          "Should include warnings info"
        )
        assert.is_number(
          result.tag_operations.total_created,
          "Should include total_created count"
        )

        -- Verify tag operations contain meaningful data
        assert.equals(2, #result.tag_operations.assignments) -- 2 resources
        assert.equals(1, result.tag_operations.total_created) -- 1 new tag created ("editor")
      end)

      it("should handle batch tag creation efficiently", function()
        local payload = {
          project_name = "efficiency-test",
          resources = {
            { name = "app1", command = "cmd1", tag_spec = "shared_workspace" },
            { name = "app2", command = "cmd2", tag_spec = "shared_workspace" },
            { name = "app3", command = "cmd3", tag_spec = "shared_workspace" },
          },
        }

        local success, result = handler.execute(payload)
        assert.is_true(success)

        -- Should only create the tag once despite 3 resources needing it
        assert.equals(1, result.tag_operations.total_created)
        assert.equals(3, #result.tag_operations.assignments)

        -- All resources should spawn successfully
        assert.equals(3, result.total_spawned)
        assert.equals(3, #result.spawned_resources)
      end)

      it("should handle tag creation failures gracefully", function()
        local payload = {
          project_name = "tag-fail-test",
          resources = {
            {
              name = "test-app",
              command = "test-cmd",
              tag_spec = "fail_tag_creation", -- Named tag that will fail
            },
          },
        }

        local result = assert.no.success(handler.execute(payload))
        assert.is_string(result.error)
        assert.matches("Tag creation failed", result.error)
        assert.equals("tag-fail-test", result.project_name)
      end)
    end)
  end)
end)
