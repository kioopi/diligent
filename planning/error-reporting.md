# TDD-Based Error Reporting Enhancement Plan (Phase 7)

## TDD Implementation Strategy: Red → Green → Refactor

This plan follows strict Test-Driven Development with each step beginning with failing tests, followed by minimal implementation to pass, then refactoring for quality.

## Current Situation Analysis

**Problems Identified:**
1. **Error Pattern Inconsistency**: tag_mapper modules use `error()` calls but start handler expects `return false, error_message` pattern
2. **Limited Error Context**: Users receive generic "Tag resolution failed" messages without specific details
3. **Poor Error Collection**: First error causes immediate failure instead of collecting multiple errors
4. **Unused Rich Error Framework**: `awe/error/*` framework is well-designed but unused
5. **No Tag Resolution Error Types**: Current error classification focuses on spawn errors, missing tag-specific errors

**Current Error Flow:**
```
tag_mapper core/integration → error() → pcall() catch in init.lua → generic message → CLI
```

**Target Error Flow:**
```
tag_mapper → structured error objects → handler → rich CLI error display
```

## Enhanced Error Object Structure

```lua
-- Error object structure:
{
  type = "TAG_RESOLUTION_ERROR",
  category = "validation", -- validation, execution, system
  resource_id = "editor",
  tag_spec = 2,
  message = "Tag overflow: resolved to tag 9",
  context = {
    base_tag = 2,
    resolved_index = 11,
    original_spec = 2
  },
  suggestions = {
    "Consider using absolute tag specification (\"9\")",
    "Check if you intended a relative offset"
  },
  metadata = {
    timestamp = os.time(),
    phase = "planning" -- planning, execution
  }
}
```

## ✅ Step 1: Extract and Enhance Error Framework (TDD Cycle 1) - COMPLETED

### 1.1 RED: Write Failing Tests for Enhanced Error Framework ✅
**Created `spec/diligent/error/`** with comprehensive test suite:
- ✅ Test enhanced error types (`TAG_SPEC_INVALID`, `TAG_OVERFLOW`, etc.)
- ✅ Test error aggregation functionality (multiple errors in single operation)
- ✅ Test tag-specific error classification patterns
- ✅ Test structured error object creation with context and suggestions
- ✅ Test error formatter for CLI-friendly output

### 1.2 GREEN: Move and Enhance awe/error Framework ✅
- ✅ Move `lua/awe/error/` → `lua/diligent/error/`
- ✅ Add new tag resolution error types and classification patterns
- ✅ Implement error aggregation support
- ✅ Add tag-specific suggestions (overflow → use absolute tags, etc.)
- ✅ **ACHIEVED**: All new tests pass (38 new error tests → 0 failures)

### 1.3 REFACTOR: Clean Up Error Framework Architecture ✅
- ✅ Optimize error classification performance
- ✅ Ensure consistent error object structure
- ✅ Clean up code duplication in error handling

**Cycle 1 Results:**
- **722 test successes** (up from 687)
- **0 test failures** in error framework
- **Enhanced error types**: TAG_SPEC_INVALID, TAG_OVERFLOW, TAG_NAME_INVALID, MULTIPLE_TAG_ERRORS
- **Rich error objects** with context, suggestions, and metadata
- **CLI formatting support** with error grouping and actionable suggestions

## ✅ Step 2: Convert tag_mapper/core.lua (TDD Cycle 2) - COMPLETED

### 2.1 RED: Write Failing Tests for Return-Based Errors ✅
**Updated `spec/tag_mapper/core_spec.lua`**:
- ✅ Test that validation errors return `nil, error_object` instead of throwing
- ✅ Test that logic errors return structured error objects with context
- ✅ Test error objects contain suggestions and metadata
- ✅ Test boundary conditions return appropriate error types
- ✅ **CONFIRMED**: All 9 new tests failed initially (error() throwing → returned errors)

### 2.2 GREEN: Convert core.lua Error Handling ✅
- ✅ Replace all `error()` calls with `return nil, create_error_object()`
- ✅ Implement error object creation with context (base_tag, resolved_index, etc.)
- ✅ Add appropriate suggestions for each error type
- ✅ **ACHIEVED**: All core error tests pass (29 error handling tests)

### 2.3 REFACTOR: Optimize Error Object Creation ✅
- ✅ Extract error creation logic into helper functions (`create_validation_error`, `create_tag_spec_error`)
- ✅ Ensure consistent error object structure
- ✅ Add error context optimization and resource error aggregation

