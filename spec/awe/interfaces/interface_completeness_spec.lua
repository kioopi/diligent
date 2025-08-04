--[[
Interface Completeness Tests

Validates that all interface implementations (mock, dry_run) provide
the same public API contract as the awesome_interface reference.

This prevents issues where interfaces are missing critical functions,
ensuring interface contract consistency across all implementations.
--]]

local assert = require("luassert")
local mock_awful = require("spec/awe/interfaces/mock_awful")

describe("Interface Completeness", function()
  local awesome_interface, mock_interface, dry_run_interface

  setup(function()
    _G._TEST = true
  end)
  teardown(function()
    _G._TEST = nil
  end)

  before_each(function()
    -- Clean module cache to get fresh instances
    package.loaded["awe.interfaces.awesome_interface"] = nil
    package.loaded["awe.interfaces.mock_interface"] = nil
    package.loaded["awe.interfaces.dry_run_interface"] = nil

    mock_awful.setup()

    local interfaces = require("awe.interfaces")
    awesome_interface = interfaces.awesome_interface
    mock_interface = interfaces.mock_interface
    dry_run_interface = interfaces.dry_run_interface
  end)

  ---Extract all public function names from a module
  ---@param module table Module to introspect
  ---@return table functions List of public function names
  local function get_public_functions(module)
    local functions = {}

    for name, value in pairs(module) do
      -- Include public functions, exclude internal (_*) and non-functions
      if type(value) == "function" and not name:match("^_") then
        table.insert(functions, name)
      end
    end

    -- Sort for consistent comparison
    table.sort(functions)
    return functions
  end

  ---Check if a function exists and is callable
  ---@param module table Module to check
  ---@param func_name string Function name to check
  ---@return boolean exists True if function exists and is callable
  local function function_exists(module, func_name)
    return type(module[func_name]) == "function"
  end

  describe("awesome_interface as reference contract", function()
    it("should have expected core functions", function()
      local functions = get_public_functions(awesome_interface)

      -- Verify core functions exist (this serves as documentation)
      local expected_core = {
        "create_named_tag",
        "find_tag_by_name",
        "get_clients",
        "get_placement",
        "get_process_env",
        "get_screen_context",
        "spawn",
      }

      for _, func_name in ipairs(expected_core) do
        assert.is_true(
          function_exists(awesome_interface, func_name),
          "awesome_interface missing expected function: " .. func_name
        )
      end
    end)
  end)

  describe("mock_interface completeness", function()
    it(
      "should implement all public functions from awesome_interface",
      function()
        local awesome_functions = get_public_functions(awesome_interface)
        local missing_functions = {}

        for _, func_name in ipairs(awesome_functions) do
          if not function_exists(mock_interface, func_name) then
            table.insert(missing_functions, func_name)
          end
        end

        assert.are.same(
          {},
          missing_functions,
          "mock_interface is missing these functions: "
            .. table.concat(missing_functions, ", ")
        )
      end
    )

    it("should have callable implementations for all functions", function()
      local awesome_functions = get_public_functions(awesome_interface)

      for _, func_name in ipairs(awesome_functions) do
        assert.is_function(
          mock_interface[func_name],
          "mock_interface." .. func_name .. " is not a function"
        )
      end
    end)
  end)

  describe("dry_run_interface completeness", function()
    it(
      "should implement all public functions from awesome_interface",
      function()
        local awesome_functions = get_public_functions(awesome_interface)
        local missing_functions = {}

        for _, func_name in ipairs(awesome_functions) do
          if not function_exists(dry_run_interface, func_name) then
            table.insert(missing_functions, func_name)
          end
        end

        assert.are.same(
          {},
          missing_functions,
          "dry_run_interface is missing these functions: "
            .. table.concat(missing_functions, ", ")
        )
      end
    )

    it("should have callable implementations for all functions", function()
      local awesome_functions = get_public_functions(awesome_interface)

      for _, func_name in ipairs(awesome_functions) do
        assert.is_function(
          dry_run_interface[func_name],
          "dry_run_interface." .. func_name .. " is not a function"
        )
      end
    end)
  end)

  describe("interface contract validation", function()
    it(
      "should have consistent function signatures across interfaces",
      function()
        -- Test a few key functions to ensure they accept the same parameters
        -- without error (basic signature compatibility)

        -- get_screen_context - should accept nil or table
        assert.has_no.errors(function()
          awesome_interface.get_screen_context(nil)
          mock_interface.get_screen_context(nil)
          dry_run_interface.get_screen_context(nil)
        end)

        -- find_tag_by_name - should accept string and optional screen
        assert.has_no.errors(function()
          awesome_interface.find_tag_by_name("test", nil)
          mock_interface.find_tag_by_name("test", nil)
          dry_run_interface.find_tag_by_name("test", nil)
        end)

        -- create_named_tag - should accept string and optional screen
        assert.has_no.errors(function()
          awesome_interface.create_named_tag("test-tag", nil)
          mock_interface.create_named_tag("test-tag", nil)
          dry_run_interface.create_named_tag("test-tag", nil)
        end)
      end
    )

    it(
      "should handle invalid inputs gracefully across all interfaces",
      function()
        local interfaces = {
          awesome = awesome_interface,
          mock = mock_interface,
          dry_run = dry_run_interface,
        }

        for interface_name, interface in pairs(interfaces) do
          -- All interfaces should handle nil/empty inputs without crashing
          assert.has_no.errors(function()
            interface.find_tag_by_name(nil)
            interface.find_tag_by_name("")
            interface.create_named_tag(nil)
            interface.create_named_tag("")
          end, interface_name .. " should handle invalid inputs gracefully")
        end
      end
    )
  end)
end)
