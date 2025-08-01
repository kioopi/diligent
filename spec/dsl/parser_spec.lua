local assert = require("luassert")
local lfs = require("lfs")
local P = require("pl.path")
local F = require("pl.file")
local dir = require("pl.dir")
local parser = require("dsl.parser")

-- Mock the file system for testing
local function create_temp_dsl_file(filename, content)
  local temp_dir = "/tmp/diligent-test-dsl/"
  lfs.mkdir(temp_dir)
  local filepath = temp_dir .. filename
  F.write(filepath, content)
  return filepath
end

local function create_temp_conf_dir(project_name)
  local tmp_home = "/tmp/diligenthome/"

  local project_dir = P.join(tmp_home, ".config", "diligent", "projects")
  dir.makepath(project_dir)
  if project_name then
    local filepath = P.join(project_dir, project_name .. ".lua")
    F.write(
      filepath,
      "return { name = '" .. project_name .. "', resources = {} }"
    )
  end
  return tmp_home
end

local function cleanup_temp_files()
  os.execute("rm -rf /tmp/diligent-test-dsl/")
  os.execute("rm -rf /tmp/diligenthome/")
end

describe("dsl.parser", function()
  after_each(function()
    cleanup_temp_files()
  end)

  describe("load_dsl_file", function()
    it("should load valid DSL file with required fields", function()
      local dsl_content = [[
return {
  name = "test-project",
  resources = {
    editor = app {
      cmd = "gedit",
      dir = "/tmp",
      tag = 0,
    },
  },
}
]]
      local filepath = create_temp_dsl_file("valid.lua", dsl_content)

      local success, result = parser.load_dsl_file(filepath)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal("test-project", result.name)
      assert.is_table(result.resources)
      assert.is_table(result.resources.editor)
      assert.are.equal("app", result.resources.editor.type)
    end)

    it("should return error for non-existent file", function()
      local filename = "/non/existent/file.lua"
      local success, result = parser.load_dsl_file(filename)

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("file not found: " .. filename, result)
    end)

    it("should handle nil file path", function()
      local success, result = parser.load_dsl_file(nil)

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("file path is required", result)
    end)

    it("should handle empty file path", function()
      local success, result = parser.load_dsl_file("")

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("file path is required", result)
    end)
  end)

  describe("compile_dsl", function()
    it("should compile valid DSL with app helper", function()
      local dsl_content = [[
return {
  name = "test-project",
  resources = {
    editor = app {
      cmd = "gedit",
      tag = 1,
    },
  },
}
]]
      local success, result = parser.compile_dsl(dsl_content, "test.lua")

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal("test-project", result.name)
      assert.is_table(result.resources.editor)
      assert.are.equal("app", result.resources.editor.type)
      assert.are.equal("gedit", result.resources.editor.cmd)
      assert.are.equal(1, result.resources.editor.tag)
    end)

    it("should return error for malformed Lua syntax", function()
      local dsl_content = [[
return {
  name = "test-project"  -- missing comma
  resources = {}
}
]]
      local success, result = parser.compile_dsl(dsl_content, "malformed.lua")

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("syntax error", result)
    end)

    it("should return error for DSL that doesn't return table", function()
      local dsl_content = [[
-- This DSL returns a string instead of a table
return "not a table"
]]
      local success, result = parser.compile_dsl(dsl_content, "no-table.lua")

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("must return a table", result)
    end)

    it("should return error for execution errors", function()
      local dsl_content = [[
-- This will cause a runtime error
error("intentional test error")
return {
  name = "test",
  resources = {}
}
]]
      local success, result =
        parser.compile_dsl(dsl_content, "runtime-error.lua")

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("execution error", result)
    end)

    it("should handle nil DSL string", function()
      local success, result = parser.compile_dsl(nil, "test.lua")

      assert.is_false(success)
      assert.matches("DSL string is required", result)
    end)

    it("should work without filepath parameter", function()
      local dsl_content = [[
return {
  name = "test",
  resources = {}
}
]]
      local success, result = parser.compile_dsl(dsl_content)

      assert.is_true(success)
      assert.is_table(result)
    end)
  end)

  describe("create_dsl_env", function()
    it("should create environment with basic Lua functions", function()
      local env = parser.create_dsl_env()

      assert.is_function(env.pairs)
      assert.is_function(env.ipairs)
      assert.is_function(env.type)
      assert.is_function(env.tostring)
      assert.is_table(env.table)
      assert.is_table(env.string)
      assert.is_table(env.math)
    end)

    it("should include app helper", function()
      local env = parser.create_dsl_env()

      assert.is_function(env.app)
    end)

    it("should not include unsafe functions", function()
      local env = parser.create_dsl_env()

      -- These should not be available in sandbox
      assert.is_nil(env.io)
      assert.is_nil(env.os)
      assert.is_nil(env.require)
      assert.is_nil(env.dofile)
      assert.is_nil(env.loadfile)
      assert.is_nil(env.load)
    end)
  end)

  describe("resolve_config_path", function()
    it("should resolve project name to config file path", function()
      local home = create_temp_conf_dir("test-project")
      local expected_path =
        P.join(home, ".config/diligent/projects/test-project.lua")

      local result, err = parser.resolve_config_path("test-project", home)

      assert.are.equal(expected_path, result)
      assert.is_nil(err)
    end)

    it("should handle project names with special characters", function()
      local home = create_temp_conf_dir("my-awesome_project")
      local expected_path =
        P.join(home, ".config/diligent/projects/my-awesome_project.lua")

      local result, err = parser.resolve_config_path("my-awesome_project", home)

      assert.are.equal(expected_path, result)
      assert.is_nil(err)
    end)

    it("should handle empty project name", function()
      local result, err = parser.resolve_config_path("")

      assert.is_false(result)
      assert.are.equal("project name is required", err)
    end)

    it("should handle nil project name", function()
      local result, err = parser.resolve_config_path(nil)

      assert.is_false(result)
      assert.are.equal("project name is required", err)
    end)

    it("should handle missing HOME environment", function()
      -- Mock os.getenv to return nil for HOME
      local original_getenv = os.getenv
      os.getenv = function(var)
        if var == "HOME" then
          return nil
        end
        return original_getenv(var)
      end

      local result, err = parser.resolve_config_path("test")

      -- Restore original getenv
      os.getenv = original_getenv

      assert.is_false(result)
      assert.matches("HOME environment variable is not set", err)
    end)

    it("should handle missing project directory", function()
      local result, err = parser.resolve_config_path("test", "/tmp/nonexistent")

      assert.is_false(result)
      assert.matches("project directory does not exist", err)
    end)

    it("should handle missing config file", function()
      local home = create_temp_conf_dir() -- Create dir but no project file

      local result, err = parser.resolve_config_path("nonexistent", home)

      assert.is_false(result)
      assert.matches("project configuration file does not exist", err)
    end)
  end)

  describe("integration tests", function()
    it("should load, compile and parse complete DSL file", function()
      local dsl_content = [[
return {
  name = "integration-test",
  resources = {
    editor = app {
      cmd = "gedit",
      dir = "/tmp",
      tag = 1,
    },
    terminal = app {
      cmd = "alacritty",
      tag = 0,
    },
    browser = app {
      cmd = "firefox",
      tag = "web",
    },
  },
}
]]
      local filepath = create_temp_dsl_file("integration.lua", dsl_content)

      local success, dsl = parser.load_dsl_file(filepath)

      assert.is_true(success)
      assert.are.equal("integration-test", dsl.name)

      -- Count resources
      local resource_count = 0
      for _ in pairs(dsl.resources) do
        resource_count = resource_count + 1
      end
      assert.are.equal(3, resource_count)

      -- Check resource details
      assert.are.equal("app", dsl.resources.editor.type)
      assert.are.equal("gedit", dsl.resources.editor.cmd)
      assert.are.equal("/tmp", dsl.resources.editor.dir)
      assert.are.equal(1, dsl.resources.editor.tag)

      assert.are.equal("app", dsl.resources.terminal.type)
      assert.are.equal("alacritty", dsl.resources.terminal.cmd)
      assert.are.equal(0, dsl.resources.terminal.tag)

      assert.are.equal("app", dsl.resources.browser.type)
      assert.are.equal("firefox", dsl.resources.browser.cmd)
      assert.are.equal("web", dsl.resources.browser.tag)
    end)
  end)
end)
