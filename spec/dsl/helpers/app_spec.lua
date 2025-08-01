local assert = require("luassert")
local app_helper = require("dsl.helpers.app")

describe("dsl.helpers.app", function()
  describe("validate", function()
    describe("required fields", function()
      it("should require cmd field", function()
        local spec = {
          dir = "/tmp",
          tag = 0,
        }

        local success, error_msg = app_helper.validate(spec)

        assert.is_false(success)
        assert.matches("cmd field is required", error_msg)
      end)

      it("should accept minimal valid spec", function()
        local spec = {
          cmd = "gedit",
        }

        local success, error_msg = app_helper.validate(spec)

        assert.is_true(success)
        assert.is_nil(error_msg)
      end)
    end)

    describe("field types", function()
      it("should validate cmd as string", function()
        local spec = {
          cmd = 123,
        }

        local success, error_msg = app_helper.validate(spec)

        assert.is_false(success)
        assert.matches("cmd must be string", error_msg)
      end)

      it("should validate dir as string", function()
        local spec = {
          cmd = "gedit",
          dir = 123,
        }

        local success, error_msg = app_helper.validate(spec)

        assert.is_false(success)
        assert.matches("dir must be string", error_msg)
      end)

      it("should validate reuse as boolean", function()
        local spec = {
          cmd = "gedit",
          reuse = "true", -- string, not boolean
        }

        local success, error_msg = app_helper.validate(spec)

        assert.is_false(success)
        assert.matches("reuse must be boolean", error_msg)
      end)

      it("should accept number tag", function()
        local spec = {
          cmd = "gedit",
          tag = 1,
        }

        local success, error_msg = app_helper.validate(spec)

        assert.is_true(success)
        assert.is_nil(error_msg)
      end)

      it("should accept string tag", function()
        local spec = {
          cmd = "gedit",
          tag = "3",
        }

        local success, error_msg = app_helper.validate(spec)

        assert.is_true(success)
        assert.is_nil(error_msg)
      end)

      it("should accept named tag", function()
        local spec = {
          cmd = "gedit",
          tag = "editor",
        }

        local success, error_msg = app_helper.validate(spec)

        assert.is_true(success)
        assert.is_nil(error_msg)
      end)

      it("should reject invalid tag type", function()
        local spec = {
          cmd = "gedit",
          tag = true,
        }

        local success, error_msg = app_helper.validate(spec)

        assert.is_false(success)
        assert.matches("tag must be number or string", error_msg)
      end)
    end)

    describe("tag validation", function()
      it("should validate tag specification", function()
        local spec = {
          cmd = "gedit",
          tag = -1, -- Invalid: negative relative offset
        }

        local success, error_msg = app_helper.validate(spec)

        assert.is_false(success)
        assert.matches("invalid tag specification", error_msg)
      end)

      it("should validate named tag format", function()
        local spec = {
          cmd = "gedit",
          tag = "invalid@name",
        }

        local success, error_msg = app_helper.validate(spec)

        assert.is_false(success)
        assert.matches("invalid tag specification", error_msg)
      end)
    end)

    describe("input validation", function()
      it("should reject nil spec", function()
        local success, error_msg = app_helper.validate(nil)

        assert.is_false(success)
        assert.matches("app spec is required", error_msg)
      end)

      it("should reject non-table spec", function()
        local success, error_msg = app_helper.validate("not a table")

        assert.is_false(success)
        assert.matches("app spec must be a table", error_msg)
      end)
    end)

    describe("complete valid specs", function()
      it("should validate complete spec with all fields", function()
        local spec = {
          cmd = "zed /home/user/project",
          dir = "/home/user/project",
          tag = 1,
          reuse = true,
        }

        local success, error_msg = app_helper.validate(spec)

        assert.is_true(success)
        assert.is_nil(error_msg)
      end)

      it("should validate spec with named tag", function()
        local spec = {
          cmd = "firefox",
          tag = "web-browser",
          reuse = true,
        }

        local success, error_msg = app_helper.validate(spec)

        assert.is_true(success)
        assert.is_nil(error_msg)
      end)
    end)
  end)

  describe("create", function()
    it("should create normalized resource with all fields", function()
      local spec = {
        cmd = "zed",
        dir = "/home/user",
        tag = 2,
        reuse = true,
      }

      local resource = app_helper.create(spec)

      assert.are.equal("app", resource.type)
      assert.are.equal("zed", resource.cmd)
      assert.are.equal("/home/user", resource.dir)
      assert.are.equal(2, resource.tag)
      assert.is_true(resource.reuse)
    end)

    it("should apply default values", function()
      local spec = {
        cmd = "gedit",
      }

      local resource = app_helper.create(spec)

      assert.are.equal("app", resource.type)
      assert.are.equal("gedit", resource.cmd)
      assert.is_nil(resource.dir) -- No default for dir
      assert.are.equal(0, resource.tag) -- Default tag
      assert.is_false(resource.reuse) -- Default reuse
    end)

    it("should preserve string tags", function()
      local spec = {
        cmd = "firefox",
        tag = "browser",
      }

      local resource = app_helper.create(spec)

      assert.are.equal("firefox", resource.cmd)
      assert.are.equal("browser", resource.tag)
    end)
  end)

  describe("describe", function()
    it("should describe minimal app spec", function()
      local spec = {
        cmd = "gedit",
      }

      local description = app_helper.describe(spec)

      assert.matches("app: gedit", description)
    end)

    it("should describe complete app spec", function()
      local spec = {
        cmd = "zed",
        dir = "/home/user",
        tag = 1,
        reuse = true,
      }

      local description = app_helper.describe(spec)

      assert.matches("app: zed", description)
      assert.matches("dir: /home/user", description)
      assert.matches("tag: relative offset %+1", description)
      assert.matches("reuse: true", description)
    end)

    it("should describe app with named tag", function()
      local spec = {
        cmd = "firefox",
        tag = "browser",
      }

      local description = app_helper.describe(spec)

      assert.matches("app: firefox", description)
      assert.matches("tag: named tag 'browser'", description)
    end)

    it("should handle invalid spec", function()
      local description = app_helper.describe(nil)
      assert.are.equal("invalid app spec", description)

      local description2 = app_helper.describe({})
      assert.are.equal("invalid app spec", description2)
    end)
  end)

  describe("schema", function()
    it("should have correct required fields", function()
      assert.are.same({ "cmd" }, app_helper.schema.required)
    end)

    it("should have correct optional fields", function()
      assert.are.same({ "dir", "tag", "reuse" }, app_helper.schema.optional)
    end)

    it("should have correct default values", function()
      assert.are.equal(0, app_helper.schema.defaults.tag)
      assert.is_false(app_helper.schema.defaults.reuse)
    end)
  end)
end)
