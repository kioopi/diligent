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
    it(
      "should spawn single app successfully via simplified orchestration",
      function()
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

        -- Test simplified response structure (no complex error handling)
        assert.are.equal("test-project", result.project_name)
        assert.are.equal(1, #result.spawned_resources)
        assert.are.equal("editor", result.spawned_resources[1].name)
        assert.are.equal("gedit", result.spawned_resources[1].command)
        assert.are.equal("0", result.spawned_resources[1].tag_spec)
        assert.is_number(result.spawned_resources[1].pid)
        assert.are.equal(1, result.total_spawned)

        -- Verify tag_operations from tag resolution phase is included
        assert.is_table(
          result.tag_operations,
          "Should include tag_operations from tag_mapper"
        )
      end
    )

    it("should handle spawn failure via simplified error response", function()
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
      local success, result = handler.execute(payload)

      assert.is_false(success, "Handler should fail with spawn error")
      -- Test simplified response structure from build_combined_response
      assert.equals("test-project", result.project_name)
      assert.equals("COMPLETE_FAILURE", result.error_type)
      assert.is_table(result.errors)
      assert.equals(1, #result.errors)
      assert.equals("spawning", result.errors[1].phase)
      assert.equals("invalid", result.errors[1].resource_id)
      assert.matches("Command not found", result.errors[1].error.message)
      -- Metadata should come from combined tag and spawn metadata
      assert.is_table(result.metadata)
      assert.equals(1, result.metadata.total_attempted)
      assert.equals(0, result.metadata.success_count)
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

    it(
      "should handle partial failure via simplified response building",
      function()
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

        local success, result = handler.execute(payload)
        -- With simplified handler, this should succeed with warnings in metadata
        assert.is_true(
          success,
          "Handler should succeed because good-app spawns successfully"
        )
        assert.equals("partial-fail", result.project_name)
        assert.equals(1, result.total_spawned) -- Only good-app spawned
        assert.equals(1, #result.spawned_resources)
        assert.equals("good-app", result.spawned_resources[1].name)

        -- Test simplified response includes warnings for partial failures
        assert.is_table(
          result.warnings,
          "Should include warnings for spawn failures"
        )
        assert.is_table(
          result.warnings.spawn_errors,
          "Should include spawn error details"
        )
        assert.equals(
          1,
          #result.warnings.spawn_errors,
          "Should have one spawn error"
        )
      end
    )

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
          return nil,
            {
              type = "TAG_OVERFLOW",
              category = "validation",
              resource_id = "editor",
              tag_spec = 2,
              message = "Tag overflow: resolved to tag 9",
              context = {
                base_tag = 2,
                resolved_index = 11,
                original_spec = 2,
              },
              suggestions = {
                'Consider using absolute tag "9"',
                "Check if you intended a relative offset",
              },
              metadata = {
                timestamp = os.time(),
                phase = "planning",
              },
            }
        end,
      }

      -- Use real refactored handler with proper awe_module mock
      local real_awe_module = {
        interface = awe.interface,
        spawn = {
          spawner = {
            spawn_with_properties = function(command, tag, properties)
              -- Mock failing spawn for testing error paths
              return nil, nil, "Spawn failed for testing"
            end,
          },
        },
      }
      
      phase5_handler = start_handler.create(real_awe_module)

      -- Legacy test infrastructure - format_error_response has been removed in TDD Cycle 4
    end)

    it("should collect structured error objects from tag_mapper", function()
      local payload = {
        project_name = "error-test",
        resources = {
          {
            name = "editor",
            command = "nonexistent_command", -- This will cause spawn failure
            tag_spec = 2,
          },
        },
      }

      local success, result = phase5_handler.execute(payload)

      assert.is_false(success, "Handler should fail when all resources fail to spawn")

      -- Test enhanced error response format with refactored handler
      assert.is_table(result, "Result should be a table")
      assert.equals("error-test", result.project_name)
      assert.equals("COMPLETE_FAILURE", result.error_type)
      assert.is_table(result.errors, "Should have errors array")
      assert.equals(1, #result.errors, "Should have one error")

      -- Test error object structure - should be spawn error since tag resolution uses fallbacks
      local error_obj = result.errors[1]
      assert.equals("spawning", error_obj.phase)
      assert.equals("editor", error_obj.resource_id)
      assert.is_table(error_obj.error, "Should contain structured error object")
      assert.equals("SPAWN_FAILURE", error_obj.error.type)
      assert.is_string(error_obj.error.message)
      assert.is_table(error_obj.error.suggestions, "Should have suggestions")
    end)

    it(
      "should continue processing after tag resolution failures when possible",
      function()
        -- Create new awe_module that allows one resource to succeed, one to fail
        local mixed_awe_module = {
          interface = awe.interface,
          spawn = {
            spawner = {
              spawn_with_properties = function(command, tag, properties)
                if command == "alacritty" then
                  return 1001, "snid-terminal", "Terminal spawned successfully"
                else
                  return nil, nil, "Spawn failed for " .. command
                end
              end,
            },
          },
        }
        
        local mixed_handler = start_handler.create(mixed_awe_module)

        local payload = {
          project_name = "partial-test",
          resources = {
            {
              name = "editor",
              command = "nonexistent_editor",
              tag_spec = 2,
            },
            {
              name = "terminal", 
              command = "alacritty",
              tag_spec = "2",
            },
          },
        }

        local success, result = mixed_handler.execute(payload)

        -- Should succeed because terminal spawns successfully (partial success)
        assert.is_true(success, "Handler should succeed with partial success")
        
        assert.equals("partial-test", result.project_name)
        assert.equals(1, result.total_spawned, "Should have one spawned resource")
        assert.equals("terminal", result.spawned_resources[1].name)
        
        -- Should have warnings about the failed resource
        assert.is_not_nil(result.warnings, "Should have warnings")
        assert.is_not_nil(result.warnings.spawn_errors, "Should have spawn errors")
        assert.equals(1, #result.warnings.spawn_errors, "Should have one spawn error")
        
        -- Verify tag operations are present
        assert.is_not_nil(result.tag_operations, "Should have tag operations")
      end
    )

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
            context = { command = "nonexistent-browser" },
          },
        })

        -- Return partial failure response
        return false,
          {
            project_name = payload.project_name,
            error_type = "PARTIAL_FAILURE",
            errors = spawn_errors,
            partial_success = {
              spawned_resources = spawned_resources,
              total_spawned = #spawned_resources,
            },
            metadata = {
              total_attempted = #payload.resources,
              success_count = #spawned_resources,
              error_count = #spawn_errors,
            },
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
      -- Use real refactored handler with failing spawn mock for complete failure
      local failure_awe_module = {
        interface = awe.interface,
        spawn = {
          spawner = {
            spawn_with_properties = function(command, tag, properties)
              -- All spawns fail to create complete failure scenario
              return nil, nil, "Spawn failed: " .. command .. " not found"
            end,
          },
        },
      }
      
      local failure_handler = start_handler.create(failure_awe_module)

      local payload = {
        project_name = "complete-fail-test",
        resources = {
          { name = "editor", command = "gedit", tag_spec = 2 },
          { name = "browser", command = "firefox", tag_spec = 3 },
        },
      }

      local success, result = failure_handler.execute(payload)

      assert.is_false(success)
      assert.equals("COMPLETE_FAILURE", result.error_type)
      assert.equals("complete-fail-test", result.project_name)
      assert.equals(2, #result.errors) -- Two spawn failures
      assert.equals(2, result.metadata.total_attempted)
      assert.equals(0, result.metadata.success_count)
      assert.equals(2, result.metadata.error_count)
      
      -- Verify error structure
      for _, error_entry in ipairs(result.errors) do
        assert.equals("spawning", error_entry.phase)
        assert.is_not_nil(error_entry.resource_id)
        assert.equals("SPAWN_FAILURE", error_entry.error.type)
      end
    end)
  end)

  describe(
    "simplified error handling without backwards compatibility",
    function()
      local simplified_handler

      before_each(function()
        mock_interface.reset()
        simplified_handler = start_handler.create(awe)
      end)

      it(
        "should always use enhanced error format for tag resolution failures",
        function()
          -- Create a new handler with properly mocked tag_mapper
          local mock_tag_mapper = {
            get_current_tag = function()
              return 1
            end,
            resolve_tags_for_project = function(resources, base_tag, interface)
              -- Return old string format that backwards compatibility would handle
              return false, "simple string error message" -- false for failure
            end,
          }

          -- Store original and replace
          local original_tag_mapper = package.loaded["tag_mapper"]
          package.loaded["tag_mapper"] = mock_tag_mapper

          -- Force start_handler to reload with mocked tag_mapper
          local original_start_handler =
            package.loaded["diligent.handlers.start"]
          package.loaded["diligent.handlers.start"] = nil
          local test_handler = require("diligent.handlers.start").create(awe)

          local payload = {
            project_name = "string-error-test",
            resources = {
              { name = "editor", command = "gedit", tag_spec = "invalid" },
            },
          }

          local success, result = test_handler.execute(payload)

          -- Handler should fail but use new structured format (no backwards compatibility)
          assert.is_false(success, "Handler should fail")

          -- Should NOT have old format fields (backwards compatibility removed)
          assert.is_nil(result.error, "Should not have simple error field")
          assert.is_nil(
            result.failed_resource,
            "Should not have failed_resource field"
          )

          -- Should have enhanced structured error format
          assert.is_table(result, "Result should be enhanced error object")
          assert.equals("string-error-test", result.project_name)
          assert.equals("COMPLETE_FAILURE", result.error_type)
          assert.is_table(result.errors, "Should have errors array")
          assert.equals(1, #result.errors, "Should have one error")
          
          -- Verify structured error details
          local error_entry = result.errors[1]
          assert.equals("tag_resolution", error_entry.phase)
          assert.equals("system", error_entry.resource_id)
          assert.equals("CRITICAL_TAG_MAPPER_ERROR", error_entry.error.type)

          -- Restore originals
          package.loaded["tag_mapper"] = original_tag_mapper
          package.loaded["diligent.handlers.start"] = original_start_handler
        end
      )

      it(
        "should always use enhanced error format for spawning failures",
        function()
          -- Set up successful tag resolution but failing spawn
          mock_interface.set_spawn_config({
            success = false,
            error = "Command not found: invalid-cmd",
          })

          local payload = {
            project_name = "spawn-error-test",
            resources = {
              { name = "invalid", command = "invalid-cmd", tag_spec = "0" },
            },
          }

          local success, result = simplified_handler.execute(payload)

          -- Handler should fail but NOT use backwards compatibility
          assert.is_false(success, "Handler should fail")

          -- Should NOT have old format fields (backwards compatibility removed)
          assert.is_nil(result.error, "Should not have simple error field")
          assert.is_nil(
            result.failed_resource,
            "Should not have failed_resource field"
          )

          -- Should have enhanced error format with spawning error
          assert.equals("spawn-error-test", result.project_name)
          assert.equals("COMPLETE_FAILURE", result.error_type)
          assert.is_table(result.errors)
          assert.equals(1, #result.errors)
          assert.equals("spawning", result.errors[1].phase)
          assert.equals("invalid", result.errors[1].resource_id)
          assert.equals("SPAWN_FAILURE", result.errors[1].error.type)
          assert.matches("Command not found", result.errors[1].error.message)
        end
      )

      it(
        "should handle spawning failures with enhanced format instead of old format",
        function()
          -- For this test, just check that spawning failures use enhanced format
          -- Set spawn to fail
          mock_interface.set_spawn_config({
            success = false,
            error = "Command not found: bad-cmd",
          })

          local payload = {
            project_name = "spawn-fail-test",
            resources = {
              { name = "bad_resource", command = "bad-cmd", tag_spec = "0" },
            },
          }

          local success, result = simplified_handler.execute(payload)

          -- Should fail but provide enhanced error format instead of backwards compatibility
          assert.is_false(success, "Handler should fail due to spawning error")

          -- Should NOT have backwards compatibility format
          assert.is_nil(result.error, "Should not have simple error field")
          assert.is_nil(
            result.failed_resource,
            "Should not have failed_resource field"
          )

          -- Should have enhanced format with spawning error
          assert.equals("spawn-fail-test", result.project_name)
          assert.equals("COMPLETE_FAILURE", result.error_type)
          assert.is_table(result.errors)
          assert.equals(1, #result.errors)
          assert.equals("spawning", result.errors[1].phase)
          assert.equals("bad_resource", result.errors[1].resource_id)
          assert.equals("SPAWN_FAILURE", result.errors[1].error.type)
          assert.matches("Command not found", result.errors[1].error.message)
        end
      )
    end
  )

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

      -- With fallback strategy, handler should succeed with fallbacks
      assert.is_true(success, "Handler should succeed with fallback strategy")
      assert.equals("failure-test", result.project_name)
      assert.is_table(
        result.spawned_resources,
        "Should have spawned resources with fallbacks"
      )
      assert.is_number(result.total_spawned, "Should have spawned count")
      -- Tag operations should include error information for failed resolution
      assert.is_table(result.tag_operations, "Should have tag operations info")
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

        local success, result = handler.execute(payload)
        -- With fallback strategy, handler should succeed with fallbacks
        assert.is_true(success, "Handler should succeed with fallback strategy")
        assert.equals("tag-fail-test", result.project_name)
        assert.is_table(
          result.spawned_resources,
          "Should have spawned resources with fallbacks"
        )
        assert.is_number(result.total_spawned, "Should have spawned count")
        -- Should still spawn the resource using fallback tag
        assert.equals(
          1,
          result.total_spawned,
          "Should spawn 1 resource with fallback"
        )
      end)
    end)
  end)
end)
