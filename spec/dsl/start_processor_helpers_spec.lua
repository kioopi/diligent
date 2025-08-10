local assert = require("luassert")
local start_processor_helpers = require("dsl.start_processor_helpers")

describe("Start Processor Helpers", function()
  -- process_tag_specification function removed - no longer needed
  -- Tag processing is now handled by helper modules and tag_mapper

  describe("convert_resource_to_request_format", function()
    it("should convert normalized app resource correctly", function()
      -- Input: normalized resource (defaults already applied by app_helper.create())
      local normalized_resource = {
        type = "app",
        cmd = "firefox",
        dir = "/home/user",
        tag = "3", -- Already validated
        reuse = true, -- Explicit value
      }

      local request_resource =
        start_processor_helpers.convert_resource_to_request_format(
          "browser",
          normalized_resource,
          "app"
        )

      assert.are.equal("browser", request_resource.name)
      assert.are.equal("firefox", request_resource.command)
      assert.are.equal("3", request_resource.tag_spec)
      assert.are.equal("/home/user", request_resource.working_dir)
      assert.is_true(request_resource.reuse)
    end)

    it("should convert normalized term resource correctly", function()
      -- Input: normalized resource (defaults already applied by term_helper.create())
      local normalized_resource = {
        type = "term",
        cmd = "nvim file.txt",
        dir = "/tmp",
        tag = 2, -- Already validated
        interactive = false, -- Explicit value
        terminal = "xterm", -- Explicit value
      }

      local request_resource =
        start_processor_helpers.convert_resource_to_request_format(
          "editor",
          normalized_resource,
          "term"
        )

      assert.are.equal("editor", request_resource.name)
      assert.are.equal("nvim file.txt", request_resource.command)
      assert.are.equal(2, request_resource.tag_spec)
      assert.are.equal("/tmp", request_resource.working_dir)
      assert.is_false(request_resource.interactive)
      assert.are.equal("xterm", request_resource.terminal)
    end)

    it("should handle normalized app with defaults applied", function()
      -- Input: normalized by app_helper.create() with defaults applied
      local normalized_resource = {
        type = "app",
        cmd = "firefox",
        tag = 0, -- Default applied by helper
        reuse = false, -- Default applied by helper
        -- dir is nil (optional)
      }

      local request_resource =
        start_processor_helpers.convert_resource_to_request_format(
          "browser",
          normalized_resource,
          "app"
        )

      assert.is_nil(request_resource.working_dir)
      assert.is_false(request_resource.reuse) -- From normalized input
      assert.are.equal(0, request_resource.tag_spec) -- From normalized input
    end)

    it("should handle normalized term with defaults applied", function()
      -- Input: normalized by term_helper.create() with defaults applied
      local normalized_resource = {
        type = "term",
        cmd = "bash",
        tag = 0, -- Default applied by helper
        interactive = true, -- Default applied by helper
        terminal = "alacritty", -- Default applied by helper
        -- dir is nil (optional)
      }

      local request_resource =
        start_processor_helpers.convert_resource_to_request_format(
          "shell",
          normalized_resource,
          "term"
        )

      assert.is_nil(request_resource.working_dir)
      assert.is_true(request_resource.interactive) -- From normalized input
      assert.are.equal("alacritty", request_resource.terminal) -- From normalized input
      assert.are.equal(0, request_resource.tag_spec) -- From normalized input
    end)

    it("should handle different resource types correctly", function()
      -- Both inputs are normalized by their respective helper.create() functions
      local normalized_app = {
        type = "app",
        cmd = "app1",
        tag = 1,
        reuse = true,
      }
      local normalized_term = {
        type = "term",
        cmd = "term1",
        tag = 2,
        interactive = false,
        terminal = "xterm",
      }

      local app_result =
        start_processor_helpers.convert_resource_to_request_format(
          "app1",
          normalized_app,
          "app"
        )
      local term_result =
        start_processor_helpers.convert_resource_to_request_format(
          "term1",
          normalized_term,
          "term"
        )

      -- App result - only app-specific fields
      assert.is_true(app_result.reuse)
      assert.is_nil(app_result.interactive) -- Not applicable to app
      assert.is_nil(app_result.terminal) -- Not applicable to app

      -- Term result - only term-specific fields
      assert.is_nil(term_result.reuse) -- Not applicable to term
      assert.is_false(term_result.interactive)
      assert.are.equal("xterm", term_result.terminal)
    end)
  end)

  describe("get_supported_resource_types", function()
    it("should return current supported types including term", function()
      local types = start_processor_helpers.get_supported_resource_types()

      assert.are.same({ "app", "term" }, types) -- Should now include term
    end)

    it("should return table that can be iterated", function()
      local types = start_processor_helpers.get_supported_resource_types()

      assert.are.equal("table", type(types))
      assert.are.equal(2, #types)
      assert.are.equal("app", types[1])
      assert.are.equal("term", types[2])
    end)
  end)
end)
