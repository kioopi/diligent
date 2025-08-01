local assert = require("luassert")
local lfs = require("lfs")
local P = require("pl.path")
local F = require("pl.file")
local dir = require("pl.dir")
local dsl = require("dsl")

-- Helper functions for testing
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
    local content = [[
return {
  name = "]] .. project_name .. [[",
  resources = {
    editor = app {
      cmd = "gedit",
      tag = 0,
    },
  },
}
]]
    F.write(filepath, content)
  end
  return tmp_home
end

local function cleanup_temp_files()
  os.execute("rm -rf /tmp/diligent-test-dsl/")
  os.execute("rm -rf /tmp/diligenthome/")
end

describe("dsl", function()
  after_each(function()
    cleanup_temp_files()
  end)

  describe("load_and_validate", function()
    it("should load and validate valid DSL file", function()
      local dsl_content = [[
return {
  name = "test-project",
  resources = {
    editor = app {
      cmd = "gedit",
      dir = "/tmp",
      tag = 1,
    },
  },
}
]]
      local filepath = create_temp_dsl_file("valid.lua", dsl_content)

      local success, result = dsl.load_and_validate(filepath)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal("test-project", result.name)
      assert.is_table(result.resources.editor)
      assert.are.equal("app", result.resources.editor.type)
    end)

    it("should return parse error for invalid syntax", function()
      local dsl_content = [[
return {
  name = "test-project"  -- missing comma
  resources = {}
}
]]
      local filepath = create_temp_dsl_file("invalid.lua", dsl_content)

      local success, error_msg = dsl.load_and_validate(filepath)

      assert.is_false(success)
      assert.is_string(error_msg)
      assert.matches("syntax error", error_msg)
    end)

    it("should return validation error for invalid DSL structure", function()
      local dsl_content = [[
return {
  name = "test-project",
  resources = {}, -- Empty resources not allowed
}
]]
      local filepath = create_temp_dsl_file("empty-resources.lua", dsl_content)

      local success, error_msg = dsl.load_and_validate(filepath)

      assert.is_false(success)
      assert.is_string(error_msg)
      assert.matches("at least one resource is required", error_msg)
    end)

    it("should return error for missing file", function()
      local success, error_msg = dsl.load_and_validate("/nonexistent/file.lua")

      assert.is_false(success)
      assert.matches("file not found", error_msg)
    end)
  end)

  describe("compile_and_validate", function()
    it("should compile and validate DSL string", function()
      local dsl_string = [[
return {
  name = "string-test",
  resources = {
    terminal = app {
      cmd = "alacritty",
      tag = "terminal",
    },
  },
}
]]

      local success, result = dsl.compile_and_validate(dsl_string, "test.lua")

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal("string-test", result.name)
      assert.are.equal("alacritty", result.resources.terminal.cmd)
      assert.are.equal("terminal", result.resources.terminal.tag)
    end)

    it("should work without filepath parameter", function()
      local dsl_string = [[
return {
  name = "no-file",
  resources = {
    app1 = app { cmd = "test" },
  },
}
]]

      local success, result = dsl.compile_and_validate(dsl_string)

      assert.is_true(success)
      assert.is_table(result)
    end)

    it("should return compilation error", function()
      local dsl_string = "invalid lua syntax {"

      local success, error_msg = dsl.compile_and_validate(dsl_string)

      assert.is_false(success)
      assert.matches("syntax error", error_msg)
    end)

    it("should return validation error", function()
      local dsl_string = [[
return {
  -- Missing required fields
}
]]

      local success, error_msg = dsl.compile_and_validate(dsl_string)

      assert.is_false(success)
      assert.matches("name field is required", error_msg)
    end)
  end)

  describe("validate", function()
    it("should validate valid DSL table", function()
      local dsl_table = {
        name = "validate-test",
        resources = {
          editor = {
            type = "app",
            cmd = "vim",
          },
        },
      }

      local success, error_msg = dsl.validate(dsl_table)

      assert.is_true(success)
      assert.is_nil(error_msg)
    end)

    it("should return error for invalid DSL table", function()
      local dsl_table = {
        name = "invalid",
        resources = {}, -- Empty resources
      }

      local success, error_msg = dsl.validate(dsl_table)

      assert.is_false(success)
      assert.is_string(error_msg)
    end)
  end)

  describe("get_validation_summary", function()
    it("should provide detailed validation summary", function()
      local dsl_table = {
        name = "summary-test",
        resources = {
          editor = {
            type = "app",
            cmd = "gedit",
          },
          terminal = {
            type = "app",
            cmd = "alacritty",
          },
        },
        hooks = {
          start = "echo starting",
        },
      }

      local summary = dsl.get_validation_summary(dsl_table)

      assert.are.equal("summary-test", summary.project_name)
      assert.are.equal(2, summary.resource_count)
      assert.is_true(summary.has_hooks)
      assert.is_false(summary.has_layouts)
      assert.is_true(summary.valid)
      assert.are.equal(2, #summary.resources)
    end)
  end)

  describe("resolve_config_path", function()
    it("should resolve project name to path", function()
      local home = create_temp_conf_dir("resolve-test")
      local expected_path =
        P.join(home, ".config/diligent/projects/resolve-test.lua")

      local path, error_msg = dsl.resolve_config_path("resolve-test", home)

      assert.are.equal(expected_path, path)
      assert.is_nil(error_msg)
    end)

    it("should return error for missing project", function()
      local home = create_temp_conf_dir() -- Create directory but no project

      local path, error_msg = dsl.resolve_config_path("missing-project", home)

      assert.is_false(path)
      assert.is_string(error_msg)
      assert.matches("does not exist", error_msg)
    end)
  end)

  describe("load_project", function()
    it("should load project by name", function()
      local home = create_temp_conf_dir("load-project-test")

      local success, result = dsl.load_project("load-project-test", home)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal("load-project-test", result.name)
      assert.is_table(result.resources.editor)
    end)

    it("should return path resolution error", function()
      local home = create_temp_conf_dir() -- No project files

      local success, error_msg = dsl.load_project("nonexistent", home)

      assert.is_false(success)
      assert.is_string(error_msg)
      assert.matches("does not exist", error_msg)
    end)

    it("should return DSL validation error", function()
      local home = create_temp_conf_dir()
      local project_dir = P.join(home, ".config", "diligent", "projects")
      local invalid_dsl = "return { invalid = 'dsl' }"
      F.write(P.join(project_dir, "invalid.lua"), invalid_dsl)

      local success, error_msg = dsl.load_project("invalid", home)

      assert.is_false(success)
      assert.matches("name field is required", error_msg)
    end)
  end)

  describe("integration", function()
    it("should handle complete realistic DSL", function()
      local dsl_content = [[
return {
  name = "web-development",
  resources = {
    editor = app {
      cmd = "zed ~/projects/webapp",
      dir = "~/projects/webapp",
      tag = 0,
      reuse = true,
    },
    terminal = app {
      cmd = "alacritty",
      dir = "~/projects/webapp", 
      tag = 1,
    },
    browser = app {
      cmd = "firefox http://localhost:3000",
      tag = "web",
    },
  },
  hooks = {
    start = "npm run dev",
    stop = "pkill -f 'npm run dev'",
  },
}
]]
      local filepath = create_temp_dsl_file("integration.lua", dsl_content)

      local success, result = dsl.load_and_validate(filepath)

      assert.is_true(success)
      assert.are.equal("web-development", result.name)
      assert.is_table(result.hooks)

      -- Validate all resource types and tag types
      assert.are.equal(0, result.resources.editor.tag) -- number
      assert.are.equal(1, result.resources.terminal.tag) -- number
      assert.are.equal("web", result.resources.browser.tag) -- named string

      -- Validate hooks
      assert.are.equal("npm run dev", result.hooks.start)
      assert.are.equal("pkill -f 'npm run dev'", result.hooks.stop)
    end)

    it("should provide detailed summary for complex DSL", function()
      local dsl_table = {
        name = "complex-project",
        resources = {
          editor = { type = "app", cmd = "vim" },
          terminal = { type = "app", cmd = "alacritty" },
          browser = { type = "app", cmd = "firefox" },
        },
        hooks = { start = "echo start" },
        layouts = {
          default = { editor = 1, terminal = 2, browser = 3 },
        },
      }

      local summary = dsl.get_validation_summary(dsl_table)

      assert.are.equal("complex-project", summary.project_name)
      assert.are.equal(3, summary.resource_count)
      assert.is_true(summary.has_hooks)
      assert.is_true(summary.has_layouts)
      assert.is_true(summary.valid)
    end)
  end)

  describe("module exports", function()
    it("should export internal modules", function()
      assert.is_table(dsl.parser)
      assert.is_table(dsl.validator)
      assert.is_table(dsl.helpers)
      assert.is_table(dsl.tag_spec)
    end)

    it("should allow access to internal functionality", function()
      -- Test that we can access helper registry
      local app_helper = dsl.helpers.get("app")
      assert.is_function(app_helper)

      -- Test that we can parse tag specs
      local success, tag_info = dsl.tag_spec.parse(1)
      assert.is_true(success)
      assert.are.equal("relative", tag_info.type)
    end)
  end)
end)
