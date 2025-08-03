--[[
Spawn Configuration Module Tests

Tests spawn property building and configuration validation.
--]]

local assert = require("luassert")
local awe = require("awe")

describe("awe.spawn.configuration", function()
  local mock_interface
  local configuration

  before_each(function()
    mock_interface = awe.interfaces.mock_interface
    local spawn = awe.create(mock_interface).spawn
    configuration = spawn.configuration
  end)

  describe("build_spawn_properties", function()
    it(
      "should return empty table when tag is nil and config is empty",
      function()
        local result = configuration.build_spawn_properties(nil, {})
        assert.are.same({}, result)
      end
    )

    it("should include tag when provided", function()
      local mock_tag = { name = "test", index = 1 }
      local result = configuration.build_spawn_properties(mock_tag, {})
      assert.are.equal(mock_tag, result.tag)
    end)

    it("should set floating property when config.floating is true", function()
      local result =
        configuration.build_spawn_properties(nil, { floating = true })
      assert.is_true(result.floating)
    end)

    it(
      "should not set floating property when config.floating is false",
      function()
        local result =
          configuration.build_spawn_properties(nil, { floating = false })
        assert.is_nil(result.floating)
      end
    )

    it("should set placement property when provided", function()
      -- Mock awful.placement for testing
      local mock_awful = {
        placement = {
          centered = function() end,
          top_left = function() end,
        },
      }

      -- We'll just test the key assignment since we can't fully mock awful
      local result =
        configuration.build_spawn_properties(nil, { placement = "centered" })
      assert.is_not_nil(result.placement)
    end)

    it("should set width when provided", function()
      local result = configuration.build_spawn_properties(nil, { width = 800 })
      assert.are.equal(800, result.width)
    end)

    it("should set height when provided", function()
      local result = configuration.build_spawn_properties(nil, { height = 600 })
      assert.are.equal(600, result.height)
    end)

    it("should combine all properties", function()
      local mock_tag = { name = "work", index = 2 }
      local config = {
        floating = true,
        width = 1024,
        height = 768,
        placement = "centered",
      }

      local result = configuration.build_spawn_properties(mock_tag, config)

      assert.are.equal(mock_tag, result.tag)
      assert.is_true(result.floating)
      assert.are.equal(1024, result.width)
      assert.are.equal(768, result.height)
      assert.is_not_nil(result.placement)
    end)

    it("should handle numeric strings for dimensions", function()
      local config = {
        width = "800",
        height = "600",
      }

      local result = configuration.build_spawn_properties(nil, config)
      assert.are.equal("800", result.width)
      assert.are.equal("600", result.height)
    end)

    it("should ignore unknown configuration options", function()
      local config = {
        unknown_option = "should_be_ignored",
        floating = true,
      }

      local result = configuration.build_spawn_properties(nil, config)
      assert.is_true(result.floating)
      assert.is_nil(result.unknown_option)
    end)
  end)
end)
