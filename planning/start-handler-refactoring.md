# TDD-Based Start Handler Refactoring Plan (Phase 7)

## TDD Implementation Strategy: Red → Green → Refactor

This plan follows strict Test-Driven Development with each step beginning with failing tests, followed by minimal implementation to pass, then refactoring for quality.

## 📊 Current Status

**🎯 Phase: TDD Cycle 3 - COMPLETED ✅**  
**📅 Last Updated: August 7, 2025**  
**⏱️ Progress: 58% (7/12 hours)**  

### ✅ Completed Milestones
- **TDD Cycle 1**: Resource Format Standardization (2 hours)
  - Eliminated data transformation code (7 lines removed)
  - Consistent `{name, tag_spec}` format throughout pipeline
  - All 750 tests passing with new format
  - Handler reduced from 249 → 242 lines

- **TDD Cycle 2**: Structured Error Handling with Fallback Support (3 hours)
  - Enhanced error handling with structured error objects instead of exceptions
  - Implemented `resolve_with_fallback()` function for individual tag resolution failures
  - Updated `resolve_tag_specification()` to return `(success, result, metadata)` pattern
  - Modified `plan_tag_operations()` to collect errors in metadata instead of failing immediately
  - Enhanced error reporting using `diligent.error.reporter` framework
  - Created comprehensive fallback tests (7 test cases) in new spec file
  - All 757 tests passing with new structured error handling

- **TDD Cycle 3**: Dedicated spawn_resources Function (2 hours)
  - Created comprehensive `spawn_resources` function with helper functions
  - Eliminated duplicate spawning logic from two places in handler
  - Implemented resilient behavior - returns success if ANY resource spawns
  - Added structured error collection and comprehensive metadata
  - Created new test suite with 7 test cases (`spawn_resources_spec.lua`)
  - Updated existing handler tests to reflect new resilient behavior
  - All 764 tests passing with enhanced spawning architecture

### 🎯 Next Steps
- **TDD Cycle 4**: Simplify Handler to Orchestration Only (1-2 hours estimated)
- **TDD Cycle 5**: Integration Testing and Validation (1-2 hours estimated)

## Current Architecture Analysis

### Problems Identified

1. ✅ ~~**Data Format Inconsistency**~~: ~~Handler uses `{name, tag_spec}` but tag_mapper expects `{id, tag}`, requiring transformation at lines 154-160 in start.lua~~ → **RESOLVED in Cycle 1**
2. ✅ ~~**Fail-Fast Tag Resolution**~~: ~~Individual tag resolution failures now have fallback support, but integration layer can still fail on critical errors~~ → **RESOLVED in Cycle 2 (structured error handling with comprehensive fallbacks)**
3. ✅ ~~**Spawning Logic Duplication**~~: ~~`awe_module.spawn.spawner.spawn_with_properties` called in two places (lines 62-70 and 192-200)~~ → **RESOLVED in Cycle 3 (dedicated spawn_resources function)**
4. **Complex Error Handling**: `format_error_response()` function is 120 lines (40% of the file) with mixed concerns
5. **Mixed Responsibilities**: `format_error_response()` does both data transformation AND business logic (spawning applications) 
6. **Complex Partial Success Logic**: Nested loops and resource matching add unnecessary complexity

### 🟡 Current Error Flow (After Cycle 3 - spawn_resources Function)
```
Handler {name, tag_spec}
    ↓ (✅ NO transformation needed - FIXED!)
tag_mapper {name, tag_spec} → enhanced error handling, returns (success, result, metadata)
    ↓ (individual resolution failures have fallbacks, comprehensive error collection)
spawn_resources() → dedicated spawning function (✅ NEW!)
    ↓ (resilient spawning, succeeds if ANY resource spawns)
Handler.format_error_response() → formats errors (mixed concerns - STILL COMPLEX)
    ↓ (120 lines of complex logic - PARTIALLY IMPROVED)
Complex response structure
```

