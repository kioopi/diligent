local assert = require("luassert")
local helpers = require("dsl.helpers.init")

describe("dsl.helpers.init", function()
  after_each(function()
    -- Reset registry after each test
    helpers._clear_registry()
  end)

  describe("built-in helpers", function()
    it("should have app helper registered by default", function()
      local app_helper = helpers.get("app")

      assert.is_function(app_helper)
    end)

    it("should have term helper registered by default", function()
      local term_helper = helpers.get("term")

      assert.is_function(term_helper)
    end)

    it("should list built-in helpers", function()
      local helper_names = helpers.list()

      assert.is_table(helper_names)
      assert.are.same({ "app", "term" }, helper_names)
    end)
  end)

  describe("register", function()
    it("should register new helper function", function()
      local test_helper = function(spec)
        return { type = "test" }
      end

      helpers.register("test", test_helper)

      local registered = helpers.get("test")
      assert.are.equal(test_helper, registered)
    end)

    it("should include registered helpers in list", function()
      local test_helper = function(spec)
        return { type = "test" }
      end
      helpers.register("test", test_helper)

      local helper_names = helpers.list()

      assert.is_table(helper_names)
      -- Should be sorted alphabetically
      assert.are.same({ "app", "term", "test" }, helper_names)
    end)

    it("should validate helper name is string", function()
      local test_helper = function(spec)
        return { type = "test" }
      end

      assert.has_error(function()
        helpers.register(123, test_helper)
      end, "helper name must be a string")
    end)

    it("should validate helper name is not empty", function()
      local test_helper = function(spec)
        return { type = "test" }
      end

      assert.has_error(function()
        helpers.register("", test_helper)
      end, "helper name is required")
    end)

    it("should validate helper name format", function()
      local test_helper = function(spec)
        return { type = "test" }
      end

      local success, err = pcall(function()
        helpers.register("invalid-name", test_helper)
      end)

      assert.is_false(success)
      assert.matches("helper name must be a valid Lua identifier", err)
    end)

    it("should validate helper is function", function()
      assert.has_error(function()
        helpers.register("test", "not a function")
      end, "helper must be a function")
    end)

    it("should prevent duplicate registration", function()
      local test_helper1 = function(spec)
        return { type = "test1" }
      end
      local test_helper2 = function(spec)
        return { type = "test2" }
      end

      helpers.register("test", test_helper1)

      assert.has_error(function()
        helpers.register("test", test_helper2)
      end, "helper 'test' is already registered")
    end)

    it("should prevent overriding built-in helpers", function()
      local custom_app = function(spec)
        return { type = "custom" }
      end

      assert.has_error(function()
        helpers.register("app", custom_app)
      end, "helper 'app' is already registered")
    end)
  end)

  describe("get", function()
    it("should return nil for unknown helper", function()
      local helper = helpers.get("unknown")

      assert.is_nil(helper)
    end)

    it("should return registered helper", function()
      local test_helper = function(spec)
        return { type = "test" }
      end
      helpers.register("test", test_helper)

      local retrieved = helpers.get("test")

      assert.are.equal(test_helper, retrieved)
    end)
  end)

  describe("get_schema", function()
    it("should return app schema", function()
      local schema = helpers.get_schema("app")

      assert.is_table(schema)
      assert.are.same({ "cmd" }, schema.required)
      assert.are.same({ "dir", "tag", "reuse" }, schema.optional)
    end)

    it("should return term schema", function()
      local schema = helpers.get_schema("term")

      assert.is_table(schema)
      assert.are.same({ "cmd" }, schema.required)
      assert.are.same(
        { "dir", "tag", "interactive", "terminal" },
        schema.optional
      )
    end)

    it("should return nil for unknown helper", function()
      local schema = helpers.get_schema("unknown")

      assert.is_nil(schema)
    end)
  end)

  describe("validate_resource", function()
    it("should validate app resource", function()
      local resource_spec = {
        cmd = "gedit",
        tag = 1,
      }

      local success, error_msg = helpers.validate_resource(resource_spec, "app")

      assert.is_true(success)
      assert.is_nil(error_msg)
    end)

    it("should return error for invalid app resource", function()
      local resource_spec = {
        -- Missing required cmd field
        tag = 1,
      }

      local success, error_msg = helpers.validate_resource(resource_spec, "app")

      assert.is_false(success)
      assert.is_string(error_msg)
      assert.matches("cmd field is required", error_msg)
    end)

    it("should validate term resource", function()
      local resource_spec = {
        cmd = "bash",
        terminal = "xterm",
      }

      local success, error_msg =
        helpers.validate_resource(resource_spec, "term")

      assert.is_true(success)
      assert.is_nil(error_msg)
    end)

    it("should return error for invalid term resource", function()
      local resource_spec = {
        -- Missing required cmd field
        terminal = "xterm",
      }

      local success, error_msg =
        helpers.validate_resource(resource_spec, "term")

      assert.is_false(success)
      assert.is_string(error_msg)
      assert.matches("cmd field is required", error_msg)
    end)

    it("should return error for unknown resource type", function()
      local resource_spec = {
        cmd = "test",
      }

      local success, error_msg =
        helpers.validate_resource(resource_spec, "unknown")

      assert.is_false(success)
      assert.matches("unknown resource type: unknown", error_msg)
    end)
  end)

  describe("create_env", function()
    it("should create environment with basic Lua functions", function()
      local env = helpers.create_env()

      assert.is_function(env.pairs)
      assert.is_function(env.ipairs)
      assert.is_function(env.type)
      assert.is_function(env.tostring)
      assert.is_table(env.table)
      assert.is_table(env.string)
      assert.is_table(env.math)
    end)

    it("should include built-in helpers", function()
      local env = helpers.create_env()

      assert.is_function(env.app)
      assert.is_function(env.term)
    end)

    it("should include registered helpers", function()
      local test_helper = function(spec)
        return { type = "test" }
      end
      helpers.register("test", test_helper)

      local env = helpers.create_env()

      assert.is_function(env.test)
      assert.are.equal(test_helper, env.test)
    end)

    it("should not include unsafe functions", function()
      local env = helpers.create_env()

      -- These should not be available in sandbox
      assert.is_nil(env.io)
      assert.is_nil(env.os)
      assert.is_nil(env.require)
      assert.is_nil(env.dofile)
      assert.is_nil(env.loadfile)
      assert.is_nil(env.load)
    end)

    it("should work with DSL execution", function()
      local env = helpers.create_env()

      -- Simulate DSL execution
      local dsl_code = [[
        return {
          name = "test-project",
          resources = {
            editor = app {
              cmd = "gedit",
              tag = 1
            }
          }
        }
      ]]

      local chunk = load(dsl_code, "test", "t", env)
      assert.is_function(chunk)

      local result = chunk()
      assert.is_table(result)
      assert.are.equal("test-project", result.name)
      assert.is_table(result.resources.editor)
      assert.are.equal("app", result.resources.editor.type)
      assert.are.equal("gedit", result.resources.editor.cmd)
    end)

    it("should work with term in DSL execution", function()
      local env = helpers.create_env()

      -- Simulate DSL execution with term helper
      local dsl_code = [[
        return {
          name = "test-project",
          resources = {
            terminal = term {
              cmd = "bash",
              tag = 2
            }
          }
        }
      ]]

      local chunk = load(dsl_code, "test", "t", env)
      assert.is_function(chunk)

      local result = chunk()
      assert.is_table(result)
      assert.are.equal("test-project", result.name)
      assert.is_table(result.resources.terminal)
      assert.are.equal("term", result.resources.terminal.type)
      assert.are.equal("bash", result.resources.terminal.cmd)
      assert.are.equal(2, result.resources.terminal.tag)
    end)
  end)

  describe("list", function()
    it("should return sorted list of helpers", function()
      local helper1 = function() end
      local helper2 = function() end

      helpers.register("zebra", helper1)
      helpers.register("alpha", helper2)

      local names = helpers.list()

      -- Should be sorted alphabetically
      assert.are.same({ "alpha", "app", "term", "zebra" }, names)
    end)
  end)
end)
