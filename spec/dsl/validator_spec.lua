local assert = require("luassert")
local validator = require("dsl.validator")

describe("dsl.validator", function()
  describe("validate_dsl", function()
    describe("required fields", function()
      it("should validate DSL with required fields", function()
        local dsl = {
          name = "test-project",
          resources = {
            editor = {
              type = "app",
              cmd = "gedit",
              tag = 0,
            },
          },
        }

        local success, error_msg = validator.validate_dsl(dsl)

        assert.is_true(success)
        assert.is_nil(error_msg)
      end)

      it("should return error for missing name field", function()
        local dsl = {
          resources = {
            editor = {
              type = "app",
              cmd = "gedit",
            },
          },
        }

        local success, error_msg = validator.validate_dsl(dsl)

        assert.is_false(success)
        assert.matches("name field is required", error_msg)
      end)

      it("should return error for missing resources field", function()
        local dsl = {
          name = "test-project",
        }

        local success, error_msg = validator.validate_dsl(dsl)

        assert.is_false(success)
        assert.matches("resources field is required", error_msg)
      end)

      it("should return error for non-string name", function()
        local dsl = {
          name = 123,
          resources = {
            editor = {
              type = "app",
              cmd = "gedit",
            },
          },
        }

        local success, error_msg = validator.validate_dsl(dsl)

        assert.is_false(success)
        assert.matches("name must be a string", error_msg)
      end)

      it("should return error for empty name", function()
        local dsl = {
          name = "",
          resources = {
            editor = {
              type = "app",
              cmd = "gedit",
            },
          },
        }

        local success, error_msg = validator.validate_dsl(dsl)

        assert.is_false(success)
        assert.matches("name cannot be empty", error_msg)
      end)

      it("should return error for non-table resources", function()
        local dsl = {
          name = "test-project",
          resources = "not a table",
        }

        local success, error_msg = validator.validate_dsl(dsl)

        assert.is_false(success)
        assert.matches("resources must be a table", error_msg)
      end)
    end)

    describe("input validation", function()
      it("should handle nil DSL input", function()
        local success, error_msg = validator.validate_dsl(nil)

        assert.is_false(success)
        assert.matches("DSL is required", error_msg)
      end)

      it("should handle non-table DSL input", function()
        local success, error_msg = validator.validate_dsl("not a table")

        assert.is_false(success)
        assert.matches("DSL must be a table", error_msg)
      end)
    end)

    describe("optional fields", function()
      it("should validate DSL with hooks", function()
        local dsl = {
          name = "test-project",
          resources = {
            editor = {
              type = "app",
              cmd = "gedit",
            },
          },
          hooks = {
            start = "echo 'starting'",
            stop = "echo 'stopping'",
          },
        }

        local success, error_msg = validator.validate_dsl(dsl)

        assert.is_true(success)
        assert.is_nil(error_msg)
      end)

      it("should validate DSL with layouts", function()
        local dsl = {
          name = "test-project",
          resources = {
            editor = {
              type = "app",
              cmd = "gedit",
            },
          },
          layouts = {
            default = {
              editor = 1,
            },
          },
        }

        local success, error_msg = validator.validate_dsl(dsl)

        assert.is_true(success)
        assert.is_nil(error_msg)
      end)
    end)
  end)

  describe("validate_resources", function()
    it("should validate non-empty resources table", function()
      local resources = {
        editor = {
          type = "app",
          cmd = "gedit",
        },
      }

      local success, error_msg = validator.validate_resources(resources)

      assert.is_true(success)
      assert.is_nil(error_msg)
    end)

    it("should return error for empty resources table", function()
      local resources = {}

      local success, error_msg = validator.validate_resources(resources)

      assert.is_false(success)
      assert.matches("at least one resource is required", error_msg)
    end)

    it("should return error for nil resources", function()
      local success, error_msg = validator.validate_resources(nil)

      assert.is_false(success)
      assert.matches("resources table is required", error_msg)
    end)

    it("should return error for non-table resources", function()
      local success, error_msg = validator.validate_resources("not a table")

      assert.is_false(success)
      assert.matches("resources must be a table", error_msg)
    end)

    it("should validate multiple resources", function()
      local resources = {
        editor = {
          type = "app",
          cmd = "gedit",
        },
        terminal = {
          type = "app",
          cmd = "alacritty",
        },
      }

      local success, error_msg = validator.validate_resources(resources)

      assert.is_true(success)
      assert.is_nil(error_msg)
    end)

    it("should return error with resource context", function()
      local resources = {
        editor = {
          type = "app",
          -- Missing required cmd field
        },
      }

      local success, error_msg = validator.validate_resources(resources)

      assert.is_false(success)
      assert.matches("resource 'editor':", error_msg)
      assert.matches("cmd field is required", error_msg)
    end)
  end)

  describe("validate_resource", function()
    it("should validate valid app resource", function()
      local resource_spec = {
        type = "app",
        cmd = "gedit",
        tag = 1,
      }

      local success, error_msg =
        validator.validate_resource(resource_spec, "editor")

      assert.is_true(success)
      assert.is_nil(error_msg)
    end)

    it("should return error for missing type", function()
      local resource_spec = {
        cmd = "gedit",
      }

      local success, error_msg =
        validator.validate_resource(resource_spec, "editor")

      assert.is_false(success)
      assert.matches("resource type is required", error_msg)
    end)

    it("should return error for non-string type", function()
      local resource_spec = {
        type = 123,
        cmd = "gedit",
      }

      local success, error_msg =
        validator.validate_resource(resource_spec, "editor")

      assert.is_false(success)
      assert.matches("resource type must be a string", error_msg)
    end)

    it("should return error for unknown resource type", function()
      local resource_spec = {
        type = "unknown",
        cmd = "gedit",
      }

      local success, error_msg =
        validator.validate_resource(resource_spec, "editor")

      assert.is_false(success)
      assert.matches("unknown resource type", error_msg)
    end)

    it("should return error for nil resource spec", function()
      local success, error_msg = validator.validate_resource(nil, "editor")

      assert.is_false(success)
      assert.matches("resource specification is required", error_msg)
    end)

    it("should return error for non-table resource spec", function()
      local success, error_msg =
        validator.validate_resource("not a table", "editor")

      assert.is_false(success)
      assert.matches("resource specification must be a table", error_msg)
    end)
  end)

  describe("validate_hooks", function()
    it("should validate valid hooks", function()
      local hooks = {
        start = "echo 'starting'",
        stop = "echo 'stopping'",
      }

      local success, error_msg = validator.validate_hooks(hooks)

      assert.is_true(success)
      assert.is_nil(error_msg)
    end)

    it("should validate hooks with only start", function()
      local hooks = {
        start = "echo 'starting'",
      }

      local success, error_msg = validator.validate_hooks(hooks)

      assert.is_true(success)
      assert.is_nil(error_msg)
    end)

    it("should validate hooks with only stop", function()
      local hooks = {
        stop = "echo 'stopping'",
      }

      local success, error_msg = validator.validate_hooks(hooks)

      assert.is_true(success)
      assert.is_nil(error_msg)
    end)

    it("should return error for non-string start hook", function()
      local hooks = {
        start = 123,
      }

      local success, error_msg = validator.validate_hooks(hooks)

      assert.is_false(success)
      assert.matches("hooks.start must be a string", error_msg)
    end)

    it("should return error for empty start hook", function()
      local hooks = {
        start = "",
      }

      local success, error_msg = validator.validate_hooks(hooks)

      assert.is_false(success)
      assert.matches("hooks.start cannot be empty", error_msg)
    end)

    it("should return error for unknown hook type", function()
      local hooks = {
        start = "echo 'starting'",
        unknown = "echo 'unknown'",
      }

      local success, error_msg = validator.validate_hooks(hooks)

      assert.is_false(success)
      assert.matches("unknown hook type: unknown", error_msg)
    end)

    it("should return error for nil hooks", function()
      local success, error_msg = validator.validate_hooks(nil)

      assert.is_false(success)
      assert.matches("hooks table is required", error_msg)
    end)

    it("should return error for non-table hooks", function()
      local success, error_msg = validator.validate_hooks("not a table")

      assert.is_false(success)
      assert.matches("hooks must be a table", error_msg)
    end)
  end)

  describe("validate_layouts", function()
    it("should validate valid layouts", function()
      local layouts = {
        default = {
          editor = 1,
          terminal = 2,
        },
        laptop = {
          editor = 1,
          terminal = 1,
        },
      }

      local success, error_msg = validator.validate_layouts(layouts)

      assert.is_true(success)
      assert.is_nil(error_msg)
    end)

    it("should return error for empty layouts", function()
      local layouts = {}

      local success, error_msg = validator.validate_layouts(layouts)

      assert.is_false(success)
      assert.matches("at least one layout is required", error_msg)
    end)

    it("should return error for non-string layout name", function()
      local layouts = {
        [123] = {
          editor = 1,
        },
      }

      local success, error_msg = validator.validate_layouts(layouts)

      assert.is_false(success)
      assert.matches("layout name must be a string", error_msg)
    end)

    it("should return error for non-table layout spec", function()
      local layouts = {
        default = "not a table",
      }

      local success, error_msg = validator.validate_layouts(layouts)

      assert.is_false(success)
      assert.matches("layout 'default' must be a table", error_msg)
    end)
  end)

  describe("get_validation_summary", function()
    it("should create summary for valid DSL", function()
      local dsl = {
        name = "test-project",
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
          start = "echo 'starting'",
        },
      }

      local summary = validator.get_validation_summary(dsl)

      assert.are.equal("test-project", summary.project_name)
      assert.are.equal(2, summary.resource_count)
      assert.is_true(summary.has_hooks)
      assert.is_false(summary.has_layouts)
      assert.is_true(summary.valid)
      assert.are.equal(0, #summary.errors)

      -- Check resource summaries
      assert.are.equal(2, #summary.resources)

      -- Resources may be in any order, so check both exist
      local resource_names = {}
      for _, resource in ipairs(summary.resources) do
        resource_names[resource.name] = resource
        assert.are.equal("app", resource.type)
        assert.is_true(resource.valid)
      end

      assert.is_not_nil(resource_names["editor"])
      assert.is_not_nil(resource_names["terminal"])
    end)

    it("should create summary for invalid DSL", function()
      local dsl = {
        name = "test-project",
        resources = {
          editor = {
            type = "app",
            -- Missing cmd field
          },
        },
      }

      local summary = validator.get_validation_summary(dsl)

      assert.are.equal("test-project", summary.project_name)
      assert.are.equal(1, summary.resource_count)
      assert.is_false(summary.valid)
      assert.is_true(#summary.errors > 0)

      -- Check resource error
      assert.are.equal(1, #summary.resources)
      assert.is_false(summary.resources[1].valid)
      assert.is_string(summary.resources[1].error)
    end)

    it("should handle nil DSL", function()
      local summary = validator.get_validation_summary(nil)

      assert.are.equal("unknown", summary.project_name)
      assert.are.equal(0, summary.resource_count)
      assert.is_false(summary.valid)
      assert.is_true(#summary.errors > 0)
    end)
  end)
end)
