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

## ✅ Step 5: Enhance Start Handler (TDD Cycle 5) - COMPLETED

### 5.1 RED: Write Failing Tests for Handler Error Collection ✅
**Updated `spec/diligent/handlers/start_handler_spec.lua`**:
- ✅ Test handler collects structured errors from tag_mapper
- ✅ Test handler continues processing after tag resolution failures when possible  
- ✅ Test enhanced error response format includes partial successes
- ✅ Test error objects are properly structured for CLI consumption
- ✅ Test complete vs partial failure scenarios
- ✅ Test multiple error types in single response
- ✅ **CONFIRMED**: All new tests failed initially (old error format → enhanced response format)

### 5.2 GREEN: Update Handler Error Processing ✅
- ✅ Implemented `format_error_response()` helper function to process structured error objects
- ✅ Added support for `MULTIPLE_TAG_ERRORS` with partial success data
- ✅ Enhanced error response format with error_type, errors array, partial_success, and metadata
- ✅ Maintained backwards compatibility for simple single-resource failure cases
- ✅ **ACHIEVED**: All handler error tests pass with enhanced structured error support

### 5.3 REFACTOR: Optimize Handler Error Logic ✅
- ✅ Fixed test isolation issues by creating separate `phase5_handler` for Phase 5 tests  
- ✅ Maintained backwards compatibility for existing spawning failure behavior
- ✅ Clean separation between new structured error handling and legacy error format
- ✅ Preserved fail-fast behavior for spawning errors to maintain existing test expectations

**Cycle 5 Results:**
- **739 test successes** (up from 735)
- **0 test failures, 0 errors**
- **Structured Error Support**: Handler processes rich error objects from tag_mapper with context, suggestions, and metadata
- **Partial Success Handling**: Can spawn some resources successfully even when others fail during tag resolution
- **Backwards Compatibility**: Existing tests continue to pass with original error format expectations
- **Test Quality**: Proper isolation between test suites prevents interference

### 🔍 **Architectural Analysis: Error Response Architecture**

**Discovery**: The implementation of `format_error_response()` revealed architectural duplication between error handling components.

**Current Error Flow Architecture:**
```
tag_mapper (structured errors) 
    ↓
handler.format_error_response (transforms + partial spawning)
    ↓  
Enhanced response format → CLI (needs formatting)
```

**Identified Components:**

1. **`lua/cli/error_reporter.lua`** (Simple CLI Error Handling)
   - **Role**: Basic CLI error reporting with Unix exit codes
   - **Scope**: Simple error messages, validation errors, file not found
   - **Format**: Plain text with categorized exit codes
   - **Usage**: General CLI command failures

2. **`lua/diligent/error/formatter.lua`** (Rich Error Formatting) 
   - **Role**: Advanced error formatting for structured error objects
   - **Scope**: Tag resolution errors, multi-error scenarios, partial success
   - **Format**: Rich CLI output (✗, ✓, ⚠), grouped errors, suggestions
   - **Usage**: Complex error scenarios from enhanced error reporting system

3. **`handler.format_error_response()`** (Bridge Function - **Needs Refactoring**)
   - **Current Role**: Transforms tag_mapper errors + attempts partial spawning
   - **Issue**: Mixing data transformation with business logic
   - **Gap**: Creates response format but doesn't use existing rich formatter

**Architectural Problems Identified:**
- **Responsibility Mixing**: `format_error_response` does transformation AND spawning logic
- **Formatting Duplication**: Basic error structure creation vs rich formatting capability
- **CLI Integration Gap**: CLI doesn't use the rich error formatting system
- **Component Confusion**: Unclear when to use `cli/error_reporter.lua` vs `diligent/error/formatter.lua`

**🔧 Recommended Solution for Phase 6:**

Before implementing CLI enhancements, refactor the error response architecture:

1. **Separate Concerns in `format_error_response`**:
   ```lua
   -- Keep: Data transformation + partial spawning (business logic)
   -- Remove: CLI-specific formatting logic
   -- Focus: Clean data structure for CLI to format
   ```

2. **Integrate Rich Error Formatting in CLI**:
   ```lua
   -- CLI detects enhanced error response format
   -- Uses diligent/error/formatter.lua for rich display
   -- Maintains backwards compatibility with simple errors
   ```

3. **Clarify Component Usage**:
   - **`cli/error_reporter.lua`**: Validation errors, file not found, basic CLI errors
   - **`diligent/error/formatter.lua`**: Tag resolution errors, multi-phase errors, partial success

**Target Architecture:**
```
tag_mapper (structured errors)
    ↓
handler.format_error_response (clean data transformation + partial spawning)
    ↓
Enhanced response format → CLI detects format
    ↓
diligent/error/formatter.lua (rich CLI formatting)
    ↓
User sees well-formatted errors with suggestions
```

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

## ✅ Step 6: Transform CLI Error Display (TDD Cycle 6) - COMPLETED

### 6.0 ARCH: Architectural Analysis ✅
**Analysis Conclusion**: The `format_error_response()` function was well-architected and didn't require refactoring
- ✅ **Discovery**: The real issue was CLI integration, not handler architecture
- ✅ **Focus Shift**: From handler refactoring to CLI response format detection and rich formatting integration
- ✅ **Architecture Validation**: Confirmed clean separation between data transformation and presentation

