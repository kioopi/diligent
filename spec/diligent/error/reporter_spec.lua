local assert = require("luassert")

describe("diligent.error.reporter", function()
  local reporter

  before_each(function()
    package.loaded["diligent.error.reporter"] = nil
    local reporter_factory = require("diligent.error.reporter")
    reporter = reporter_factory.create()
  end)

  describe("create_tag_resolution_error", function()
    it("should create structured tag resolution error objects", function()
      local error_obj = reporter.create_tag_resolution_error(
        "editor", -- resource_id
        2, -- tag_spec
        "TAG_OVERFLOW", -- error_type
        "Tag overflow: resolved to tag 9", -- message
        { -- context
          base_tag = 2,
          resolved_index = 11,
          final_index = 9,
        }
      )

      -- Verify basic structure
      assert.are.equal("TAG_RESOLUTION_ERROR", error_obj.category)
      assert.are.equal("editor", error_obj.resource_id)
      assert.are.equal(2, error_obj.tag_spec)
      assert.are.equal("TAG_OVERFLOW", error_obj.type)
      assert.are.equal("Tag overflow: resolved to tag 9", error_obj.message)

      -- Verify context
      assert.are.equal(2, error_obj.context.base_tag)
      assert.are.equal(11, error_obj.context.resolved_index)
      assert.are.equal(9, error_obj.context.final_index)

      -- Verify metadata
      assert.is_table(error_obj.metadata)
      assert.is_number(error_obj.metadata.timestamp)
      assert.are.equal("planning", error_obj.metadata.phase)

      -- Verify suggestions exist
      assert.is_table(error_obj.suggestions)
    end)

    it("should handle missing context gracefully", function()
      local error_obj = reporter.create_tag_resolution_error(
        "editor",
        2,
        "TAG_OVERFLOW",
        "Tag overflow"
        -- no context provided
      )

      assert.is_table(error_obj.context)
      assert.is_table(error_obj.suggestions)
    end)
  end)

  describe("tag-specific error suggestions", function()
    it("should provide overflow-specific suggestions", function()
      local error_obj = reporter.create_tag_resolution_error(
        "editor",
        2,
        "TAG_OVERFLOW",
        "Overflow",
        { resolved_index = 11, final_index = 9 }
      )

      local suggestions = error_obj.suggestions
      assert.is_true(#suggestions > 0)

      -- Should suggest using absolute tag specification
      local has_absolute_suggestion = false
      for _, suggestion in ipairs(suggestions) do
        if suggestion:match("absolute tag") then
          has_absolute_suggestion = true
          break
        end
      end
      assert.is_true(has_absolute_suggestion)
    end)

    it("should provide invalid spec suggestions", function()
      local error_obj = reporter.create_tag_resolution_error(
        "editor",
        true,
        "TAG_SPEC_INVALID",
        "Invalid spec type"
      )

      local suggestions = error_obj.suggestions
      local has_type_suggestion = false
      for _, suggestion in ipairs(suggestions) do
        if suggestion:match("number.*or.*string") then
          has_type_suggestion = true
          break
        end
      end
      assert.is_true(
        has_type_suggestion,
        "Should find 'number or string' in suggestions"
      )
    end)

    it("should provide tag name format suggestions", function()
      local error_obj = reporter.create_tag_resolution_error(
        "editor",
        "123invalid",
        "TAG_NAME_INVALID",
        "Invalid name format"
      )

      local suggestions = error_obj.suggestions
      local has_format_suggestion = false
      for _, suggestion in ipairs(suggestions) do
        if suggestion:match("start with.*letter") then
          has_format_suggestion = true
          break
        end
      end
      assert.is_true(has_format_suggestion)
    end)
  end)

  describe("aggregate_errors", function()
    it("should aggregate multiple tag resolution errors", function()
      local errors = {
        {
          resource_id = "editor",
          type = "TAG_OVERFLOW",
          message = "Tag overflow",
        },
        {
          resource_id = "browser",
          type = "TAG_SPEC_INVALID",
          message = "Invalid tag spec",
        },
        {
          resource_id = "terminal",
          type = "TAG_NAME_INVALID",
          message = "Invalid tag name",
        },
      }

      local aggregated = reporter.aggregate_errors(errors)

      -- Verify aggregated structure
      assert.are.equal("MULTIPLE_TAG_ERRORS", aggregated.type)
      assert.are.equal("TAG_RESOLUTION_ERROR", aggregated.category)
      assert.are.equal(3, #aggregated.errors)

      -- Verify summary message
      assert.matches("3 errors", aggregated.message)
      assert.matches("TAG_OVERFLOW", aggregated.message)
      assert.matches("TAG_SPEC_INVALID", aggregated.message)
      assert.matches("TAG_NAME_INVALID", aggregated.message)

      -- Verify individual errors preserved
      assert.are.equal("editor", aggregated.errors[1].resource_id)
      assert.are.equal("browser", aggregated.errors[2].resource_id)
      assert.are.equal("terminal", aggregated.errors[3].resource_id)
    end)

    it("should handle single error input", function()
      local errors = {
        { resource_id = "editor", type = "TAG_OVERFLOW", message = "Overflow" },
      }

      local result = reporter.aggregate_errors(errors)

      -- Should return the single error, not aggregate
      assert.are.equal("TAG_OVERFLOW", result.type)
      assert.are.equal("editor", result.resource_id)
    end)

    it("should handle empty error list", function()
      local result = reporter.aggregate_errors({})

      assert.is_nil(result)
    end)
  end)

  describe("create_spawn_summary with tag context", function()
    it("should include tag resolution errors in spawn summary", function()
      local spawn_results = {
        {
          success = false,
          resource_id = "editor",
          error_report = {
            type = "TAG_OVERFLOW",
            category = "TAG_RESOLUTION_ERROR",
            message = "Tag overflow",
          },
        },
        {
          success = false,
          resource_id = "browser",
          error_report = {
            type = "COMMAND_NOT_FOUND",
            category = "SPAWN_ERROR",
            message = "Command not found",
          },
        },
        {
          success = true,
          resource_id = "terminal",
          pid = 12345,
        },
      }

      local summary = reporter.create_spawn_summary(spawn_results)

      assert.are.equal(3, summary.total_attempts)
      assert.are.equal(1, summary.successful)
      assert.are.equal(2, summary.failed)

      -- Should count different error types
      assert.are.equal(1, summary.error_types["TAG_OVERFLOW"])
      assert.are.equal(1, summary.error_types["COMMAND_NOT_FOUND"])

      -- Should include tag-specific recommendations
      local has_tag_recommendation = false
      for _, rec in ipairs(summary.recommendations) do
        if rec:match("tag") then
          has_tag_recommendation = true
          break
        end
      end
      assert.is_true(has_tag_recommendation)
    end)
  end)
end)