**Cycle 2 Results:**
- **730 test successes** (up from 722)
- **100% error handling test coverage** in core module
- **Error aggregation support** for individual resource failures  
- **Updated all existing tests** from pcall() pattern to return-based pattern
- **Enhanced error context** with base_tag, resolved_index, tag_spec_type
- **No regressions** in existing functionality

## ✅ Step 3: Convert tag_mapper/integration.lua (TDD Cycle 3) - COMPLETED

### 3.1 RED: Write Failing Tests for Error Aggregation ✅
**Updated `spec/tag_mapper/integration_spec.lua`**:
- ✅ Test multiple resource failures return aggregated error object
- ✅ Test partial success scenarios (some succeed, some fail) 
- ✅ Test error collection continues after individual failures
- ✅ Test interface errors that return structured objects
- ✅ Test core planning errors and structured error returns
- ✅ **CONFIRMED**: All new tests failed initially (error() throwing → returned errors)

### 3.2 GREEN: Convert integration.lua Error Handling ✅
- ✅ Replace all `error()` calls with `return nil, error_obj` pattern
- ✅ Implement error aggregation for tag creation failures
- ✅ Support both simple failures and structured error objects from interfaces
- ✅ Handle planning errors from core module appropriately
- ✅ **ACHIEVED**: All integration error tests pass (17 integration tests)

### 3.3 REFACTOR: Optimize Error Aggregation Logic ✅
- ✅ Extract common validation logic into reusable `validate_inputs` helper
- ✅ Create `handle_tag_creation_failure` helper for consistent error handling
- ✅ Add `should_fail_on_planning_errors` helper for planning error logic
- ✅ Fix validation bug where `pairs()` skipped nil values
- ✅ Clean up code duplication and improve modularity

**Cycle 3 Results:**
- **734 test successes** (up from 730)
- **0 test failures** in integration module
- **Error Aggregation**: Multiple tag creation failures collected instead of fail-fast
- **Interface Compatibility**: Handles both simple failures and structured error objects  
- **Planning Error Handling**: Proper handling of core module errors
- **Clean Architecture**: Well-structured, modular helper functions

## ✅ Step 4: Update tag_mapper/init.lua (TDD Cycle 4) - COMPLETED

### 4.1 RED: Identify Failing Handler Test ✅
**Handler test failed with structured error incompatibility**:
- ✅ Handler test: "should handle tag resolution failures gracefully" - FAILED
- ✅ **ROOT CAUSE**: init.lua using `pcall()` around integration calls
- ✅ **ISSUE**: integration.lua returns `nil, error_obj` but pcall() succeeds with `workflow_result = nil`
- ✅ **CRASH**: Line 168 tries to access `workflow_result.execution` when `workflow_result` is nil

### 4.2 GREEN: Fix init.lua Error Handling ✅
- ✅ Replace `pcall()` wrapper with direct error handling
- ✅ Handle structured error objects from integration layer
- ✅ Preserve error message formatting for backwards compatibility
- ✅ **ACHIEVED**: Handler test passes, no regressions introduced

**Code Change Summary:**
```lua
-- OLD (broken):
local success, workflow_result = pcall(function()
  return integration.resolve_tags_for_project(resources, base_tag, interface)
end)
if not success then
  return false, "Tag resolution failed: " .. workflow_result
end

-- NEW (fixed):
local workflow_result, error_obj = integration.resolve_tags_for_project(resources, base_tag, interface)
if not workflow_result then
  local error_message = error_obj and error_obj.message or "unknown error"
  return false, "Tag resolution failed: " .. error_message
end
```

### 4.3 REFACTOR: Not Required ✅
- ✅ Code change was minimal and clean
- ✅ No additional refactoring needed
- ✅ Error message formatting preserved for handler compatibility

**Cycle 4 Results:**
- **735 test successes** (up from 734)
- **0 test failures, 0 errors**
- **Handler Integration Fixed**: Clean transition from integration → init.lua → handler
- **Backwards Compatibility**: Handler still receives expected error message format
- **Pattern Consistency**: Return-based errors throughout tag_mapper pipeline

## Step 5: Enhance Start Handler (TDD Cycle 5)

### 5.1 RED: Write Failing Tests for Handler Error Collection
**Update `spec/diligent/handlers/start_spec.lua`**:
- Test handler collects structured errors from tag_mapper
- Test handler continues processing after tag resolution failures when possible
- Test enhanced error response format includes partial successes
- Test error objects are properly structured for CLI consumption
- **Tests will fail initially** because handler expects old error format