**Key Improvements in Cycle 3:**
- 🔧 **Dedicated spawn_resources Function**: Eliminated code duplication, centralized spawning logic
- 🔧 **Resilient Spawning**: Returns success if ANY resource spawns (vs fail-fast behavior)
- 🔧 **Helper Functions**: Extracted `attempt_single_spawn()` and `create_spawn_error()` for cleaner code
- 🔧 **Comprehensive Metadata**: Structured error collection with detailed spawn results
- ⚠️  **Still Complex**: Handler error response and orchestration logic remains complex (to be addressed in Cycle 4)

### 🎯 Target Clean Flow (Final Goal)
```
Handler {name, tag_spec}
    ↓ (✅ no transformation needed - ACHIEVED!)
tag_mapper {name, tag_spec} → always succeed with fallbacks, errors in metadata
    ↓ (clean resolved_tags + error metadata)
spawn_resources() → dedicated spawning function
    ↓ (clean spawned_resources + spawn metadata)
build_response() → simple response construction
```

## Enhanced Architecture Design

### New API Signatures

```lua
-- tag_mapper.resolve_tags_for_project (enhanced)
function tag_mapper.resolve_tags_for_project(resources, base_tag, interface)
  -- resources: {name, tag_spec} format (consistent throughout pipeline)
  -- Always returns true unless critical system error
  return true, resolved_tags, metadata
  -- resolved_tags: {[resource_name] = tag_object} with fallbacks for failed resolutions
  -- metadata: {tag_operations, errors, warnings, fallback_usage}
end

-- New spawn_resources function
function spawn_resources(resolved_tags, resources, awe_module)
  -- Returns true if ANY resource spawns successfully
  return success, spawned_resources, metadata
  -- spawned_resources: [{name, pid, snid, command, tag_spec}]
  -- metadata: {spawn_results, errors, total_attempted, success_count}
end

-- Simplified handler.execute
function handler.execute(payload)
  -- 1. Tag resolution (with fallbacks)
  local tag_success, resolved_tags, tag_metadata = tag_mapper.resolve_tags_for_project(
    payload.resources, -- {name, tag_spec} directly - no transformation!
    current_tag_index,
    interface
  )
  
  -- 2. Resource spawning
  local spawn_success, spawned_resources, spawn_metadata = spawn_resources(
    resolved_tags,
    payload.resources,
    awe_module
  )
  
  -- 3. Response building
  return build_combined_response(tag_metadata, spawn_metadata, payload)
end
```

### Fallback Strategy Design

**Tag Resolution Fallbacks (Priority Order)**:
1. **Successful resolution**: Use resolved tag as normal
2. **Failed relative/absolute**: Fall back to current_tag
3. **Failed named tag**: Fall back to current_tag  
4. **No current_tag available**: Fall back to tag 1
5. **Tag 1 unavailable**: Fall back to tag 1 with mock object

**Error Collection**: All resolution failures are collected in `metadata.errors` but don't prevent operation completion.

**Success Strategy**: `tag_mapper` returns `true` unless critical system errors (interface failure, invalid inputs, etc.)

## TDD Implementation Cycles

## ✅ Step 1: Standardize Resource Format (TDD Cycle 1) - COMPLETED

### ✅ 1.1 RED: Write Failing Tests for New Resource Format - COMPLETED

**✅ Updated `spec/tag_mapper/core_spec.lua`**:
- ✅ Changed `plan_tag_operations` test resources from `{id, tag}` to `{name, tag_spec}`
- ✅ Updated all mock_resources, overflow_resources, duplicate_resources, and error test resources
- ✅ **Result**: 10 tests failed as expected - core.lua couldn't process new resource format

**✅ Updated `spec/tag_mapper/integration_spec.lua`**:
- ✅ Updated all resource definitions to use new `{name, tag_spec}` format
- ✅ Updated mock_resources, overflow test resources, error handling resources
- ✅ **Result**: Multiple integration tests failed due to resource format mismatch

**✅ Updated `spec/tag_mapper/init_spec.lua`**:
- ✅ Updated batch API test resources to new format
- ✅ Fixed all resource format inconsistencies
- ✅ **Result**: Tests failed with resource access errors (vim, relative_tag, etc.)

