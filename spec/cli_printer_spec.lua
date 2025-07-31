local assert = require("luassert")

describe("CLI Printer Module", function()
  local cli_printer
  local original_print
  local captured_output

  before_each(function()
    -- Capture print output for testing
    captured_output = {}
    original_print = _G.print
    _G.print = function(msg)
      table.insert(captured_output, msg)
    end

    -- Reset module cache to get fresh instance
    package.loaded["cli_printer"] = nil
    cli_printer = require("cli_printer")
  end)

  after_each(function()
    -- Restore original print function
    _G.print = original_print
  end)

  describe("success", function()
    it("should print message with green checkmark", function()
      cli_printer.success("Operation completed")

      assert.are.equal(1, #captured_output)
      assert.matches("✓", captured_output[1])
      assert.matches("Operation completed", captured_output[1])
      assert.matches("\027%[32m", captured_output[1]) -- Green color code
      assert.matches("\027%[0m", captured_output[1]) -- Reset color code
    end)

    it("should handle empty message", function()
      cli_printer.success("")

      assert.are.equal(1, #captured_output)
      assert.matches("✓", captured_output[1])
    end)
  end)

  describe("error", function()
    it("should print message with red X mark", function()
      cli_printer.error("Something went wrong")

      assert.are.equal(1, #captured_output)
      assert.matches("✗", captured_output[1])
      assert.matches("Something went wrong", captured_output[1])
      assert.matches("\027%[31m", captured_output[1]) -- Red color code
      assert.matches("\027%[0m", captured_output[1]) -- Reset color code
    end)

    it("should handle empty message", function()
      cli_printer.error("")

      assert.are.equal(1, #captured_output)
      assert.matches("✗", captured_output[1])
    end)
  end)

  describe("info", function()
    it("should print message with blue info symbol", function()
      cli_printer.info("Here is some information")

      assert.are.equal(1, #captured_output)
      assert.matches("ℹ", captured_output[1])
      assert.matches("Here is some information", captured_output[1])
      assert.matches("\027%[34m", captured_output[1]) -- Blue color code
      assert.matches("\027%[0m", captured_output[1]) -- Reset color code
    end)

    it("should handle empty message", function()
      cli_printer.info("")

      assert.are.equal(1, #captured_output)
      assert.matches("ℹ", captured_output[1])
    end)
  end)

  describe("module structure", function()
    it("should export all required functions", function()
      assert.is_function(cli_printer.success)
      assert.is_function(cli_printer.error)
      assert.is_function(cli_printer.info)
    end)

    it("should be a proper module table", function()
      assert.is_table(cli_printer)
    end)
  end)
end)
