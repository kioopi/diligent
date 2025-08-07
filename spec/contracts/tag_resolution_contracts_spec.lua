local assert = require("luassert")

describe("Tag Resolution Contracts", function()
  local mock_interface
  local start_handler
  local awe

  before_each(function()
    _G._TEST = true
    mock_interface = require("awe.interfaces.mock_interface")
    mock_interface.reset()
    start_handler = require("diligent.handlers.start")
    awe = require("awe")
  end)

  teardown(function()
    _G._TEST = nil
  end)

  describe("DSL Processor Contract", function()
    it(
      "start_processor output should provide tag_spec for handler consumption",
      function()
        -- Contract: start_processor must provide tag_spec for handler to resolve via tag_mapper
        local dsl_project = {
          name = "contract-test",
          resources = {
            app1 = {
              type = "app",
              cmd = "test-app",
              tag = 2, -- relative offset
            },
          },
        }

        local start_processor = require("dsl.start_processor")
        local start_request =
          start_processor.convert_project_to_start_request(dsl_project)

        local resource = start_request.resources[1]
        assert.is_not_nil(
          resource.tag_spec,
          "Contract violation: missing tag_spec"
        )
        assert.are.equal(
          2,
          resource.tag_spec,
          "Contract violation: incorrect tag_spec value"
        )

        -- tag_info should NOT be present - handler will resolve via tag_mapper
        assert.is_nil(
          resource.tag_info,
          "Contract violation: tag_info should not be present - handler resolves via tag_mapper"
        )
      end
    )
  end)

  describe("Start Handler Contract", function()
    it("handler MUST use tag_mapper to resolve tag_spec", function()
      -- Test that handler resolves tag_spec via tag_mapper, not parsing internally
      mock_interface.set_current_tag_index(5) -- User on tag 5

      local payload = {
        project_name = "contract-test",
        resources = {
          {
            name = "test-app",
            command = "test-command",
            tag_spec = 2, -- Handler should resolve this via tag_mapper
            -- No tag_info - handler must resolve via tag_mapper
          },
        },
      }

      local mock_awe = awe.create(mock_interface)
      local handler = start_handler.create(mock_awe)
      local success, result = handler.execute(payload)

      assert.is_true(success, "Handler execution failed")

      local spawn_call = mock_interface.get_last_spawn_call()

      -- CRITICAL CONTRACT TEST: Handler must use tag_mapper to resolve tag_spec
      assert.are.equal(
        7,
        spawn_call.properties.tag.index,
        "Handler must resolve relative tag_spec via tag_mapper (expected 5+2=7)"
      )
    end)

    it("handler should resolve absolute tag_spec correctly", function()
      -- Test absolute tag resolution via tag_mapper
      mock_interface.set_current_tag_index(3)

      local payload = {
        project_name = "absolute-tag-test",
        resources = {
          {
            name = "absolute-app",
            command = "absolute-command",
            tag_spec = "5", -- Absolute tag string - should resolve to tag 5
          },
        },
      }

      local mock_awe = awe.create(mock_interface)
      local handler = start_handler.create(mock_awe)
      local success, result = handler.execute(payload)

      assert.is_true(success, "Handler execution should succeed")

      local spawn_call = mock_interface.get_last_spawn_call()
      assert.are.equal(
        5,
        spawn_call.properties.tag.index,
        "Handler should resolve absolute tag '5' to tag 5 regardless of current tag"
      )
    end)
  end)

  describe("End-to-End Contract Verification", function()
    it("complete pipeline should preserve tag resolution semantics", function()
      -- Test that demonstrates the full contract from DSL to spawning
      mock_interface.set_current_tag_index(1) -- User on tag 1

      -- Create a scenario that would expose tag_spec vs tag_info usage
      local dsl_str = [[
        local function app(spec)
          return {
            type = "app",
            cmd = spec.cmd,
            tag = spec.tag or 0
          }
        end

        return {
          name = "contract-verification",
          resources = {
            test_app = app { cmd = "contract-test", tag = 3 } -- relative +3
          }
        }
      ]]

      local parser = require("dsl.parser")
      local start_processor = require("dsl.start_processor")

      local success, dsl = parser.compile_dsl(dsl_str)
      assert.is_true(success)

      local start_request =
        start_processor.convert_project_to_start_request(dsl)

      -- Verify the contract at each stage
      local resource = start_request.resources[1]
      local mock_awe = awe.create(mock_interface)
      local handler = start_handler.create(mock_awe)
      local exec_success, result = handler.execute(start_request)

      assert.is_true(exec_success)

      local spawn_call = mock_interface.get_last_spawn_call()
      assert.are.equal(
        4,
        spawn_call.properties.tag.index,
        "End-to-end contract: relative tag 3 from current tag 1 should resolve to tag 4"
      )
    end)
  end)
end)
