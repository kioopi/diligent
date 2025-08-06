local assert = require("luassert")

local parser = require("dsl.parser")
local start_processor = require("dsl.start_processor")

describe("Start Command Full Pipeline Integration", function()
  local mock_interface
  local start_handler
  local awe

  before_each(function()
    _G._TEST = true
    mock_interface = require("awe.interfaces.mock_interface")
    mock_interface.reset()
    start_handler = require("diligent.handlers.start")
    awe = require("awe").create(mock_interface)
  end)

  teardown(function()
    _G._TEST = nil
  end)

  describe("DSL → Processor → Handler → Spawner Pipeline", function()
    it("should resolve relative tag_spec via tag_mapper correctly", function()
      -- SETUP: User on tag 3, DSL with relative tag +1 (should resolve to tag 4)
      mock_interface.set_current_tag_index(3)

      -- REAL DSL processing (not mock payload)
      local dsl_str = [[
        return {
          name = "pipeline-test",
          resources = {
            editor = app { cmd = "gedit", tag = 1 }  -- relative +1
          }
        }
      ]]

      -- Full pipeline: DSL → Processor → Handler → Spawner

      local dsl = assert.success(parser.compile_dsl(dsl_str))
      local start_request =
        start_processor.convert_project_to_start_request(dsl)

      -- Verify DSL processor provides tag_spec (no tag_info)
      local resource = start_request.resources[1]
      assert.are.equal("editor", resource.name)
      assert.are.equal(1, resource.tag_spec, "Raw tag_spec should be 1")
      assert.is_nil(
        resource.tag_info,
        "tag_info should not be present - handler resolves via tag_mapper"
      )

      -- Execute through handler
      local handler = start_handler.create(awe)
      local result = assert.success(handler.execute(start_request))

      -- CRITICAL TEST: Verify spawner receives resolved tag (4) via tag_mapper
      local spawn_call = mock_interface.get_last_spawn_call()
      assert.is_not_nil(spawn_call, "No spawn call recorded")
      assert.is_not_nil(spawn_call.properties, "Spawn call missing properties")
      assert.is_not_nil(
        spawn_call.properties.tag,
        "Spawn call missing tag property"
      )

      assert.are.equal(
        4,
        spawn_call.properties.tag.index,
        "Handler must resolve relative tag_spec via tag_mapper. "
          .. "Expected resolved tag 4 (current 3 + offset 1), but got: "
          .. tostring(spawn_call.properties.tag.index)
      )
    end)

    it("should handle absolute tags correctly through full pipeline", function()
      -- SETUP: User on tag 2, DSL with absolute tag "5"
      mock_interface.set_current_tag_index(2)

      local dsl_str = [[
        return {
          name = "absolute-test",
          resources = {
            browser = app { cmd = "firefox", tag = "5" }  -- absolute tag 5
          }
        }
      ]]

      local dsl = assert.success(parser.compile_dsl(dsl_str))
      local start_request =
        start_processor.convert_project_to_start_request(dsl)
      local resource = start_request.resources[1]

      -- Verify DSL processor provides tag_spec (no tag_info)
      assert.are.equal("5", resource.tag_spec, "Raw tag_spec should be '5'")
      assert.is_nil(
        resource.tag_info,
        "tag_info should not be present - handler resolves via tag_mapper"
      )

      -- Execute through handler
      local handler = start_handler.create(awe)
      local result = assert.success(handler.execute(start_request))

      -- Verify spawner receives absolute tag 5 (not affected by current tag 2)
      local spawn_call = mock_interface.get_last_spawn_call()
      assert.are.equal(
        5,
        spawn_call.properties.tag.index,
        "Absolute tag should resolve to tag 5 regardless of current tag, got: "
          .. tostring(spawn_call.properties.tag.index)
      )
    end)

    it("should handle named tags correctly through full pipeline", function()
      -- SETUP: User on tag 1, DSL with named tag "editor"
      mock_interface.set_current_tag_index(1)

      local dsl_str = [[
        return {
          name = "named-test",
          resources = {
            editor = app { cmd = "gedit", tag = "editor" }  -- named tag
          }
        }
      ]]

      local dsl = assert.success(parser.compile_dsl(dsl_str))

      local start_request =
        start_processor.convert_project_to_start_request(dsl)
      local resource = start_request.resources[1]

      -- Verify DSL processor provides tag_spec (no tag_info)
      assert.are.equal(
        "editor",
        resource.tag_spec,
        "Raw tag_spec should be 'editor'"
      )
      assert.is_nil(
        resource.tag_info,
        "tag_info should not be present - handler resolves via tag_mapper"
      )

      -- Execute through handler
      local handler = start_handler.create(awe)
      local result = assert.success(handler.execute(start_request))

      -- Verify spawner receives named tag (mock creates index 2 for new named tags)
      local spawn_call = mock_interface.get_last_spawn_call()
      assert.are.equal(
        "editor",
        spawn_call.properties.tag.name,
        "Named tag should have correct name, got: "
          .. tostring(spawn_call.properties.tag.name)
      )
    end)

    it(
      "should demonstrate correct tag resolution from user's scenario",
      function()
        -- SETUP: This replicates the user's exact scenario - now fixed
        mock_interface.set_current_tag_index(2) -- User is on tag 2

        local dsl_str = [[
        return {
          name = "fun",
          resources = {
            arandr = app { cmd = "arandr", tag = 2 }  -- relative +2, should go to tag 4
          }
        }
      ]]

        local dsl = assert.success(parser.compile_dsl(dsl_str))
        local start_request =
          start_processor.convert_project_to_start_request(dsl)

        -- Verify processor provides only tag_spec
        local resource = start_request.resources[1]
        assert.are.equal(2, resource.tag_spec, "Tag spec should be 2")
        assert.is_nil(resource.tag_info, "tag_info should not be present")

        -- Execute through handler
        local handler = start_handler.create(awe)
        local exec_success, result = handler.execute(start_request)

        -- Verify correct resolution via tag_mapper
        local spawn_call = mock_interface.get_last_spawn_call()
        assert.are.equal(
          4,
          spawn_call.properties.tag.index,
          "arandr with tag=2 on current tag 2 should spawn on tag 4 (2+2), "
            .. "got tag "
            .. tostring(spawn_call.properties.tag.index)
            .. ". "
            .. "Handler correctly uses tag_mapper to resolve tag_spec!"
        )
      end
    )
  end)
end)