**✅ Updated `spec/diligent/handlers/start_handler_spec.lua`**:
- ✅ Removed transformation logic from phase5_handler test
- ✅ Now passes `payload.resources` directly to tag_mapper
- ✅ **Result**: Tests validated no transformation needed

### ✅ 1.2 GREEN: Update tag_mapper to Use New Format - COMPLETED

**✅ Modified `lua/tag_mapper/core.lua`**:
- ✅ Line 257: Changed `resource.id` → `resource.name`  
- ✅ Line 261: Changed `resource.tag` → `resource.tag_spec`
- ✅ Line 270: Changed `resource_id = resource.id` → `resource_id = resource.name`
- ✅ Line 285: Updated overflow warning resource_id
- ✅ Line 298: Updated error context resource_id
- ✅ Line 206: Updated function documentation

**✅ Modified `lua/tag_mapper/integration.lua`**:
- ✅ Line 166: Updated function documentation to reflect new format

**✅ Modified `lua/tag_mapper/init.lua`**:
- ✅ Line 86: Changed `{id = "single", tag = tag_spec}` → `{name = "single", tag_spec = tag_spec}`
- ✅ Line 139: Updated function documentation
- ✅ **Result**: Single resource wrapper now uses consistent format

**✅ Removed transformation in `lua/diligent/handlers/start.lua`**:
- ✅ Removed lines 154-160 (tag_mapper_resources transformation loop)
- ✅ Line 154: Now passes `payload.resources` directly to tag_mapper
- ✅ **Result**: 7 lines removed, no data transformation needed

### ✅ 1.3 REFACTOR: Clean Up Naming and Consistency - COMPLETED

- ✅ **Code Formatting**: Applied `make fmt` to fix whitespace and indentation
- ✅ **Quality Checks**: All tests pass (750 successes, 0 failures, 0 errors)
- ✅ **Documentation**: Updated all function signatures and comments
- ✅ **Consistency**: Verified no remaining `id`/`tag` references in pipeline

**✅ Cycle 1 Success Criteria - ALL MET**:
- ✅ **All tests pass**: 750 successes with new `{name, tag_spec}` format
- ✅ **No transformation needed**: Handler passes resources directly (7 lines removed)
- ✅ **Consistent format**: `{name, tag_spec}` used throughout entire pipeline
- ✅ **No regressions**: All existing functionality preserved
- ✅ **File reduction**: start.lua reduced from 249 → 242 lines

**🎉 Cycle 1 Results:**
- **Files Modified**: 6 core files + 4 test files
- **Lines Removed**: 7 lines of transformation code from handler
- **Tests Updated**: 40+ test cases converted to new format
- **Architecture Improvement**: Eliminated impedance mismatch between handler and tag_mapper
- **Code Quality**: Consistent resource format throughout entire pipeline

## ✅ Step 2: Structured Error Handling with Fallback Support (TDD Cycle 2) - COMPLETED

### ✅ 2.1 RED: Write Failing Tests for Enhanced Error Handling - COMPLETED

**✅ Created `spec/tag_mapper/fallback_strategy_spec.lua`**:
- ✅ Test individual tag resolution failure uses current_tag fallback
- ✅ Test named tag creation failure behavior  
- ✅ Test error collection in metadata instead of operation failure
- ✅ Test parameter validation still works (critical errors)
- ✅ Test `resolve_tags_for_project` returns structured results
- ✅ Test metadata contains comprehensive error information
- ✅ **Result**: 7 test cases created, all initially failed as expected

**✅ Updated existing tag_mapper tests**:
- ✅ Updated tests in core_spec.lua, init_spec.lua, integration_spec.lua
- ✅ Updated tests to expect new `(success, result, metadata)` return pattern
- ✅ Updated mock interfaces to support new error handling requirements
- ✅ **Result**: Multiple test failures as expected due to changed error handling approach

### ✅ 2.2 GREEN: Implement Structured Error Handling in tag_mapper - COMPLETED