### 6.1 RED: Write Failing Tests for Enhanced CLI Output ✅
**Created `spec/integration/cli_error_display_spec.lua`**:
- ✅ Test CLI detects enhanced vs simple error response formats
- ✅ Test rich CLI formatting with symbols, grouped errors, and suggestions
- ✅ Test partial success display alongside errors
- ✅ Test multiple error types with proper grouping
- ✅ Test backwards compatibility with simple error responses
- ✅ Test success response formatting with resource details
- ✅ Test end-to-end handler → CLI → formatted output integration
- ✅ **CONFIRMED**: All 8 tests failed initially (missing `cli.response_formatter` module)

### 6.2 GREEN: Update CLI Error Display ✅
- ✅ **Created** `lua/cli/response_formatter.lua` with comprehensive formatting capabilities
- ✅ **Format Detection**: Automatic detection of enhanced, simple, and success response types
- ✅ **Rich Formatting**: Integration with `diligent/error/formatter.lua` for structured error display
- ✅ **Backwards Compatibility**: Seamless handling of existing simple error formats
- ✅ **CLI Integration**: Updated `cli/commands/start.lua` to use response formatter
- ✅ **Enhanced Display**: Grouped errors by phase (tag_resolution, spawning) with suggestions
- ✅ **Partial Success**: Clear display of successful resources alongside failures
- ✅ **ACHIEVED**: All 8 CLI error display tests pass

### 6.3 REFACTOR: Optimize CLI Error Formatting ✅
- ✅ **Performance**: Formatter instance reuse to avoid repeated creation
- ✅ **Code Quality**: Helper functions (`build_output`, `build_error_header`) for maintainability  
- ✅ **Architecture**: Clean separation between detection, formatting, and output logic
- ✅ **Consistency**: Unified approach to section building and line management
- ✅ **Optimization**: Eliminated code duplication in error response formatting

**Cycle 6 Results:**
- **747 test successes** (up from 739)
- **0 test failures, 0 errors**
- **Rich CLI Error Display**: Enhanced formatting with ✗, ✓, ⚠ symbols and grouped errors
- **Partial Success Support**: Users see what succeeded alongside failures
- **Complete Backwards Compatibility**: Existing error formats continue to work seamlessly  
- **Architecture Integration**: Clean use of existing rich error formatter without duplication
- **User Experience**: Actionable error messages with suggestions and context

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
- ✅ **Cycle 5** (Handler): 1.5 hours - **COMPLETED**
- ✅ **Cycle 6** (CLI): 2.5 hours - **COMPLETED**
- **Cycle 7** (Integration): 1-2 hours

**Progress: 10.5/15 hours completed (70%)**  
**Remaining: 1-2 hours** with comprehensive integration testing and final optimization

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

### Completed Phases (6/7)

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

**✅ Phase 5: Enhanced Start Handler**
- **Files Modified**: `lua/diligent/handlers/start.lua`, `spec/diligent/handlers/start_handler_spec.lua`
- **Implementation**: Added `format_error_response()` function for structured error processing
- **Features**: Partial success handling, error aggregation, enhanced response format
- **Tests Added**: 4 comprehensive error collection tests with proper isolation
- **Architecture Discovery**: Identified error formatting duplication requiring Phase 6 refactoring
- **Result**: 739 test successes, 0 failures, 0 errors - complete handler enhancement

**✅ Phase 6: Transform CLI Error Display**
- **Files Created**: `lua/cli/response_formatter.lua`, `spec/integration/cli_error_display_spec.lua`
- **Files Modified**: `cli/commands/start.lua` 
- **Implementation**: CLI response formatter with format detection and rich error display
- **Features**: Rich CLI formatting, partial success display, backwards compatibility, error grouping
- **Tests Added**: 8 comprehensive CLI error display integration tests
- **Architecture**: Clean integration with existing rich error formatter without duplication
- **Result**: 747 test successes, 0 failures, 0 errors - complete CLI enhancement

### Next Steps

With the complete error reporting pipeline now implemented, only final validation remains:
- **Phase 7**: Integration testing (end-to-end error flow validation and performance optimization)

### Key Achievements

1. **Complete Error Pipeline**: tag_mapper → handler → CLI with structured errors end-to-end
2. **Rich CLI Error Display**: Users see ✗, ✓, ⚠ symbols, grouped errors, and actionable suggestions
3. **Partial Success Support**: Clear display of successful resources alongside failures
4. **Error Aggregation**: Multiple failures collected and displayed together instead of fail-fast
5. **Interface Compatibility**: Handles both simple and structured error objects seamlessly
6. **Pattern Consistency**: Return-based errors throughout the entire pipeline
7. **Test Coverage**: Comprehensive TDD coverage with 747 passing tests
8. **Clean Architecture**: Well-structured, modular code with proper separation of concerns
9. **Backwards Compatibility**: All existing functionality preserved while adding enhancements
10. **Format Detection**: Automatic detection and handling of different error response types
11. **Performance Optimization**: Formatter instance reuse and efficient error processing
12. **User Experience**: Production-ready error reporting with context and suggestions