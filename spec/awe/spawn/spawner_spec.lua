--[[
Core Spawner Module Tests

Tests the core application spawning logic.
--]]

local assert = require("luassert")
local awe = require("awe")

describe("awe.spawn.spawner", function()
  local mock_interface
  local spawner

  before_each(function()
    mock_interface = awe.interfaces.mock_interface
    local spawn = awe.create(mock_interface).spawn
    spawner = spawn.spawner
  end)

  describe("spawn_simple", function()
    it("should be a convenience wrapper for spawn_with_properties", function()
      -- Mock spawn_with_properties to verify it's called
      local original_spawn = spawner.spawn_with_properties
      local called_with = nil
      spawner.spawn_with_properties = function(app, tag_spec, config)
        called_with = { app, tag_spec, config }
        return 1234, "snid", "test message"
      end

      local pid, snid, msg = spawner.spawn_simple("firefox", "+1")

      assert.are.same({ "firefox", "+1", {} }, called_with)
      assert.are.equal(1234, pid)
      assert.are.equal("snid", snid)
      assert.are.equal("test message", msg)

      -- Restore original function
      spawner.spawn_with_properties = original_spawn
    end)
  end)

  describe("spawn_with_properties", function()
    local mock_awesome_client_manager

    before_each(function()
      -- Mock awesome_client_manager functions that spawner depends on
      mock_awesome_client_manager = {
        resolve_tag_spec = function(tag_spec)
          if tag_spec == "invalid" then
            return nil, "Invalid tag"
          else
            return { name = "test", index = 1 }, "Resolved successfully"
          end
        end,
      }

      -- Inject mock into interface for spawner to use
      mock_interface.awesome_client_manager = mock_awesome_client_manager
    end)

    it("should handle tag resolution failure", function()
      local pid, snid, msg =
        spawner.spawn_with_properties("firefox", "invalid", {})

      assert.is_nil(pid)
      assert.is_nil(snid)
      assert.is_truthy(msg:match("Tag resolution failed"))
    end)

    it("should handle config being false (JSON quirk)", function()
      local pid, snid, msg =
        spawner.spawn_with_properties("firefox", "+1", false)

      -- Should not crash and should treat as empty config
      assert.is_not_nil(msg)
    end)

    it("should handle spawn success with mock interface", function()
      -- For successful spawn, we need to properly mock the spawn behavior
      mock_interface.spawn = function(command, properties)
        -- Mock successful spawn
        return 1234, "snid-123"
      end

      local pid, snid, msg = spawner.spawn_with_properties("firefox", "+1", {})

      assert.are.equal(1234, pid)
      assert.are.equal("snid-123", snid)
      assert.is_truthy(msg:match("SUCCESS"))
      assert.is_truthy(msg:match("firefox"))
      assert.is_truthy(msg:match("1234"))
    end)

    it("should handle spawn error with mock interface", function()
      -- Mock spawn error
      mock_interface.spawn = function(command, properties)
        return "Command not found: firefox"
      end

      local pid, snid, msg = spawner.spawn_with_properties("firefox", "+1", {})

      assert.is_nil(pid)
      assert.is_nil(snid)
      assert.are.equal("Command not found: firefox", msg)
    end)

    it("should build properties and command correctly", function()
      local captured_command = nil
      local captured_properties = nil

      mock_interface.spawn = function(command, properties)
        captured_command = command
        captured_properties = properties
        return 1234, "snid"
      end

      local config = {
        floating = true,
        width = 800,
        env_vars = { DISPLAY = ":1" },
      }

      spawner.spawn_with_properties("firefox", "+1", config)

      -- Verify command includes environment variables
      assert.is_truthy(captured_command:match("env DISPLAY=:1 firefox"))

      -- Verify properties include tag and config settings
      assert.is_not_nil(captured_properties.tag)
      assert.is_true(captured_properties.floating)
      assert.are.equal(800, captured_properties.width)
    end)

    it("should format success message correctly", function()
      mock_interface.spawn = function(command, properties)
        return 5678, "snid-456"
      end

      local pid, snid, msg = spawner.spawn_with_properties("gedit", "work", {})

      assert.is_truthy(msg:match("SUCCESS"))
      assert.is_truthy(msg:match("gedit"))
      assert.is_truthy(msg:match("5678"))
      assert.is_truthy(msg:match("test")) -- tag name
      assert.is_truthy(msg:match("%[1%]")) -- tag index
    end)

    it("should handle complex configuration", function()
      local captured_properties = nil

      mock_interface.spawn = function(command, properties)
        captured_properties = properties
        return 9999, "snid-complex"
      end

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

      local pid, snid, msg =
        spawner.spawn_with_properties("myapp", "+2", config)

      assert.are.equal(9999, pid)
      assert.is_not_nil(captured_properties.tag)
      assert.is_true(captured_properties.floating)
      assert.are.equal(1024, captured_properties.width)
      assert.are.equal(768, captured_properties.height)
    end)
  end)
end)