**✅ Modified `lua/tag_mapper/core.lua`**:
- ✅ Enhanced `resolve_tag_specification()` to return `(success, result, metadata)` instead of throwing exceptions
- ✅ Added structured error object creation using `diligent.error.reporter`
- ✅ Implemented comprehensive metadata collection (timing, error context, etc.)
- ✅ Added `resolve_with_fallback()` helper function for individual tag resolution failures
- ✅ Updated `plan_tag_operations()` to collect errors in metadata instead of failing immediately
- ✅ Enhanced error collection and resource processing logic
- ✅ **Result**: Core module now uses structured error handling throughout

### ✅ 2.3 REFACTOR: Code Quality and Error Handling Optimization - COMPLETED

- ✅ **Code Formatting**: Applied `make fmt` to ensure consistent formatting
- ✅ **Quality Checks**: All 757 tests passing with new error handling
- ✅ **Error Object Structure**: Consistent structured error objects throughout
- ✅ **Metadata Enhancement**: Comprehensive timing and context information
- ✅ **Interface Cleanup**: Removed unused parameters and variables where possible
- ✅ **Documentation**: Updated function signatures and comments for new patterns

**✅ Cycle 2 Success Criteria - ACHIEVED**:
- ✅ **Structured Error Handling**: Core functions return `(success, result, metadata)` instead of throwing
- ✅ **Enhanced Error Collection**: Individual failures collected in metadata with detailed context
- ✅ **Partial Fallback Support**: Failed tag resolutions fallback to current_tag where applicable
- ✅ **Comprehensive Testing**: 7 new fallback test cases plus updated existing tests
- ✅ **Backward Compatibility**: All existing functionality preserved with enhanced error reporting
- ✅ **Test Coverage**: All 757 tests passing (up from 750 in Cycle 1)

**🎉 Cycle 2 Results:**
- **Files Modified**: 3 core tag_mapper files + 1 new spec file + 4 updated test files
- **Architecture Improvement**: Structured error handling eliminates exception-based failures
- **Error Enhancement**: Comprehensive error objects with timing, context, and fallback information
- **Testing Quality**: Added robust fallback testing suite (spec/tag_mapper/fallback_strategy_spec.lua)
- **System Reliability**: Enhanced resilience to individual tag resolution failures
- **Developer Experience**: Better debugging with detailed metadata and structured error objects

## ✅ Step 3: Create Dedicated spawn_resources Function (TDD Cycle 3) - COMPLETED

### ✅ 3.1 RED: Write Failing Tests for spawn_resources Function - COMPLETED

**✅ Created `spec/diligent/handlers/spawn_resources_spec.lua`**:
- ✅ Test `spawn_resources(resolved_tags, resources, awe_module)` function signature
- ✅ Test successful spawning returns `true, spawned_resources, metadata`
- ✅ Test partial success (some spawn, some fail) returns `true` with errors in metadata
- ✅ Test complete failure (none spawn) returns `false, error_object`
- ✅ Test metadata contains comprehensive spawn results and error details
- ✅ Test consistent resource data structure in spawned_resources
- ✅ Test proper error object creation for spawn failures
- ✅ **Result**: 7 test cases created, all initially failed as expected because function didn't exist

**✅ Updated `spec/diligent/handlers/start_handler_spec.lua`**:
- ✅ Updated test expectations to reflect new resilient behavior (partial success vs fail-fast)
- ✅ Handler now succeeds if ANY resource spawns successfully  
- ✅ Updated test assertions to match new spawn_resources behavior
- ✅ **Result**: Tests initially failed due to changed spawning behavior

### ✅ 3.2 GREEN: Implement spawn_resources Function - COMPLETED

**✅ Added `handler.spawn_resources` function to `lua/diligent/handlers/start.lua`**:
- ✅ Implemented complete `spawn_resources(resolved_tags, resources, awe_instance)` function
- ✅ Returns `(success, spawned_resources, metadata)` pattern following architecture design
- ✅ Resilient behavior: returns `true` if ANY resource spawns successfully 
- ✅ Handles empty resource lists gracefully (returns success for empty list)
- ✅ Creates structured error objects using established patterns
- ✅ Comprehensive metadata collection with spawn_results, errors, and statistics

