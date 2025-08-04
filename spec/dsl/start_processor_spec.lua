local assert = require("luassert")
local start_processor = require("dsl.start_processor")

describe("Start Processor", function()
  describe("convert_project_to_start_request", function()
    it("should convert single app resource to start request", function()
      local dsl_project = {
        name = "test-project",
        resources = {
          editor = {
            type = "app",
            cmd = "gedit",
            tag = "0",
            dir = "/home/user",
          },
        },
      }

      local start_request =
        start_processor.convert_project_to_start_request(dsl_project)

      assert.are.equal("test-project", start_request.project_name)
      assert.are.equal(1, #start_request.resources)
      assert.are.equal("editor", start_request.resources[1].name)
      assert.are.equal("gedit", start_request.resources[1].command)
      assert.are.equal("0", start_request.resources[1].tag_spec)
      assert.are.equal("/home/user", start_request.resources[1].working_dir)
    end)

    it("should handle minimal app resource with defaults", function()
      local dsl_project = {
        name = "minimal",
        resources = {
          app1 = {
            type = "app",
            cmd = "firefox",
          },
        },
      }

      local start_request =
        start_processor.convert_project_to_start_request(dsl_project)

      assert.are.equal("0", start_request.resources[1].tag_spec) -- default
      assert.is_nil(start_request.resources[1].working_dir) -- no default
      assert.is_false(start_request.resources[1].reuse) -- default false
    end)

    it("should convert multiple app resources", function()
      local dsl_project = {
        name = "multi-app",
        resources = {
          editor = {
            type = "app",
            cmd = "zed",
            tag = 1,
            reuse = true,
          },
          terminal = {
            type = "app",
            cmd = "alacritty",
            tag = "3",
            dir = "/tmp",
          },
        },
      }

      local start_request =
        start_processor.convert_project_to_start_request(dsl_project)

      assert.are.equal(2, #start_request.resources)

      -- Check first resource
      assert.are.equal("editor", start_request.resources[1].name)
      assert.are.equal("zed", start_request.resources[1].command)
      assert.are.equal(1, start_request.resources[1].tag_spec)
      assert.is_true(start_request.resources[1].reuse)

      -- Check second resource
      assert.are.equal("terminal", start_request.resources[2].name)
      assert.are.equal("alacritty", start_request.resources[2].command)
      assert.are.equal("3", start_request.resources[2].tag_spec)
      assert.are.equal("/tmp", start_request.resources[2].working_dir)
    end)

    it("should handle numeric and string tag specifications", function()
      local dsl_project = {
        name = "tag-test",
        resources = {
          numeric_tag = {
            type = "app",
            cmd = "app1",
            tag = 5,
          },
          string_tag = {
            type = "app",
            cmd = "app2",
            tag = "editor",
          },
        },
      }

      local start_request =
        start_processor.convert_project_to_start_request(dsl_project)

      assert.are.equal(5, start_request.resources[1].tag_spec)
      assert.are.equal("editor", start_request.resources[2].tag_spec)
    end)

    it("should ignore non-app resource types", function()
      local dsl_project = {
        name = "mixed-types",
        resources = {
          my_app = {
            type = "app",
            cmd = "firefox",
          },
          some_other_type = {
            type = "service",
            cmd = "docker run something",
          },
        },
      }

      local start_request =
        start_processor.convert_project_to_start_request(dsl_project)

      -- Should only include app resources
      assert.are.equal(1, #start_request.resources)
      assert.are.equal("my_app", start_request.resources[1].name)
    end)

    it("should handle empty resources table", function()
      local dsl_project = {
        name = "empty-project",
        resources = {},
      }

      local start_request =
        start_processor.convert_project_to_start_request(dsl_project)

      assert.are.equal("empty-project", start_request.project_name)
      assert.are.equal(0, #start_request.resources)
    end)

    it("should handle missing resources table", function()
      local dsl_project = {
        name = "no-resources-project",
      }

      local start_request =
        start_processor.convert_project_to_start_request(dsl_project)

      assert.are.equal("no-resources-project", start_request.project_name)
      assert.are.equal(0, #start_request.resources)
    end)
  end)
end)
