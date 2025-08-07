--[[
Core Spawner Module Tests

Tests the core application spawning logic.
--]]

local assert = require("luassert")

describe("awe.spawn.spawner", function()
  local awe
  local mock_interface
  local spawner

  setup(function()
    _G._TEST = true
    awe = require("awe")
  end)

  teardown(function()
    _G._TEST = nil
  end)

  before_each(function()
    mock_interface = awe.interfaces.mock_interface
    mock_interface.reset() -- Ensure clean state for each test
    local spawn = awe.create(mock_interface).spawn
    spawner = spawn.spawner
  end)

  describe("spawn_simple", function()
    it("should be a convenience wrapper for spawn_with_properties", function()
      -- Configure mock to return specific values
      mock_interface.set_spawn_config({
        success = true,
        pid = 1234,
        snid = "snid",
      })

      local pid, snid, msg = spawner.spawn_simple("firefox", "+1")

      -- Verify the interface was called with the expected parameters
      local spawn_call = mock_interface.get_last_spawn_call()
      assert.is_not_nil(spawn_call)

      -- spawn_simple should call spawn_with_properties with empty config
      -- which should result in interface.spawn being called
      assert.is_truthy(spawn_call.command:match("firefox"))

      -- Verify return values match what spawn_with_properties would return
      assert.are.equal(1234, pid)
      assert.are.equal("snid", snid)
      assert.is_truthy(msg:match("SUCCESS"))
      assert.is_truthy(msg:match("firefox"))
      assert.is_truthy(msg:match("1234"))
    end)
  end)

  describe("spawn_with_properties", function()
    it("should handle invalid tag object", function()
      -- Pass invalid tag object (nil) to trigger validation error
      local pid, snid, msg = spawner.spawn_with_properties("firefox", nil, {})

      assert.is_nil(pid)
      assert.is_nil(snid)
      assert.is_truthy(msg:match("Invalid tag object"))
    end)

    it("should handle config being false (JSON quirk)", function()
      -- Create a valid resolved tag object
      local resolved_tag = { index = 2, name = "2" }
      local pid, snid, msg =
        spawner.spawn_with_properties("firefox", resolved_tag, false)

      -- Should not crash and should treat as empty config
      assert.is_not_nil(msg)
    end)

    it("should handle spawn success with mock interface", function()
      -- Configure mock to simulate successful spawn
      mock_interface.set_spawn_config({
        success = true,
        pid = 1234,
        snid = "snid-123",
      })

      -- Create a valid resolved tag object
      local resolved_tag = { index = 3, name = "3" }
      local pid, snid, msg =
        spawner.spawn_with_properties("firefox", resolved_tag, {})

      assert.are.equal(1234, pid)
      assert.are.equal("snid-123", snid)
      assert.is_truthy(msg:match("SUCCESS"))
      assert.is_truthy(msg:match("firefox"))
      assert.is_truthy(msg:match("1234"))
    end)

    it("should handle spawn error with mock interface", function()
      -- Configure mock to simulate spawn error
      mock_interface.set_spawn_config({
        success = false,
        error = "Command not found: firefox",
      })

      -- Create a valid resolved tag object
      local resolved_tag = { index = 1, name = "1" }
      local pid, snid, msg =
        spawner.spawn_with_properties("firefox", resolved_tag, {})

      assert.is_nil(pid)
      assert.is_nil(snid)
      assert.are.equal("Command not found: firefox", msg)
    end)

    it("should build properties and command correctly", function()
      -- Configure mock for successful spawn
      mock_interface.set_spawn_config({
        success = true,
        pid = 1234,
        snid = "snid",
      })

      local config = {
        floating = true,
        width = 800,
        env_vars = { DISPLAY = ":1" },
      }

      -- Create a valid resolved tag object
      local resolved_tag = { index = 2, name = "2" }
      spawner.spawn_with_properties("firefox", resolved_tag, config)

      -- Get the captured spawn call
      local spawn_call = mock_interface.get_last_spawn_call()
      assert.is_not_nil(spawn_call)

      -- Verify command includes environment variables
      assert.is_truthy(spawn_call.command:match("env DISPLAY=:1 firefox"))

      -- Verify properties include tag and config settings
      assert.is_not_nil(spawn_call.properties.tag)
      assert.is_true(spawn_call.properties.floating)
      assert.are.equal(800, spawn_call.properties.width)
    end)

    it("should format success message correctly", function()
      -- Configure mock for specific PID and snid
      mock_interface.set_spawn_config({
        success = true,
        pid = 5678,
        snid = "snid-456",
      })

      -- Create a valid resolved tag object (named tag)
      local resolved_tag = { index = 2, name = "work" }
      local pid, snid, msg =
        spawner.spawn_with_properties("gedit", resolved_tag, {})

      assert.is_truthy(msg:match("SUCCESS"))
      assert.is_truthy(msg:match("gedit"))
      assert.is_truthy(msg:match("5678"))
      assert.is_truthy(msg:match("work")) -- tag name
      assert.is_truthy(msg:match("%[2%]")) -- tag index (mock_interface.create_named_tag returns index 2)
    end)

    it("should handle complex configuration", function()
      -- Configure mock for complex spawn scenario
      mock_interface.set_spawn_config({
        success = true,
        pid = 9999,
        snid = "snid-complex",
      })

      local config = {
        floating = true,
        width = 1024,
        height = 768,
        placement = "centered",
        env_vars = {
          DISPLAY = ":0",
          DILIGENT_PROJECT = "test",
        },
      }

      -- Create a valid resolved tag object
      local resolved_tag = { index = 3, name = "3" }
      local pid, snid, msg =
        spawner.spawn_with_properties("myapp", resolved_tag, config)

      assert.are.equal(9999, pid)

      -- Get the captured spawn call to verify properties
      local spawn_call = mock_interface.get_last_spawn_call()
      assert.is_not_nil(spawn_call)
      assert.is_not_nil(spawn_call.properties.tag)
      assert.is_true(spawn_call.properties.floating)
      assert.are.equal(1024, spawn_call.properties.width)
      assert.are.equal(768, spawn_call.properties.height)
    end)
  end)
end)
