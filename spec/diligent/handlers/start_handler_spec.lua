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
      local success, result = handler.execute(payload)

      assert.is_true(success)
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
      local success, result = handler.execute(payload)

      assert.is_false(success)
      assert.are.equal("bad-app", result.failed_resource)
      assert.matches("Command not found", result.error)
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
end)
