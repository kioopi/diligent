local assert = require("luassert")
local tag_spec = require("dsl.tag_spec")

describe("dsl.tag_spec", function()
  describe("parse", function()
    describe("relative tags (numbers)", function()
      it("should parse relative offset 0", function()
        local success, result = tag_spec.parse(0)

        assert.is_true(success)
        assert.are.equal(tag_spec.TYPE_RELATIVE, result.type)
        assert.are.equal(0, result.value)
      end)

      it("should parse positive relative offset", function()
        local success, result = tag_spec.parse(2)

        assert.is_true(success)
        assert.are.equal(tag_spec.TYPE_RELATIVE, result.type)
        assert.are.equal(2, result.value)
      end)

      it("should reject negative offsets", function()
        local success, result = tag_spec.parse(-1)

        assert.is_false(success)
        assert.is_string(result)
        assert.matches("negative tag offsets not supported", result)
      end)
    end)

    describe("absolute tags (string digits)", function()
      it("should parse valid absolute tag", function()
        local success, result = tag_spec.parse("3")

        assert.is_true(success)
        assert.are.equal(tag_spec.TYPE_ABSOLUTE, result.type)
        assert.are.equal(3, result.value)
      end)

      it("should parse single digit strings", function()
        local success, result = tag_spec.parse("9")

        assert.is_true(success)
        assert.are.equal(tag_spec.TYPE_ABSOLUTE, result.type)
        assert.are.equal(9, result.value)
      end)

      it("should reject absolute tag 0", function()
        local success, result = tag_spec.parse("0")

        assert.is_false(success)
        assert.matches("absolute tag must be between 1 and 9", result)
      end)

      it("should reject absolute tag > 9", function()
        local success, result = tag_spec.parse("10")

        assert.is_false(success)
        assert.matches("absolute tag must be between 1 and 9", result)
      end)
    end)

    describe("named tags (string names)", function()
      it("should parse valid named tag", function()
        local success, result = tag_spec.parse("editor")

        assert.is_true(success)
        assert.are.equal(tag_spec.TYPE_NAMED, result.type)
        assert.are.equal("editor", result.value)
      end)

      it("should parse named tag with underscores", function()
        local success, result = tag_spec.parse("web_browser")

        assert.is_true(success)
        assert.are.equal(tag_spec.TYPE_NAMED, result.type)
        assert.are.equal("web_browser", result.value)
      end)

      it("should parse named tag with dashes", function()
        local success, result = tag_spec.parse("chat-app")

        assert.is_true(success)
        assert.are.equal(tag_spec.TYPE_NAMED, result.type)
        assert.are.equal("chat-app", result.value)
      end)

      it("should parse named tag with numbers", function()
        local success, result = tag_spec.parse("editor2")

        assert.is_true(success)
        assert.are.equal(tag_spec.TYPE_NAMED, result.type)
        assert.are.equal("editor2", result.value)
      end)

      it("should reject name starting with number", function()
        local success, result = tag_spec.parse("2editor")

        assert.is_false(success)
        assert.matches("invalid tag name format", result)
      end)

      it("should reject name with invalid characters", function()
        local success, result = tag_spec.parse("editor@home")

        assert.is_false(success)
        assert.matches("invalid tag name format", result)
      end)

      it("should reject empty string", function()
        local success, result = tag_spec.parse("")

        assert.is_false(success)
        assert.matches("tag specification cannot be empty string", result)
      end)
    end)

    describe("invalid input", function()
      it("should reject nil input", function()
        local success, result = tag_spec.parse(nil)

        assert.is_false(success)
        assert.matches("tag specification cannot be nil", result)
      end)

      it("should reject boolean input", function()
        local success, result = tag_spec.parse(true)

        assert.is_false(success)
        assert.matches("tag must be a number or string", result)
      end)

      it("should reject table input", function()
        local success, result = tag_spec.parse({ tag = 1 })

        assert.is_false(success)
        assert.matches("tag must be a number or string", result)
      end)
    end)
  end)

  describe("validate", function()
    it("should validate valid relative tag", function()
      local success, err = tag_spec.validate(1)

      assert.is_true(success)
      assert.is_nil(err)
    end)

    it("should validate valid absolute tag", function()
      local success, err = tag_spec.validate("5")

      assert.is_true(success)
      assert.is_nil(err)
    end)

    it("should validate valid named tag", function()
      local success, err = tag_spec.validate("browser")

      assert.is_true(success)
      assert.is_nil(err)
    end)

    it("should return error for invalid tag", function()
      local success, err = tag_spec.validate(-1)

      assert.is_false(success)
      assert.is_string(err)
    end)
  end)

  describe("describe", function()
    it("should describe relative tag offset 0", function()
      local tag_info = { type = tag_spec.TYPE_RELATIVE, value = 0 }
      local description = tag_spec.describe(tag_info)

      assert.are.equal("current tag (relative offset 0)", description)
    end)

    it("should describe relative tag offset", function()
      local tag_info = { type = tag_spec.TYPE_RELATIVE, value = 2 }
      local description = tag_spec.describe(tag_info)

      assert.are.equal("relative offset +2", description)
    end)

    it("should describe absolute tag", function()
      local tag_info = { type = tag_spec.TYPE_ABSOLUTE, value = 5 }
      local description = tag_spec.describe(tag_info)

      assert.are.equal("absolute tag 5", description)
    end)

    it("should describe named tag", function()
      local tag_info = { type = tag_spec.TYPE_NAMED, value = "editor" }
      local description = tag_spec.describe(tag_info)

      assert.are.equal("named tag 'editor'", description)
    end)

    it("should handle invalid tag info", function()
      local description = tag_spec.describe(nil)
      assert.are.equal("invalid tag info", description)

      local description2 = tag_spec.describe({})
      assert.are.equal("invalid tag info", description2)
    end)
  end)
end)