### 5.2 GREEN: Update Handler Error Processing
- Parse structured error objects from tag_mapper
- Implement error collection during processing
- Create enhanced error response format with partial successes
- Differentiate between fatal vs recoverable errors
- **Goal**: Make all handler error tests pass

### 5.3 REFACTOR: Optimize Handler Error Logic
- Extract error processing patterns
- Optimize error collection performance
- Clean up error response structuring

**Enhanced Handler Response Format:**
```lua
-- Success response (unchanged)
return true, {
  project_name = "example",
  spawned_resources = {...},
  total_spawned = 2,
  tag_operations = {...}
}

-- Enhanced error response
return false, {
  project_name = "example", 
  error_type = "PARTIAL_FAILURE", -- or "COMPLETE_FAILURE"
  errors = { -- Array of detailed error objects
    {
      phase = "tag_resolution",
      resource_id = "editor",
      error = error_object_with_suggestions
    },
    {
      phase = "spawning", 
      resource_id = "browser",
      error = spawn_error_object
    }
  },
  partial_success = {
    spawned_resources = {...}, -- Resources that succeeded
    total_spawned = 1
  },
  metadata = {
    total_attempted = 3,
    success_count = 1,
    error_count = 2
  }
}
```

## Step 6: Transform CLI Error Display (TDD Cycle 6)

### 6.1 RED: Write Failing Tests for Enhanced CLI Output
**Update `spec/cli/start_command_integration_spec.lua`**:
- Test CLI parses structured error responses correctly
- Test grouped error display (tag resolution, spawning, etc.)
- Test partial success display alongside errors
- Test enhanced dry-run output with warnings
- Test actionable suggestions are displayed
- **Tests will fail initially** because CLI expects old error format

### 6.2 GREEN: Update CLI Error Display
- Parse structured error responses from handler
- Implement grouped error display with categories
- Add partial success reporting
- Enhance dry-run output with warnings and context
- Display actionable suggestions for each error type
- **Goal**: Make all CLI error display tests pass

### 6.3 REFACTOR: Optimize CLI Error Formatting
- Extract error formatting patterns into reusable components
- Optimize error grouping and display logic
- Ensure consistent CLI output formatting

**Enhanced CLI Output Examples:**
```bash
# Multiple errors with details and suggestions
$ ./cli/workon start example-project
✗ Failed to start project: example-project (2 errors, 1 success)

TAG RESOLUTION ERRORS:
  ✗ editor: Tag overflow (tag 11 → 9)
    • Consider using absolute tag "9" instead
    • Check if relative offset +9 was intended

SPAWNING ERRORS:  
  ✗ browser: Command not found
    • Check if 'firefox-nightly' is installed
    • Verify command name spelling
    • Add application directory to PATH

PARTIAL SUCCESS:
  ✓ terminal: Started successfully (PID: 12345)
```

**Enhanced Dry-Run Output:**
```bash
$ ./cli/workon start example-project --dry-run
DRY RUN: Would start project example-project

RESOURCES TO START:
  ✓ editor: gedit → tag 4 (current 2 + offset 2)
  ⚠ browser: firefox → tag 9 (overflow: 11 → 9)  
  ✓ terminal: alacritty → tag "workspace"

WARNINGS:
  • browser: Tag overflow detected (11 → 9)
    Suggestion: Use absolute tag "9" for clarity

Would create 1 named tag: "workspace"
```

## Step 7: Integration Testing (TDD Cycle 7)

### 7.1 RED: Write Comprehensive Integration Tests
**Create `spec/integration/error_reporting_spec.lua`**:
- Test complete error flow: tag_mapper → handler → CLI
- Test multiple error scenarios end-to-end
- Test partial success scenarios through full pipeline
- Test dry-run error preview functionality
- **Tests will fail initially** if integration issues exist

### 7.2 GREEN: Fix Integration Issues
- Resolve any integration problems between components
- Ensure error objects flow correctly through entire pipeline
- Fix any formatting or structure inconsistencies
- **Goal**: Make all integration tests pass

### 7.3 REFACTOR: Optimize End-to-End Performance
- Optimize error processing performance across pipeline
- Clean up any remaining code duplication
- Ensure optimal memory usage for error objects

## TDD Quality Gates

**After Each Cycle:**
1. **All tests must pass**: `make test`
2. **No linting errors**: `make lint` 
3. **Code properly formatted**: `make fmt`
4. **Test coverage maintained**: ≥60% overall, ≥80% on error paths

**Before Moving to Next Cycle:**
- Previous cycle's refactoring is complete
- All existing functionality preserved
- No regressions in test suite
- Code quality maintained or improved

