local assert = require("luassert")
local term = require("dsl.helpers.term")

-- Helper function to check if table contains value
local function tbl_contains(tbl, value)
  for _, v in ipairs(tbl) do
    if v == value then
      return true
    end
  end
  return false
end

describe("term helper", function()
  describe("schema", function()
    it("should define required fields", function()
      assert.is_not_nil(term.schema)
      assert.is_table(term.schema.required)
      assert.is_true(tbl_contains(term.schema.required, "cmd"))
    end)

    it("should define optional fields", function()
      assert.is_table(term.schema.optional)
      assert.is_true(tbl_contains(term.schema.optional, "dir"))
      assert.is_true(tbl_contains(term.schema.optional, "tag"))
      assert.is_true(tbl_contains(term.schema.optional, "interactive"))
      assert.is_true(tbl_contains(term.schema.optional, "terminal"))
    end)

    it("should define correct default values", function()
      assert.is_table(term.schema.defaults)
      assert.equals(true, term.schema.defaults.interactive)
      assert.equals("alacritty", term.schema.defaults.terminal)
      assert.equals(0, term.schema.defaults.tag)
    end)
  end)

  describe("create", function()
    it("should create term resource with required cmd field", function()
      local spec = { cmd = "nvim notes.md" }
      local resource = term.create(spec)

      assert.is_table(resource)
      assert.equals("term", resource.type)
      assert.equals("nvim notes.md", resource.cmd)
    end)

    it("should apply default values for optional fields", function()
      local spec = { cmd = "bash" }
      local resource = term.create(spec)

      assert.equals(true, resource.interactive)
      assert.equals("alacritty", resource.terminal)
      assert.equals(0, resource.tag)
    end)

    it("should preserve provided optional values", function()
      local spec = {
        cmd = "nvim file.txt",
        dir = "~/projects",
        tag = 2,
        interactive = false,
        terminal = "xterm",
      }
      local resource = term.create(spec)

      assert.equals("nvim file.txt", resource.cmd)
      assert.equals("~/projects", resource.dir)
      assert.equals(2, resource.tag)
      assert.equals(false, resource.interactive)
      assert.equals("xterm", resource.terminal)
    end)
  end)

  describe("validate", function()
    it("should validate required cmd field", function()
      local success, error_msg = term.validate({})
      assert.is_false(success)
      assert.matches("cmd field is required", error_msg)
    end)

    it("should accept valid term spec", function()
      local spec = { cmd = "bash" }
      local success, error_msg = term.validate(spec)
      assert.is_true(success)
      assert.is_nil(error_msg)
    end)

    it("should validate field types", function()
      local spec = { cmd = 123 } -- Invalid: cmd should be string
      local success, error_msg = term.validate(spec)
      assert.is_false(success)
      assert.matches("cmd must be string", error_msg)
    end)

    it("should validate interactive field type", function()
      local spec = { cmd = "bash", interactive = "yes" } -- Invalid: should be boolean
      local success, error_msg = term.validate(spec)
      assert.is_false(success)
      assert.matches("interactive must be boolean", error_msg)
    end)

    it("should validate terminal field type", function()
      local spec = { cmd = "bash", terminal = 123 } -- Invalid: should be string
      local success, error_msg = term.validate(spec)
      assert.is_false(success)
      assert.matches("terminal must be string", error_msg)
    end)

    it("should reject nil input", function()
      local success, error_msg = term.validate(nil)
      assert.is_false(success)
      assert.matches("term spec is required", error_msg)
    end)

    it("should reject non-table input", function()
      local success, error_msg = term.validate("not a table")
      assert.is_false(success)
      assert.matches("term spec must be a table", error_msg)
    end)
  end)

  describe("describe", function()
    it("should provide human-readable description", function()
      local spec = { cmd = "nvim notes.md" }
      local description = term.describe(spec)
      assert.matches("term: nvim notes.md", description)
    end)

    it("should include optional fields in description", function()
      local spec = {
        cmd = "bash",
        dir = "~/projects",
        tag = 2,
        terminal = "xterm",
      }
      local description = term.describe(spec)
      assert.matches("term: bash", description)
      assert.matches("dir: ~/projects", description)
      assert.matches("tag:", description)
      assert.matches("terminal: xterm", description)
    end)

    it("should handle invalid spec gracefully", function()
      local description = term.describe(nil)
      assert.matches("invalid term spec", description)
    end)
  end)
end)
