--[[
Spawn Module Factory Tests

Tests the factory pattern for spawn modules with dependency injection.
--]]

local assert = require("luassert")

describe("awe.spawn factory", function()
  local awe
  local mock_interface
  local create_spawn

  setup(function()
    _G._TEST = true
    awe = require("awe")
  end)

  teardown(function()
    _G._TEST = nil
  end)

  before_each(function()
    mock_interface = awe.interfaces.mock_interface
    create_spawn = require("awe.spawn")
  end)

  describe("factory function", function()
    it("should be a function", function()
      assert.is_function(create_spawn)
    end)

    it("should return spawn modules when called with interface", function()
      local spawn = create_spawn(mock_interface)

      assert.is_table(spawn)
      assert.is_table(spawn.environment)
      assert.is_table(spawn.configuration)
      assert.is_table(spawn.spawner)
    end)

    it("should create independent instances", function()
      local spawn1 = create_spawn(mock_interface)
      local spawn2 = create_spawn(mock_interface)

      assert.are_not.equal(spawn1, spawn2)
      assert.are_not.equal(spawn1.environment, spawn2.environment)
    end)
  end)

  describe("module structure", function()
    local spawn

    before_each(function()
      spawn = create_spawn(mock_interface)
    end)

    it("should have environment module with expected functions", function()
      assert.is_function(spawn.environment.build_command_with_env)
    end)

    it("should have configuration module with expected functions", function()
      assert.is_function(spawn.configuration.build_spawn_properties)
    end)

    it("should have spawner module with expected functions", function()
      assert.is_function(spawn.spawner.spawn_with_properties)
      assert.is_function(spawn.spawner.spawn_simple)
    end)
  end)
end)