**✅ Updated handler to use spawn_resources**:
- ✅ Modified `format_error_response` to use `spawn_resources` for partial success handling
- ✅ Updated main `execute` function to use `spawn_resources` instead of inline logic
- ✅ Eliminated duplicate spawning code from two places in handler
- ✅ Fixed resource filtering to only spawn resources with resolved tags

### ✅ 3.3 REFACTOR: Extract Helper Functions and Optimize - COMPLETED

- ✅ **Helper Functions**: Extracted `attempt_single_spawn()` and `create_spawn_error()` helper functions  
- ✅ **Code Organization**: Cleaner, more maintainable spawn_resources function with single responsibilities
- ✅ **Parameter Cleanup**: Fixed variable shadowing issues (renamed awe_module to awe_instance in helpers)
- ✅ **Quality Checks**: Applied `make fmt` for consistent formatting, fixed linting warnings
- ✅ **Error Handling**: Optimized error collection and metadata handling
- ✅ **Documentation**: Added comprehensive function documentation and type annotations

**✅ Cycle 3 Success Criteria - ALL MET**:
- ✅ **Dedicated Function**: New `spawn_resources` function handles all spawning logic
- ✅ **Consistent Pattern**: Follows `(success, result, metadata)` pattern throughout 
- ✅ **Code Deduplication**: Complete removal of duplicate spawning code from handler (~30 lines eliminated)
- ✅ **Resilient Behavior**: Comprehensive error collection without fail-fast behavior (succeeds if ANY resource spawns)
- ✅ **Separation of Concerns**: Clear separation between tag resolution and resource spawning
- ✅ **Test Coverage**: All 764 tests passing with new spawning architecture

**🎉 Cycle 3 Results:**
- **Files Modified**: 1 core handler file + 1 new test spec file + 1 updated test file
- **Architecture Improvement**: Centralized spawning logic eliminates code duplication  
- **Behavioral Enhancement**: More resilient partial success handling vs fail-fast approach
- **Testing Quality**: Added comprehensive spawn_resources test suite (7 test cases)
- **Code Clarity**: Helper functions make spawning logic more readable and maintainable
- **Handler Size**: File increased to 300 lines (due to new function) but eliminated duplication

## Step 4: Simplify Handler to Orchestration Only (TDD Cycle 4)

### 4.1 RED: Write Failing Tests for Simplified Handler

**Update `spec/diligent/handlers/start_handler_spec.lua`**:
- Test simplified `execute` function with clean orchestration flow
- Test proper sequencing: tag resolution → spawning → response building
- Test error handling when tag_mapper has critical failures
- Test response building with combined tag and spawn metadata
- Test removal of data transformation code
- Test clean separation of concerns in handler logic
- **Expected**: Tests fail because handler still has complex structure

**Create `spec/diligent/handlers/response_builder_spec.lua`**:
- Test `build_combined_response` function with various scenarios
- Test response format with tag metadata and spawn metadata
- Test success response structure
- Test partial failure response structure  
- Test complete failure response structure
- **Expected**: Tests fail because response builder doesn't exist

### 4.2 GREEN: Implement Simplified Handler Architecture

**Rewrite handler.execute in `lua/diligent/handlers/start.lua`**:

