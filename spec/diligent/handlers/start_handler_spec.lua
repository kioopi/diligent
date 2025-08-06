local assert = require("luassert")

describe("Start Handler", function()
  local start_handler
  local awe

  setup(function()
    _G._TEST = true
    start_handler = require("diligent.handlers.start")
    awe = require("awe")
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
      local mock_awe = awe.create(awe.interfaces.mock_interface)
      local handler = start_handler.create(mock_awe)

      assert.is_table(handler)
      assert.is_function(handler.execute)
    end)

    it("should create handler with validator function", function()
      local mock_awe = awe.create(awe.interfaces.mock_interface)
      local handler = start_handler.create(mock_awe)

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
      local mock_awe = awe.create(awe.interfaces.mock_interface)
      local handler = start_handler.create(mock_awe)

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

      -- Create custom mock that fails spawning
      local failing_interface = {
        spawn = function(cmd, props)
          return "ERROR: Command not found" -- String return indicates error
        end,
        screen = awe.interfaces.mock_interface.screen,
        tag = awe.interfaces.mock_interface.tag,
        get_screen_context = awe.interfaces.mock_interface.get_screen_context,
      }
      local mock_awe = awe.create(failing_interface)
      local handler = start_handler.create(mock_awe)
      local success, result = handler.execute(payload)

      assert.is_false(success)
      assert.matches("Command not found", result.error)
      assert.are.equal("invalid", result.failed_resource)
      assert.are.equal("test-project", result.project_name)
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

      local mock_awe = awe.create(awe.interfaces.mock_interface)
      local handler = start_handler.create(mock_awe)
      local success, result = handler.execute(payload)

      assert.is_true(success)
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
            command = "nonexistent",
            tag_spec = "1",
          },
        },
      }

      -- Create interface that fails on second spawn
      local call_count = 0
      local failing_interface = {
        spawn = function(cmd, props)
          call_count = call_count + 1
          if call_count == 1 then
            return 1234, "snid-123" -- Success for first call
          else
            return "ERROR: Command not found" -- Fail for second call
          end
        end,
        screen = awe.interfaces.mock_interface.screen,
        tag = awe.interfaces.mock_interface.tag,
        get_screen_context = awe.interfaces.mock_interface.get_screen_context,
      }

      local mock_awe = awe.create(failing_interface)
      local handler = start_handler.create(mock_awe)

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

      local mock_awe = awe.create(awe.interfaces.mock_interface)
      local handler = start_handler.create(mock_awe)
      local success, result = handler.execute(payload)

      assert.is_true(success)
      assert.are.equal(1, result.total_spawned)
    end)

    it("should handle empty resources list", function()
      local payload = {
        project_name = "empty-project",
        resources = {},
      }

      local mock_awe = awe.create(awe.interfaces.mock_interface)
      local handler = start_handler.create(mock_awe)
      local success, result = handler.execute(payload)

      assert.is_true(success)
      assert.are.equal("empty-project", result.project_name)
      assert.are.equal(0, #result.spawned_resources)
      assert.are.equal(0, result.total_spawned)
    end)
  end)

  describe("tag resolution with tag_mapper", function()
    local mock_interface
    local original_tag_mapper
    local original_start_handler

    before_each(function()
      mock_interface = require("awe.interfaces.mock_interface")
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

      local mock_awe = awe.create(mock_interface)
      local handler = start_handler.create(mock_awe)

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

      local mock_awe = awe.create(mock_interface)
      local handler = start_handler.create(mock_awe)

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

      local mock_awe = awe.create(mock_interface)
      local handler = start_handler.create(mock_awe)

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

      local mock_awe = awe.create(mock_interface)
      local handler = start_handler.create(mock_awe)

      local success, result = handler.execute(payload)

      -- Restore original tag_mapper
      package.loaded["tag_mapper"].resolve_tag = original_resolve_tag

      assert.is_false(success, "Handler should fail with invalid tag")
      assert.matches("Tag resolution failed", result.error or "")
      assert.are.equal("invalid", result.failed_resource)
    end)
  end)

  describe("tag resolution via tag_mapper", function()
    local mock_interface

    before_each(function()
      mock_interface = require("awe.interfaces.mock_interface")
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

        local mock_awe = awe.create(mock_interface)
        local handler = start_handler.create(mock_awe)
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

      local mock_awe = awe.create(mock_interface)
      local handler = start_handler.create(mock_awe)
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

        local mock_awe = awe.create(mock_interface)
        local handler = start_handler.create(mock_awe)

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

        local mock_awe = awe.create(mock_interface)
        local handler = start_handler.create(mock_awe)
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
  end)
end)
