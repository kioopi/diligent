local assert = require("luassert")

describe("diligent.error", function()
  local error_handler

  before_each(function()
    -- Clear any cached modules
    package.loaded["diligent.error"] = nil
    package.loaded["diligent.error.classifier"] = nil 
    package.loaded["diligent.error.reporter"] = nil
    package.loaded["diligent.error.formatter"] = nil
    
    -- Create fresh error handler instance
    local error_factory = require("diligent.error")
    error_handler = error_factory.create()
  end)

  describe("enhanced error types", function()
    it("should include tag resolution error types", function()
      local ERROR_TYPES = error_handler.classifier.ERROR_TYPES
      
      -- Original error types should still exist
      assert.is_not_nil(ERROR_TYPES.COMMAND_NOT_FOUND)
      assert.is_not_nil(ERROR_TYPES.PERMISSION_DENIED)
      
      -- New tag resolution error types should exist
      assert.is_not_nil(ERROR_TYPES.TAG_SPEC_INVALID)
      assert.is_not_nil(ERROR_TYPES.TAG_OVERFLOW) 
      assert.is_not_nil(ERROR_TYPES.TAG_NAME_INVALID)
      assert.is_not_nil(ERROR_TYPES.MULTIPLE_TAG_ERRORS)
    end)
  end)

  describe("error classification", function()
    it("should classify tag overflow errors", function()
      local error_type, user_message = error_handler.classifier.classify_error(
        "Tag overflow: resolved index 11 exceeds maximum 9"
      )
      
      assert.are.equal(error_handler.classifier.ERROR_TYPES.TAG_OVERFLOW, error_type)
      assert.matches("Tag overflow", user_message)
    end)

    it("should classify invalid tag spec errors", function()
      local error_type, user_message = error_handler.classifier.classify_error(
        "Invalid tag specification: must be number or string"
      )
      
      assert.are.equal(error_handler.classifier.ERROR_TYPES.TAG_SPEC_INVALID, error_type)
      assert.matches("Invalid tag", user_message)
    end)

    it("should classify invalid tag name errors", function()
      local error_type, user_message = error_handler.classifier.classify_error(
        "Invalid tag name format: must start with letter"
      )
      
      assert.are.equal(error_handler.classifier.ERROR_TYPES.TAG_NAME_INVALID, error_type)
      assert.matches("Invalid tag name", user_message)
    end)
  end)

  describe("structured error object creation", function()
    it("should create structured error objects with context", function()
      local error_obj = error_handler.reporter.create_tag_resolution_error(
        "editor", -- resource_id
        2, -- tag_spec
        "TAG_OVERFLOW", -- error_type
        "Tag overflow: resolved to tag 9", -- message
        { -- context
          base_tag = 2,
          resolved_index = 11,
          final_index = 9
        }
      )

      assert.are.equal("editor", error_obj.resource_id)
      assert.are.equal(2, error_obj.tag_spec)
      assert.are.equal("TAG_OVERFLOW", error_obj.type)
      assert.are.equal("Tag overflow: resolved to tag 9", error_obj.message)
      assert.are.equal(2, error_obj.context.base_tag)
      assert.are.equal(11, error_obj.context.resolved_index)
      assert.are.equal(9, error_obj.context.final_index)
      assert.is_table(error_obj.suggestions)
      assert.is_table(error_obj.metadata)
    end)

    it("should include appropriate suggestions for tag overflow", function()
      local error_obj = error_handler.reporter.create_tag_resolution_error(
        "editor", 2, "TAG_OVERFLOW", "Tag overflow", {resolved_index = 11}
      )

      local suggestions = error_obj.suggestions
      assert.is_true(#suggestions > 0)
      
      local found_absolute_suggestion = false
      for _, suggestion in ipairs(suggestions) do
        if suggestion:match("absolute tag") then
          found_absolute_suggestion = true
          break
        end
      end
      assert.is_true(found_absolute_suggestion, "Should suggest using absolute tag")
    end)
  end)

  describe("error aggregation", function()
    it("should aggregate multiple errors into single object", function()
      local errors = {
        {
          resource_id = "editor",
          type = "TAG_OVERFLOW",
          message = "Tag overflow"
        },
        {
          resource_id = "browser", 
          type = "TAG_SPEC_INVALID",
          message = "Invalid tag spec"
        }
      }

      local aggregated = error_handler.reporter.aggregate_errors(errors)
      
      assert.are.equal("MULTIPLE_TAG_ERRORS", aggregated.type)
      assert.are.equal(2, #aggregated.errors)
      assert.are.equal("editor", aggregated.errors[1].resource_id)
      assert.are.equal("browser", aggregated.errors[2].resource_id)
    end)

    it("should provide summary in aggregated error message", function()
      local errors = {
        {resource_id = "editor", type = "TAG_OVERFLOW", message = "Overflow"},
        {resource_id = "browser", type = "TAG_SPEC_INVALID", message = "Invalid"}
      }

      local aggregated = error_handler.reporter.aggregate_errors(errors)
      
      assert.matches("2 errors", aggregated.message)
      assert.matches("TAG_OVERFLOW", aggregated.message)
      assert.matches("TAG_SPEC_INVALID", aggregated.message)
    end)
  end)

  describe("CLI error formatting", function()
    it("should format tag resolution errors for CLI display", function()
      local error_obj = {
        type = "TAG_OVERFLOW",
        resource_id = "editor",
        message = "Tag overflow: resolved to tag 9",
        context = {resolved_index = 11, final_index = 9},
        suggestions = {"Consider using absolute tag \"9\""}
      }

      local formatted = error_handler.formatter.format_tag_error_for_cli(error_obj)
      
      assert.matches("editor", formatted)
      assert.matches("Tag overflow", formatted)
      assert.matches("absolute tag", formatted)
      assert.matches("•", formatted) -- bullet point for suggestions
    end)

    it("should format multiple errors with grouping", function()
      local errors = {
        {
          phase = "tag_resolution",
          resource_id = "editor",
          error = {type = "TAG_OVERFLOW", message = "Overflow"}
        },
        {
          phase = "spawning",
          resource_id = "browser", 
          error = {type = "COMMAND_NOT_FOUND", message = "Not found"}
        }
      }

      local formatted = error_handler.formatter.format_multiple_errors_for_cli(errors)
      
      assert.matches("TAG RESOLUTION", formatted)
      assert.matches("SPAWNING", formatted)
      assert.matches("editor", formatted)
      assert.matches("browser", formatted)
    end)
  end)
end)