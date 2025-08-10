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
      -- Note: In real flow, app_helper.create() would normalize this input
      local dsl_project = {
        name = "minimal",
        resources = {
          app1 = {
            type = "app",
            cmd = "firefox",
            -- Defaults would be applied by app_helper.create():
            tag = 0, -- Default applied by app_helper.create()
            reuse = false, -- Default applied by app_helper.create()
          },
        },
      }

      local start_request =
        start_processor.convert_project_to_start_request(dsl_project)

      assert.are.equal(0, start_request.resources[1].tag_spec) -- from normalized input
      assert.is_nil(start_request.resources[1].working_dir) -- no default
      assert.is_false(start_request.resources[1].reuse) -- from normalized input
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

      local zed = start_request.resources[1]

      -- Check first resource
      assert.are.equal("editor", zed.name)
      assert.are.equal("zed", zed.command)
      assert.are.equal(1, zed.tag_spec)
      assert.is_true(zed.reuse)

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

  describe("tag specification handling", function()
    it(
      "should accept valid numeric tag specifications from normalized input",
      function()
        -- Note: In real flow, tag validation is done by helper modules and tag_mapper
        local dsl_project = {
          name = "numeric-tags",
          resources = {
            app1 = {
              type = "app",
              cmd = "gedit",
              tag = 1, -- Already validated by helper modules
            },
            app2 = {
              type = "app",
              cmd = "firefox",
              tag = 0, -- Already validated by helper modules
            },
          },
        }

        local start_request =
          start_processor.convert_project_to_start_request(dsl_project)

        -- Should preserve tag_spec values as-is from normalized input
        assert.are.equal(1, start_request.resources[1].tag_spec)
        assert.are.equal(0, start_request.resources[2].tag_spec)
      end
    )

    it(
      "should accept valid string tag specifications from normalized input",
      function()
        -- Note: In real flow, tag validation is done by helper modules and tag_mapper
        local dsl_project = {
          name = "string-tags",
          resources = {
            app1 = {
              type = "app",
              cmd = "gedit",
              tag = "3", -- Already validated by helper modules
            },
            app2 = {
              type = "app",
              cmd = "firefox",
              tag = "editor", -- Already validated by helper modules
            },
          },
        }

        local start_request =
          start_processor.convert_project_to_start_request(dsl_project)

        -- Should preserve tag_spec values as-is from normalized input
        assert.are.equal("3", start_request.resources[1].tag_spec)
        assert.are.equal("editor", start_request.resources[2].tag_spec)
      end
    )
  end)

  describe("resource processing consistency", function()
    it("should process app resources identically after refactoring", function()
      -- Note: In real flow, these resources would be normalized by app_helper.create()
      local dsl_project = {
        name = "consistency-test",
        resources = {
          app_with_all_fields = {
            type = "app",
            cmd = "firefox",
            dir = "/home/user",
            tag = "browser",
            reuse = true,
          },
          app_minimal = {
            type = "app",
            cmd = "gedit",
            -- Normalized by app_helper.create():
            tag = 0, -- Default applied by helper
            reuse = false, -- Default applied by helper
          },
          app_with_numeric_tag = {
            type = "app",
            cmd = "calculator",
            tag = 5,
            reuse = false, -- Default applied by helper
          },
        },
      }

      local start_request =
        start_processor.convert_project_to_start_request(dsl_project)

      -- Should process in alphabetical order
      assert.are.equal(3, #start_request.resources)

      -- Check app_minimal (first alphabetically)
      local minimal = start_request.resources[1]
      assert.are.equal("app_minimal", minimal.name)
      assert.are.equal("gedit", minimal.command)
      assert.are.equal(0, minimal.tag_spec) -- From normalized input
      assert.is_nil(minimal.working_dir) -- No default
      assert.is_false(minimal.reuse) -- From normalized input

      -- Check app_with_all_fields (second alphabetically)
      local full = start_request.resources[2]
      assert.are.equal("app_with_all_fields", full.name)
      assert.are.equal("firefox", full.command)
      assert.are.equal("browser", full.tag_spec)
      assert.are.equal("/home/user", full.working_dir)
      assert.is_true(full.reuse)

      -- Check app_with_numeric_tag (third alphabetically)
      local numeric = start_request.resources[3]
      assert.are.equal("app_with_numeric_tag", numeric.name)
      assert.are.equal("calculator", numeric.command)
      assert.are.equal(5, numeric.tag_spec)
      assert.is_false(numeric.reuse) -- From normalized input
    end)

    it(
      "should maintain deterministic resource ordering after refactoring",
      function()
        local dsl_project = {
          name = "order-test",
          resources = {
            zebra = { type = "app", cmd = "zebra" },
            alpha = { type = "app", cmd = "alpha" },
            beta = { type = "app", cmd = "beta" },
          },
        }

        local start_request =
          start_processor.convert_project_to_start_request(dsl_project)

        -- Should be alphabetically ordered
        assert.are.equal("alpha", start_request.resources[1].name)
        assert.are.equal("beta", start_request.resources[2].name)
        assert.are.equal("zebra", start_request.resources[3].name)
      end
    )
  end)

  describe("integration with normalized resources from helpers", function()
    it("should work with pre-normalized app resources", function()
      -- Simulate what happens when app_helper.create() produces normalized resources
      local dsl_project = {
        name = "normalized-test",
        resources = {
          browser = {
            type = "app",
            cmd = "firefox",
            tag = 0, -- Default applied by app_helper.create()
            reuse = false, -- Default applied by app_helper.create()
            dir = "/home/user", -- Explicit value
          },
        },
      }

      local start_request =
        start_processor.convert_project_to_start_request(dsl_project)

      assert.are.equal("normalized-test", start_request.project_name)
      assert.are.equal(1, #start_request.resources)

      local resource = start_request.resources[1]
      assert.are.equal("browser", resource.name)
      assert.are.equal("firefox", resource.command)
      assert.are.equal(0, resource.tag_spec) -- Should pass through as-is
      assert.are.equal(false, resource.reuse) -- Should pass through as-is
      assert.are.equal("/home/user", resource.working_dir)
    end)

    it("should work with pre-normalized term resources", function()
      -- Test integration with pre-normalized resources from term_helper.create()

      local dsl_project = {
        name = "term-test",
        resources = {
          shell = {
            type = "term",
            cmd = "bash",
            tag = 1, -- Explicit value from DSL
            interactive = true, -- Default applied by term_helper.create()
            terminal = "alacritty", -- Default applied by term_helper.create()
            dir = "/tmp", -- Explicit value
          },
        },
      }

      local start_request =
        start_processor.convert_project_to_start_request(dsl_project)

      assert.are.equal("term-test", start_request.project_name)
      assert.are.equal(1, #start_request.resources)

      local resource = start_request.resources[1]
      assert.are.equal("shell", resource.name)
      assert.are.equal("bash", resource.command)
      assert.are.equal(1, resource.tag_spec) -- Should pass through as-is
      assert.are.equal(true, resource.interactive) -- Should pass through as-is
      assert.are.equal("alacritty", resource.terminal) -- Should pass through as-is
      assert.are.equal("/tmp", resource.working_dir)
    end)
  end)

  describe("term resource processing", function()
    it("should process single term resource correctly", function()
      local dsl_project = {
        name = "term-project",
        resources = {
          shell = {
            type = "term",
            cmd = "bash",
            tag = 0, -- Default from term_helper.create()
            interactive = true, -- Default from term_helper.create()
            terminal = "alacritty", -- Default from term_helper.create()
            dir = "/tmp", -- Explicit value
          },
        },
      }

      local start_request =
        start_processor.convert_project_to_start_request(dsl_project)

      assert.are.equal("term-project", start_request.project_name)
      assert.are.equal(1, #start_request.resources)

      local resource = start_request.resources[1]
      assert.are.equal("shell", resource.name)
      assert.are.equal("bash", resource.command)
      assert.are.equal(0, resource.tag_spec)
      assert.are.equal(true, resource.interactive)
      assert.are.equal("alacritty", resource.terminal)
      assert.are.equal("/tmp", resource.working_dir)
    end)

    it("should process mixed app and term resources", function()
      local dsl_project = {
        name = "mixed-project",
        resources = {
          browser = {
            type = "app",
            cmd = "firefox",
            tag = 1,
            reuse = false, -- Default from app_helper.create()
          },
          editor = {
            type = "term",
            cmd = "nvim",
            tag = "editor",
            interactive = true, -- Default from term_helper.create()
            terminal = "alacritty", -- Default from term_helper.create()
            dir = "/home/user",
          },
        },
      }

      local start_request =
        start_processor.convert_project_to_start_request(dsl_project)

      assert.are.equal("mixed-project", start_request.project_name)
      assert.are.equal(2, #start_request.resources)

      -- Should be in alphabetical order: browser, editor
      local app_resource = start_request.resources[1]
      assert.are.equal("browser", app_resource.name)
      assert.are.equal("firefox", app_resource.command)
      assert.are.equal(1, app_resource.tag_spec)
      assert.is_false(app_resource.reuse)
      assert.is_nil(app_resource.interactive) -- Not applicable to app
      assert.is_nil(app_resource.terminal) -- Not applicable to app

      local term_resource = start_request.resources[2]
      assert.are.equal("editor", term_resource.name)
      assert.are.equal("nvim", term_resource.command)
      assert.are.equal("editor", term_resource.tag_spec)
      assert.are.equal("/home/user", term_resource.working_dir)
      assert.is_true(term_resource.interactive)
      assert.are.equal("alacritty", term_resource.terminal)
      assert.is_nil(term_resource.reuse) -- Not applicable to term
    end)

    it(
      "should handle term resources with explicit non-default values",
      function()
        local dsl_project = {
          name = "custom-term",
          resources = {
            custom_shell = {
              type = "term",
              cmd = "zsh -l",
              tag = 5, -- Explicit numeric tag
              interactive = false, -- Explicit non-default
              terminal = "gnome-terminal", -- Explicit non-default
              dir = "/opt/project", -- Explicit directory
            },
          },
        }

        local start_request =
          start_processor.convert_project_to_start_request(dsl_project)

        assert.are.equal("custom-term", start_request.project_name)
        assert.are.equal(1, #start_request.resources)

        local resource = start_request.resources[1]
        assert.are.equal("custom_shell", resource.name)
        assert.are.equal("zsh -l", resource.command)
        assert.are.equal(5, resource.tag_spec)
        assert.is_false(resource.interactive) -- Explicit value
        assert.are.equal("gnome-terminal", resource.terminal) -- Explicit value
        assert.are.equal("/opt/project", resource.working_dir)
      end
    )

    it(
      "should ignore unsupported resource types while processing term",
      function()
        local dsl_project = {
          name = "mixed-types",
          resources = {
            my_app = {
              type = "app",
              cmd = "firefox",
              tag = 1,
              reuse = false,
            },
            my_term = {
              type = "term",
              cmd = "bash",
              tag = 0,
              interactive = true,
              terminal = "alacritty",
            },
            unsupported = {
              type = "service", -- Not supported
              cmd = "docker run something",
            },
          },
        }

        local start_request =
          start_processor.convert_project_to_start_request(dsl_project)

        -- Should only include app and term resources, not service
        assert.are.equal(2, #start_request.resources)
        assert.are.equal("my_app", start_request.resources[1].name) -- alphabetical
        assert.are.equal("my_term", start_request.resources[2].name) -- alphabetical
      end
    )

    it("should handle term resource with minimal fields", function()
      local dsl_project = {
        name = "minimal-term",
        resources = {
          simple = {
            type = "term",
            cmd = "bash",
            -- All other fields use defaults from term_helper.create()
            tag = 0,
            interactive = true,
            terminal = "alacritty",
          },
        },
      }

      local start_request =
        start_processor.convert_project_to_start_request(dsl_project)

      assert.are.equal("minimal-term", start_request.project_name)
      assert.are.equal(1, #start_request.resources)

      local resource = start_request.resources[1]
      assert.are.equal("simple", resource.name)
      assert.are.equal("bash", resource.command)
      assert.are.equal(0, resource.tag_spec)
      assert.is_nil(resource.working_dir) -- Optional field not provided
      assert.is_true(resource.interactive)
      assert.are.equal("alacritty", resource.terminal)
    end)

    it(
      "should handle large mixed project with multiple resource types",
      function()
        local dsl_project = {
          name = "large-project",
          resources = {
            app1 = { type = "app", cmd = "firefox", tag = 1, reuse = false },
            app2 = { type = "app", cmd = "gedit", tag = 2, reuse = true },
            term1 = {
              type = "term",
              cmd = "bash",
              tag = 3,
              interactive = true,
              terminal = "alacritty",
            },
            term2 = {
              type = "term",
              cmd = "zsh",
              tag = 4,
              interactive = false,
              terminal = "xterm",
            },
            app3 = { type = "app", cmd = "calculator", tag = 5, reuse = false },
          },
        }

        local start_request =
          start_processor.convert_project_to_start_request(dsl_project)

        assert.are.equal("large-project", start_request.project_name)
        assert.are.equal(5, #start_request.resources)

        -- Verify all resources processed in alphabetical order
        assert.are.equal("app1", start_request.resources[1].name)
        assert.are.equal("app2", start_request.resources[2].name)
        assert.are.equal("app3", start_request.resources[3].name)
        assert.are.equal("term1", start_request.resources[4].name)
        assert.are.equal("term2", start_request.resources[5].name)

        -- Spot check a few resources for correct field mapping
        local app_resource = start_request.resources[1]
        assert.are.equal("firefox", app_resource.command)
        assert.are.equal(1, app_resource.tag_spec)
        assert.is_false(app_resource.reuse)
        assert.is_nil(app_resource.interactive) -- Not applicable to app

        local term_resource = start_request.resources[4]
        assert.are.equal("bash", term_resource.command)
        assert.are.equal(3, term_resource.tag_spec)
        assert.is_true(term_resource.interactive)
        assert.are.equal("alacritty", term_resource.terminal)
        assert.is_nil(term_resource.reuse) -- Not applicable to term
      end
    )
  end)
end)