```lua
---Build combined response from tag and spawn metadata
---@param tag_metadata table Metadata from tag resolution
---@param spawn_metadata table Metadata from spawning operation
---@param payload table Original request payload
---@return boolean success Overall operation success
---@return table response Response object with comprehensive information
local function build_combined_response(tag_metadata, spawn_metadata, payload)
  local total_attempted = #payload.resources
  local spawned_count = spawn_metadata.success_count or 0
  local has_spawn_errors = spawn_metadata.error_count > 0
  local has_tag_errors = tag_metadata.errors and #tag_metadata.errors > 0
  
  -- Determine overall success
  local overall_success = spawned_count > 0
  
  if overall_success then
    -- Success response (some or all resources spawned)
    local response = {
      project_name = payload.project_name,
      spawned_resources = spawn_metadata.result or {},
      total_spawned = spawned_count,
      tag_operations = tag_metadata.tag_operations or {},
    }
    
    -- Include warnings/errors in metadata if present
    if has_tag_errors or has_spawn_errors then
      response.warnings = {
        tag_errors = tag_metadata.errors or {},
        spawn_errors = spawn_metadata.errors or {},
      }
    end
    
    return true, response
  else
    -- Failure response (no resources spawned)
    local errors = {}
    
    -- Collect tag errors
    if has_tag_errors then
      for _, error_obj in ipairs(tag_metadata.errors) do
        table.insert(errors, {
          phase = "tag_resolution",
          resource_id = error_obj.resource_id,
          error = error_obj,
        })
      end
    end
    
    -- Collect spawn errors  
    if has_spawn_errors then
      for _, error_obj in ipairs(spawn_metadata.errors) do
        table.insert(errors, {
          phase = "spawning",
          resource_id = error_obj.resource_id,
          error = error_obj,
        })
      end
    end
    
    local response = {
      project_name = payload.project_name,
      error_type = "COMPLETE_FAILURE",
      errors = errors,
      metadata = {
        total_attempted = total_attempted,
        success_count = 0,
        error_count = #errors,
      },
    }
    
    return false, response
  end
end

function handler.execute(payload)
  -- Get current tag index using tag_mapper
  local current_tag_index = tag_mapper.get_current_tag(awe_module.interface)
  
  -- Step 1: Batch tag resolution for all resources (with fallbacks)
  local tag_success, resolved_tags, tag_metadata = tag_mapper.resolve_tags_for_project(
    payload.resources, -- {name, tag_spec} directly - no transformation!
    current_tag_index,
    awe_module.interface
  )
  
  -- Handle critical tag_mapper failure (rare)
  if not tag_success then
    return false, {
      error = "Critical tag mapper error: " .. (resolved_tags or "unknown error"),
      project_name = payload.project_name,
    }
  end
  
  -- Step 2: Spawn resources using resolved tags
  local spawn_success, spawned_resources, spawn_metadata = spawn_resources(
    resolved_tags,
    payload.resources,
    awe_module
  )
  
  -- Store results in spawn_metadata for response building
  if spawn_success then
    spawn_metadata.result = spawned_resources
  end
  
  -- Step 3: Build combined response
  return build_combined_response(tag_metadata, spawn_metadata, payload)
end
```

### 4.3 REFACTOR: Final Code Organization and Optimization

- Ensure all helper functions are properly scoped and documented
- Optimize error collection and response building logic
- Remove any remaining unused code or variables
- Ensure consistent error object structures throughout
- Add comprehensive function documentation
- Optimize performance by avoiding unnecessary object creation

**Cycle 4 Success Criteria**:
- Handler execute function is ~30 lines (down from 100+)
- Clear orchestration flow: tag resolution → spawning → response building
- Complete removal of format_error_response function (~120 lines removed)
- No data transformation or format conversion code
- Clean separation of concerns throughout the handler
- Comprehensive error handling without complex nested logic

## Step 5: Integration Testing and Validation (TDD Cycle 5)

### 5.1 RED: Write Comprehensive End-to-End Tests

**Create `spec/integration/refactored_start_flow_spec.lua`**:
- Test complete flow with mixed success/failure scenarios
- Test tag fallback behavior with spawn success
- Test error collection and metadata propagation
- Test response format consistency across different scenarios
- Test no regressions in existing functionality
- Test performance improvements with complex project configurations
- **Expected**: Tests may reveal integration issues between refactored components

### 5.2 GREEN: Fix Any Integration Issues

- Resolve any data flow problems between refactored components
- Fix inconsistencies in error object formats
- Ensure metadata propagation works correctly
- Address any performance regressions
- Fix any edge cases revealed by integration testing

### 5.3 REFACTOR: Final Performance and Quality Optimization

- Optimize error collection and metadata handling for large projects
- Ensure memory efficiency in fallback tag creation
- Clean up any remaining code duplication
- Validate comprehensive test coverage across all components
- Ensure documentation is updated for new architecture

