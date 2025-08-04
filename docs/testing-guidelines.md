# Diligent Testing Guidelines

**Version**: 1.0  
**Date**: August 3, 2025  
**Status**: Active

## Overview

This document establishes comprehensive testing standards for the Diligent project, based on lessons learned from real testing challenges and anti-patterns discovered during development. These guidelines ensure reliable, maintainable, and robust test suites that provide genuine confidence in code quality.

## Table of Contents

- [Core Testing Principles](#core-testing-principles)
- [Test Structure and Organization](#test-structure-and-organization)
- [Interface Testing Best Practices](#interface-testing-best-practices)
- [Mocking and Test Doubles](#mocking-and-test-doubles)
- [Anti-Patterns to Avoid](#anti-patterns-to-avoid)
- [Test Coverage Guidelines](#test-coverage-guidelines)
- [Integration Testing](#integration-testing)
- [Test Maintenance](#test-maintenance)

## Core Testing Principles

### 1. Test Behavior, Not Implementation

Focus tests on what the code should do, not how it does it:

```lua
-- Good: Tests behavior
it("should spawn application on specified tag", function()
  mock_interface.set_spawn_config({success = true, pid = 1234})
  
  local pid, snid, msg = spawner.spawn_with_properties("firefox", "+1", {})
  
  assert.are.equal(1234, pid)
  assert.is_truthy(msg:match("SUCCESS"))
  
  local spawn_call = mock_interface.get_last_spawn_call()
  assert.is_truthy(spawn_call.command:match("firefox"))
end)

-- Bad: Tests implementation details
it("should call spawn_with_properties internally", function()
  local called = false
  spawner.spawn_with_properties = function() -- DON'T DO THIS
    called = true
  end
  
  spawner.spawn_simple("firefox", "+1")
  assert.is_true(called)
end)
```

### 2. Tests Should Be Isolated and Deterministic

Each test should:
- Start with a clean state
- Not depend on other tests
- Produce the same result every time

```lua
describe("Module Tests", function()
  before_each(function()
    mock_interface.reset() -- Clean state for each test
  end)
  
  it("should handle test case A", function()
    -- Test-specific setup
    mock_interface.set_spawn_config({success = true, pid = 1234})
    -- Test implementation
  end)
  
  it("should handle test case B", function()
    -- Different test-specific setup 
    mock_interface.set_spawn_config({success = false, error = "Command not found"})
    -- Test implementation
  end)
end)
```

### 3. Interface Contract Testing

Ensure all interface implementations provide the same API:

```lua
-- Example from spec/awe/interfaces/interface_completeness_spec.lua
describe("Interface Completeness", function()
  it("should implement all public functions from reference interface", function()
    local reference_functions = get_public_functions(awesome_interface)
    local missing_functions = {}
    
    for _, func_name in ipairs(reference_functions) do
      if not function_exists(mock_interface, func_name) then
        table.insert(missing_functions, func_name)
      end
    end
    
    assert.are.same({}, missing_functions, 
      "mock_interface is missing: " .. table.concat(missing_functions, ", "))
  end)
end)
```

## Test Structure and Organization

### Standard Test File Structure

```lua
--[[
Module Test Suite

Tests for [module_name] functionality including normal operations,
error conditions, and edge cases.
--]]

local assert = require("luassert")
local module_name = require("module_name")

describe("Module Name", function()
  local test_interface
  
  before_each(function()
    -- Setup fresh test environment
    test_interface = create_test_interface()
    test_interface.reset()
  end)
  
  after_each(function()
    -- Cleanup if needed
    test_interface.cleanup()
  end)
  
  describe("public_function", function()
    describe("normal operation", function()
      it("should handle valid input correctly", function()
        -- Test normal case
      end)
      
      it("should return expected format", function()
        -- Test return value structure
      end)
    end)
    
    describe("error conditions", function()
      it("should handle nil input gracefully", function()
        -- Test error handling
      end)
      
      it("should provide helpful error messages", function()
        -- Test error message quality
      end)
    end)
    
    describe("edge cases", function()
      it("should handle empty string input", function()
        -- Test edge case
      end)
    end)
  end)
end)
```

### Test Naming Conventions

Use descriptive test names that explain the scenario:

```lua
-- Good: Descriptive test names
it("should spawn application successfully with valid command", function()
it("should return error message when command not found", function()
it("should handle timeout when application takes too long to start", function()

-- Bad: Vague test names  
it("should work", function()
it("test spawn", function()
it("error case", function()
```

## Interface Testing Best Practices

### Interface Completeness Testing

Create automated tests to ensure interface consistency:

```lua
---Extract all public function names from a module
local function get_public_functions(module)
  local functions = {}
  
  for name, value in pairs(module) do
    if type(value) == "function" and not name:match("^_") then
      table.insert(functions, name)
    end
  end
  
  table.sort(functions)
  return functions
end

-- Test all interfaces implement the same contract
describe("Interface Contract Validation", function()
  local interfaces = {
    awesome = awesome_interface,
    mock = mock_interface,
    dry_run = dry_run_interface
  }
  
  it("should have consistent function signatures", function()
    for interface_name, interface in pairs(interfaces) do
      assert.has_no.errors(function()
        interface.get_screen_context(nil)
        interface.find_tag_by_name("test", nil)
      end, interface_name .. " should handle standard calls")
    end
  end)
end)
```

### Configuration-Based Interface Testing

Use configuration instead of runtime patching:

```lua
-- Good: Configuration-based testing
describe("spawn operations", function()
  before_each(function()
    mock_interface.reset()
  end)
  
  it("should handle successful spawn", function()
    mock_interface.set_spawn_config({
      success = true,
      pid = 1234,
      snid = "test-snid"
    })
    
    local result = spawn_module.spawn_application("firefox")
    
    assert.are.equal(1234, result.pid)
    assert.are.equal("test-snid", result.snid)
  end)
  
  it("should handle spawn failure", function()
    mock_interface.set_spawn_config({
      success = false,
      error = "Command not found"
    })
    
    local result = spawn_module.spawn_application("nonexistent")
    
    assert.is_nil(result.pid)
    assert.are.equal("Command not found", result.error)
  end)
end)
```

## Mocking and Test Doubles

### Interface Mocking Patterns

Create comprehensive mock interfaces that support configuration:

```lua
-- Good: Configurable mock interface
local mock_interface = {}
local mock_data = {
  spawn_config = {success = true, pid = 1234, snid = "mock-snid"},
  last_spawn_call = nil
}

function mock_interface.spawn(command, properties)
  -- Capture call for inspection
  mock_data.last_spawn_call = {
    command = command,
    properties = properties
  }
  
  -- Return configured behavior
  if mock_data.spawn_config.success then
    return mock_data.spawn_config.pid, mock_data.spawn_config.snid
  else
    return mock_data.spawn_config.error
  end
end

function mock_interface.set_spawn_config(config)
  mock_data.spawn_config = config
end

function mock_interface.get_last_spawn_call()
  return mock_data.last_spawn_call
end

function mock_interface.reset()
  mock_data.spawn_config = {success = true, pid = 1234, snid = "mock-snid"}
  mock_data.last_spawn_call = nil
end
```

### External Dependency Mocking

For external dependencies, use controlled mocking with proper cleanup:

```lua
describe("file operations", function()
  local original_io_open
  
  before_each(function()
    original_io_open = io.open
  end)
  
  after_each(function()
    io.open = original_io_open -- Always restore
  end)
  
  it("should handle file read success", function()
    io.open = function(filename, mode)
      if filename:match("/test/file") then
        return {
          read = function() return "test content" end,
          close = function() end
        }
      end
      return nil
    end
    
    local content = module.read_file("/test/file")
    assert.are.equal("test content", content)
  end)
end)
```

## Anti-Patterns to Avoid

### ❌ Runtime Interface Patching

**Problem**: Directly modifying interface functions during tests
```lua
-- DON'T DO THIS
mock_interface.spawn = function(command, properties)
  return 1234, "snid"
end
```

**Solution**: Use configuration-based mocking
```lua
-- DO THIS INSTEAD  
mock_interface.set_spawn_config({
  success = true,
  pid = 1234,
  snid = "snid"
})
```

### ❌ Module Function Replacement

**Problem**: Replacing module functions for testing
```lua
-- DON'T DO THIS
spawner.spawn_with_properties = function(app, tag, config)
  called_with = {app, tag, config}
  return 1234, "snid", "message"
end
```

**Solution**: Test through the interface layer
```lua
-- DO THIS INSTEAD
mock_interface.set_spawn_config({success = true, pid = 1234, snid = "snid"})
local result = spawner.spawn_simple("firefox", "+1")
local call = mock_interface.get_last_spawn_call()
assert.is_truthy(call.command:match("firefox"))
```

### ❌ Global State Pollution

**Problem**: Tests affecting each other through shared state
```lua
-- DON'T DO THIS - No cleanup between tests
describe("tests", function()
  it("test A", function()
    some_global.value = "A"
    -- test logic
  end)
  
  it("test B", function()
    -- This test may fail if test A ran first
    assert.is_nil(some_global.value) -- Fails!
  end)
end)
```

**Solution**: Proper test isolation
```lua
-- DO THIS INSTEAD
describe("tests", function()
  before_each(function()
    some_global.reset()
  end)
  
  it("test A", function()
    some_global.value = "A"
    -- test logic
  end)
  
  it("test B", function()
    -- Clean state guaranteed
    assert.is_nil(some_global.value) -- Passes!
  end)
end)
```

### ❌ Testing Implementation Details

**Problem**: Tests that break when implementation changes
```lua
-- DON'T DO THIS
it("should call internal_helper_function", function()
  local called = false
  module.internal_helper_function = function()
    called = true
  end
  
  module.public_function()
  assert.is_true(called)
end)
```

**Solution**: Test public behavior and contracts
```lua
-- DO THIS INSTEAD
it("should process input correctly", function()
  local result = module.public_function("test input")
  
  assert.is_table(result)
  assert.are.equal("expected output", result.value)
end)
```

### ❌ Incomplete Interface Mocks

**Problem**: Mock interfaces missing functions from the real interface
```lua
-- DON'T DO THIS - Incomplete mock
local mock_interface = {
  get_screen_context = function() return {} end
  -- Missing: spawn, get_placement, etc.
}
```

**Solution**: Complete interface implementation with automated validation
```lua
-- DO THIS INSTEAD - Complete mock with validation
-- Use interface completeness tests to ensure all functions are implemented
describe("Interface Completeness", function()
  it("should implement all functions from reference interface", function()
    local reference_functions = get_public_functions(awesome_interface)
    for _, func_name in ipairs(reference_functions) do
      assert.is_function(mock_interface[func_name],
        "Missing function: " .. func_name)
    end
  end)
end)
```

## Test Coverage Guidelines

### Coverage Targets

- **≥80% coverage** for core functionality modules
- **≥60% coverage** for integration modules  
- **100% coverage** for critical path functions
- **All error conditions** must have test cases

### Coverage Analysis

```bash
# Run tests with coverage
make test

# Check coverage report
luacov-reporter

# Ensure coverage meets minimum thresholds
```

### What to Test

**✅ Always Test:**
- Public API functions
- Error conditions and edge cases
- Input validation
- Return value formats
- Integration points

**✅ Consider Testing:**
- Performance characteristics
- Resource cleanup
- Concurrent access (if applicable)

**❌ Avoid Testing:**
- Private implementation details
- Third-party library behavior
- Language features

## Integration Testing

### Interface Integration

Test that different interfaces work correctly with the same modules:

```lua
describe("Cross-Interface Integration", function()
  local interfaces = {
    mock = mock_interface,
    dry_run = dry_run_interface
  }
  
  for interface_name, interface in pairs(interfaces) do
    describe("with " .. interface_name .. " interface", function()
      it("should handle spawn workflow", function()
        local spawn = create_spawn_module(interface)
        
        -- Configure interface-specific behavior
        if interface.set_spawn_config then
          interface.set_spawn_config({success = true, pid = 1234})
        end
        
        local result = spawn.spawner.spawn_simple("firefox", "+1")
        
        -- Test should work with any interface
        assert.is_number(result.pid)
        assert.is_string(result.message)
      end)
    end)
  end
end)
```

### End-to-End Testing

Test complete workflows across module boundaries:

```lua
describe("Complete Spawn Workflow", function()
  it("should spawn application with tag resolution", function()
    -- Setup
    mock_interface.reset()
    mock_interface.set_spawn_config({success = true, pid = 1234})
    
    -- Execute complete workflow
    local awe = create_awe_instance(mock_interface)
    local pid, snid, msg = awe.spawn.spawner.spawn_with_properties(
      "firefox", "+2", {floating = true}
    )
    
    -- Verify end-to-end behavior
    assert.are.equal(1234, pid)
    assert.is_truthy(msg:match("SUCCESS"))
    
    local call = mock_interface.get_last_spawn_call()
    assert.is_truthy(call.command:match("firefox"))
    assert.is_true(call.properties.floating)
  end)
end)
```

## Test Maintenance

### Keeping Tests Updated

1. **Run tests after every change**: Use `make test` before committing
2. **Update tests when APIs change**: Maintain test-code alignment
3. **Review test failures**: Don't ignore or skip failing tests
4. **Refactor tests**: Keep test code clean and maintainable

### Test Debugging

```lua
-- Add debug output when tests fail
it("should process complex data", function()
  local input = create_test_data()
  local result = module.process(input)
  
  -- Add context for failures
  assert.is_table(result, "Expected table result, got: " .. type(result))
  assert.are.equal("expected", result.value, 
    "Input: " .. inspect(input) .. ", Result: " .. inspect(result))
end)
```

### Continuous Testing

```bash
# Watch for changes and run tests automatically
make test-watch

# Run specific test files
busted spec/awe/spawn/spawner_spec.lua

# Run tests with verbose output
busted --verbose spec/
```

## Best Practices Summary

### ✅ Do

1. **Use configuration-based mocking** instead of runtime patching
2. **Test behavior and contracts** rather than implementation
3. **Ensure proper test isolation** with setup/teardown
4. **Create comprehensive interface mocks** with validation
5. **Write descriptive test names** that explain the scenario
6. **Test all error conditions** and edge cases
7. **Maintain high test coverage** for critical functionality
8. **Use automated interface contract validation**

### ❌ Don't

1. **Patch interfaces or modules** during test execution
2. **Test private implementation details**
3. **Create incomplete mock interfaces**
4. **Let tests depend on each other**
5. **Ignore test failures or skip tests**
6. **Write tests that are harder to understand than the code**
7. **Test third-party library behavior**
8. **Pollute global state without cleanup**

---

**Remember**: Good tests provide confidence in your code's correctness, catch regressions early, and serve as documentation of expected behavior. When tests are hard to write, it often indicates design problems in the code being tested.

For specific testing tools and commands, see the project's [development documentation](../README.md#development).