## Expected TDD Benefits

1. **Confidence**: Each change backed by failing tests first
2. **Quality**: Refactoring ensures clean, maintainable code
3. **Coverage**: Error handling paths thoroughly tested
4. **Regression Prevention**: Comprehensive test suite prevents future breaks
5. **Documentation**: Tests serve as living documentation of error behavior

## Timeline Estimate (TDD Cycles)

- ✅ **Cycle 1** (Error Framework): ~2 hours - **COMPLETED**
- ✅ **Cycle 2** (core.lua): ~2 hours - **COMPLETED**
- ✅ **Cycle 3** (integration.lua): 2-3 hours - **COMPLETED**
- ✅ **Cycle 4** (init.lua): 0.5 hours - **COMPLETED**
- **Cycle 5** (Handler): 1-2 hours
- **Cycle 6** (CLI): 2-3 hours
- **Cycle 7** (Integration): 1-2 hours

**Progress: 6.5/15 hours completed (43%)**  
**Remaining: 4.5-8 hours** with comprehensive testing and quality assurance

## Success Criteria

- **Rich Error Messages**: Users see specific problems and actionable suggestions
- **Error Aggregation**: Multiple errors collected and displayed together  
- **Partial Success Support**: Users informed of what succeeded despite failures
- **Enhanced Dry-Run**: Preview shows warnings and potential issues
- **Consistent Error Patterns**: All modules use return-based error handling
- **Test Coverage**: ≥80% coverage on error handling paths
- **User Experience**: Error messages guide users toward solutions

This TDD approach ensures every change is backed by tests, maintains quality throughout the process, and results in a robust, well-tested error reporting system.

## 🎉 Implementation Status Summary

### Completed Phases (4/7)

**✅ Phase 1: Enhanced Error Framework**
- **Files Created**: `lua/diligent/error/` (4 modules)
- **Tests Added**: 38+ comprehensive error framework tests
- **New Error Types**: TAG_SPEC_INVALID, TAG_OVERFLOW, TAG_NAME_INVALID, MULTIPLE_TAG_ERRORS
- **Result**: Rich error objects with context, suggestions, and CLI formatting support

**✅ Phase 2: Core Module Error Conversion**
- **Files Modified**: `lua/tag_mapper/core.lua`, `spec/tag_mapper/core_spec.lua`
- **Conversion**: All `error()` calls → structured return pattern (`nil, error_object`)
- **Tests Updated**: 29 error handling tests (9 new + 20 updated)
- **Features Added**: Error aggregation, resource-level error collection, enhanced context
- **Result**: 730 test successes, no regressions, 100% error test coverage

**✅ Phase 3: Integration Layer Error Conversion**
- **Files Modified**: `lua/tag_mapper/integration.lua`, `spec/tag_mapper/integration_spec.lua`
- **Conversion**: All `error()` calls → structured return pattern with error aggregation
- **Tests Added**: 17 integration tests including new structured error handling tests
- **Features Added**: Tag creation error aggregation, interface error support, planning error handling
- **Code Quality**: Extracted reusable helper functions, fixed validation bugs
- **Result**: 734 test successes, clean modular architecture

**✅ Phase 4: API Layer Error Integration**
- **Files Modified**: `lua/tag_mapper/init.lua`
- **Fix**: Replaced `pcall()` pattern with direct structured error handling
- **Integration**: Clean transition from integration → init.lua → handler layers
- **Compatibility**: Maintained backwards compatibility for handler expectations
- **Result**: 735 test successes, 0 failures, 0 errors - complete success

### Next Steps

With the tag_mapper pipeline now fully converted, remaining phases focus on user experience:
- **Phase 5**: Enhance start handler (collect and format structured errors)
- **Phase 6**: Transform CLI display (rich error formatting with suggestions)
- **Phase 7**: Integration testing (end-to-end error flow validation)

### Key Achievements

1. **Complete Tag Mapper Pipeline**: Core → Integration → Init.lua all use structured errors
2. **Error Aggregation**: Multiple tag creation failures collected instead of fail-fast
3. **Interface Compatibility**: Handles both simple and structured error objects from interfaces
4. **Pattern Consistency**: Return-based errors throughout the entire tag resolution pipeline
5. **Test Coverage**: Comprehensive TDD coverage with 735 passing tests
6. **Clean Architecture**: Well-structured, modular code with helper functions
7. **Handler Integration**: Seamless error flow from tag_mapper to handler layer
8. **User Experience Foundation**: Rich error framework ready for CLI enhancement