**Cycle 5 Success Criteria**:
- All integration tests pass without regressions
- Performance is equal or better than original implementation
- Error reporting is more comprehensive and user-friendly
- Code is significantly more maintainable and testable
- Test coverage is maintained or improved

## TDD Quality Gates

**After Each Cycle**:
1. **All tests must pass**: `make test`
2. **No linting errors**: `make lint`
3. **Code properly formatted**: `make fmt`
4. **Test coverage maintained**: ≥60% overall, ≥80% on refactored paths

**Before Moving to Next Cycle**:
- Previous cycle's refactoring is complete
- All existing functionality preserved
- No regressions in test suite
- Code quality maintained or improved
- Documentation updated for changes

## Expected Outcomes

### Code Quality Improvements

**Before Refactoring** (Original):
- `start.lua`: 249 lines with complex mixed concerns
- `format_error_response`: 120 lines (48% of file)
- Spawning logic duplicated in 2 places
- Data transformation required between layers
- Fail-fast error handling loses context

**Current State** (After Cycle 3):
- `start.lua`: 300 lines with dedicated spawn_resources function (temporary increase due to new function)
- `spawn_resources`: ~70 lines focused function with helper functions
- `format_error_response`: ~120 lines (still complex, to be addressed in Cycle 4)
- No data transformation needed ✅
- Comprehensive error collection with fallbacks ✅
- Eliminated spawning code duplication ✅

**Target After Refactoring** (After Cycle 4-5):
- `start.lua`: ~150-180 lines with clear orchestration 
- `spawn_resources`: ~70 lines focused function
- `build_response`: ~30 lines simple formatter
- Complete removal of complex `format_error_response`
- Clean orchestration: tag resolution → spawning → response building

### User Experience Improvements

1. **Robust Fallback Behavior**: Users see what would happen even with tag resolution errors
2. **Comprehensive Error Reporting**: All errors collected and displayed with context
3. **Partial Success Handling**: Users informed of what succeeded despite failures
4. **Consistent API Responses**: Predictable response format across scenarios
5. **Better Performance**: Reduced complexity and object creation overhead

### Developer Experience Improvements

1. **Clear Architecture**: Single-responsibility functions with obvious purposes
2. **Easier Testing**: Focused functions with predictable input/output
3. **Better Debugging**: Comprehensive metadata for troubleshooting
4. **Maintainable Code**: Separation of concerns makes changes easier
5. **Consistent Patterns**: Same `success, result, metadata` pattern throughout

## Timeline Estimate (TDD Cycles)

- ✅ **Cycle 1** (Resource Format Standardization): **COMPLETED** - 2 hours actual
- ✅ **Cycle 2** (Structured Error Handling): **COMPLETED** - 3 hours actual (comprehensive error framework implementation)
- ✅ **Cycle 3** (spawn_resources Function): **COMPLETED** - 2 hours actual (extraction, testing, and helper functions)
- **Cycle 4** (Handler Simplification): 1-2 hours (orchestration focus)
- **Cycle 5** (Integration Testing): 1-2 hours (validation and optimization)

**Progress: 7/12 hours completed (58%)**  
**Remaining Estimate: 2-4 hours** with comprehensive TDD coverage

**Note**: All major refactoring cycles are proceeding on schedule. Cycle 3 was completed efficiently with comprehensive testing and helper function extraction, setting up excellent foundation for the final simplification phases.

## Success Criteria

- **Code Reduction**: 60%+ reduction in start.lua complexity (249 → ~100 lines)
- **Consistency**: Single resource format throughout pipeline
- **Robustness**: Fallback tag strategy prevents operation failures
- **Separation of Concerns**: Clear boundaries between tag resolution, spawning, and formatting
- **Error Handling**: Comprehensive collection without fail-fast behavior
- **Test Coverage**: ≥80% coverage on all refactored components
- **Performance**: Equal or better performance than original implementation
- **User Experience**: More informative responses with comprehensive error context

This TDD approach ensures every change is backed by tests, maintains quality throughout the process, and results in a robust, well-tested, and maintainable handler architecture.