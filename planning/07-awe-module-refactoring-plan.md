# AwesomeWM Module Refactoring Plan

**Document Version**: 1.2  
**Date**: August 3, 2025  
**Status**: Phase 2 Completed - Instance-Based Architecture Implemented  
**Dependencies**: Completed client spawning exploration (Section 4)

## Overview

This document outlines the comprehensive refactoring plan to eliminate code duplication, create consistent APIs, and properly separate AwesomeWM interaction concerns through the new `lua/awe/` module architecture.

### Background

During code review of the client spawning exploration work, significant duplication and architectural issues were identified:

1. **Major Duplication**: `awesome_client_manager.resolve_tag_spec()` completely reimplements tag resolution logic that already exists in `tag_mapper`
2. **Inconsistent APIs**: Different function signatures and return patterns across modules
3. **Violated SRP**: `awesome_client_manager` handles too many responsibilities
4. **Misplaced Interfaces**: AwesomeWM interfaces belong in a shared location, not within `tag_mapper`

### Goals

- ✅ **Eliminate 200+ lines** of duplicate tag resolution code
- ✅ **Create modular architecture** with 8+ focused modules
- ✅ **Establish consistent APIs** across the entire project  
- ✅ **Separate AwesomeWM concerns** into dedicated `lua/awe/` module
- ✅ **Maintain CLI compatibility** without adapter modules
- ✅ **Enable better testing** through clean interfaces and modularity

## Progress Summary

### Completed Phases
- ✅ **Phase 1: Infrastructure Setup** (December 2024)
  - Created foundational `awe` module structure
  - Moved all interfaces from `tag_mapper` to `awe/interfaces/`
  - Implemented direct property access API
  - Achieved 100% test coverage with TDD approach
  - Updated all dependencies and references

- ✅ **Phase 2: Extract Client Management Modules** (August 2025)
  - ✅ **Architectural Revolution**: Implemented instance-based dependency injection
  - ✅ **Extracted 4 Client Modules**: tracker, properties, info, wait
  - ✅ **Enhanced Testing**: Clean DI pattern eliminates test complexity
  - ✅ **Consistent APIs**: Factory pattern with standardized interfaces
  - ✅ **42 New Tests**: Added comprehensive test coverage for all modules

### Current Status
- **Total Progress**: 2/7 phases complete (29%)
- **Architecture Foundation**: ✅ Revolutionary instance-based DI implemented
- **Test Coverage**: ✅ Maintained at 537 tests passing (+42 new tests)
- **Quality Gates**: ✅ All passing (tests, lint, format)
- **Code Reduction**: ✅ Monolithic client manager broken into 4 focused modules

### Next Phase
- **Phase 3: Extract Spawning Modules** - Ready to begin
  - Extract spawning logic, configuration, and environment handling
  - Apply same factory pattern and dependency injection approach
  - Continue building on the proven architecture

## Target Architecture

### Directory Structure

```
lua/
├── awe/                                    # AwesomeWM interaction layer
│   ├── init.lua                           # Main awe module API
│   ├── interfaces/                        # AwesomeWM interface abstractions
│   │   ├── awesome_interface.lua          # Live AwesomeWM interface
│   │   ├── dry_run_interface.lua          # Dry-run interface
│   │   └── mock_interface.lua             # Mock interface for testing
│   ├── client/                            # Client management modules ✅ COMPLETED
│   │   ├── init.lua                       # Client factory with dependency injection ✅
│   │   ├── tracker.lua                    # Client finding & tracking ✅
│   │   ├── properties.lua                 # Client property management ✅
│   │   ├── info.lua                       # Client information retrieval ✅
│   │   └── wait.lua                       # Client waiting & polling ✅
│   ├── spawn/                             # Spawning modules
│   │   ├── spawner.lua                    # Core spawning logic
│   │   ├── configuration.lua              # Spawn configuration building
│   │   └── environment.lua                # Environment variable handling
│   ├── tag/                               # Tag operation modules
│   │   └── resolver.lua                   # String-based tag resolution wrapper
│   ├── error/                             # Error handling modules
│   │   ├── classifier.lua                 # Error classification
│   │   ├── reporter.lua                   # Error reporting & aggregation
│   │   └── formatter.lua                  # User-friendly formatting
│   └── client_manager.lua                 # High-level API (refactored)
├── tag_mapper/                            # Pure tag resolution logic
│   ├── init.lua                           # (updated - no interfaces)
│   ├── core.lua                           # (unchanged)
│   └── integration.lua                    # (unchanged)
└── dbus_communication.lua                 # (unchanged)
```

### API Design Standards

**Function Signature Pattern**:
```lua
function module.operation(primary_input, context, options)
  -- primary_input: main data (tag_spec, app_name, pid, etc.)
  -- context: environmental data (base_tag, screen_context, etc.)
  -- options: configuration (timeout, properties, etc.)
end
```

**Return Pattern**:
```lua
return success, result, metadata
-- success: boolean success indicator
-- result: actual result data or error message  
-- metadata: additional context (timing, warnings, etc.)
```

**Error Objects**:
```lua
{
  type = "ERROR_TYPE_CONSTANT",
  message = "User-friendly message", 
  context = {...},
  suggestions = {...}
}
```

## Implementation Phases

### Phase 1: Infrastructure Setup ✅ **COMPLETED**

**Objective**: Create the foundational structure for the awe module

**Status**: ✅ **COMPLETED** (December 2024)  
**Implementation Approach**: Strict Test-Driven Development (TDD)

**Completed Tasks**:

1. **✅ Created Directory Structure**
   ```bash
   mkdir -p lua/awe/{interfaces,client,spawn,tag,error}
   ```

2. **✅ Moved Interfaces from tag_mapper**
   - ✅ Moved `lua/tag_mapper/interfaces/awesome_interface.lua` → `lua/awe/interfaces/`
   - ✅ Moved `lua/tag_mapper/interfaces/dry_run_interface.lua` → `lua/awe/interfaces/`
   - ✅ Created `lua/awe/interfaces/mock_interface.lua` for testing

3. **✅ Created Main awe Module with Direct Property Access**
   - ✅ Created `lua/awe/init.lua` as the primary API entry point
   - ✅ Implemented direct property access API: `awe.awesome_interface`, `awe.dry_run_interface`, `awe.mock_interface`

4. **✅ Updated Rockspec and Cleaned Architecture**
   - ✅ Initially added awe modules to `diligent-scm-0.rockspec`
   - ✅ **IMPROVED**: Cleaned up rockspec to single entry: `["awe"] = "lua/awe/init.lua"`
   - ✅ **MODERNIZED**: Updated all imports to use `require("awe").interfaces.X` pattern
   - ✅ Achieved 75% reduction in rockspec entries (4 → 1)

5. **✅ Updated All Dependencies and Modernized Interface Access**
   - ✅ Updated `tag_mapper/init.lua` to use new interface access pattern
   - ✅ Updated all test files to use modernized interface locations
   - ✅ Updated example scripts to use consistent patterns
   - ✅ Removed old empty `tag_mapper/interfaces/` directory
   - ✅ **NEW**: Implemented consistent `require("awe").interfaces.X` across codebase

6. **✅ Comprehensive Test Coverage**
   - ✅ Created `spec/awe/init_spec.lua` - Tests main awe module API
   - ✅ Created `spec/awe/interfaces/awesome_interface_spec.lua` - Full interface testing
   - ✅ Created `spec/awe/interfaces/dry_run_interface_spec.lua` - Dry-run functionality  
   - ✅ Created `spec/awe/interfaces/mock_interface_spec.lua` - Mock interface for testing

**TDD Implementation Process**:
- 🔴 **Red Phase**: Created comprehensive failing tests first
- 🟢 **Green Phase**: Implemented minimal code to make tests pass  
- 🔧 **Refactor Phase**: Cleaned up and improved code quality

**Success Criteria Achieved**:
- ✅ All awe modules can be required successfully
- ✅ Direct property access works: `awe.awesome_interface.get_screen_context()`
- ✅ All moved interfaces work identically to before (100% test coverage maintained)
- ✅ No broken dependencies in existing code
- ✅ All 495 tests pass (0 failures, 0 errors) → **NOW**: 537 tests pass
- ✅ Code passes linting and formatting checks
- ✅ Mock interface enables isolated testing

**Actual Duration**: 3 hours

---

### Phase 2: Extract Client Management Modules ✅ **COMPLETED**

**Objective**: Break down the monolithic client management into focused modules

**Status**: ✅ **COMPLETED** (August 2025)
**Implementation Approach**: Revolutionary Instance-Based Dependency Injection + Strict TDD

**Completed Tasks**:

1. **✅ Architectural Revolution: Instance-Based Dependency Injection**
   - ✅ Eliminated hacky `package.loaded` overwriting in tests
   - ✅ Implemented factory pattern: `awe.create(interface)` for clean testing
   - ✅ Created `awe/client/init.lua` factory for all client modules
   - ✅ Enabled multiple instances with different interfaces (dry-run, mock, real)

2. **✅ Created awe/client/tracker.lua** (5 functions, 18 tests)
   - ✅ Extracted: `find_by_pid`, `find_by_env`, `find_by_property`, `find_by_name_or_class`, `get_all_tracked_clients`
   - ✅ Implemented factory pattern with dependency injection
   - ✅ 100% test coverage with clean mock interface usage

3. **✅ Created awe/client/properties.lua** (2 functions, 10 tests)
   - ✅ Extracted: `get_client_properties`, `set_client_property`
   - ✅ Added property validation and type conversion logic
   - ✅ Comprehensive testing of property management utilities

4. **✅ Created awe/client/info.lua** (2 functions, 7 tests)
   - ✅ Extracted: `get_client_info`, `read_process_env`
   - ✅ Added robust file system mocking for environment parsing
   - ✅ Enhanced client information analysis capabilities

5. **✅ Created awe/client/wait.lua** (1 function, 7 tests)
   - ✅ Extracted: `wait_and_set_properties`
   - ✅ Added configurable timeout and polling logic
   - ✅ Improved client appearance detection with comprehensive testing

**Revolutionary Architecture Example**:
```lua
-- New Factory Pattern with Dependency Injection
local function create_tracker(interface)
  local tracker = {}
  
  function tracker.find_by_pid(target_pid)
    local clients = interface.get_clients()  -- Clean DI
    -- ... logic
  end
  
  return tracker
end

-- Usage Examples:
local awe = require("awe")

-- Default usage
awe.client.tracker.find_by_pid(1234)

-- Testing
local test_awe = awe.create(awe.interfaces.mock_interface)
test_awe.client.tracker.find_by_pid(1234)  -- Uses mock

-- Dry-run mode (ready for future)
local dry_awe = awe.create(awe.interfaces.dry_run_interface)
```

**Success Criteria Achieved**:
- ✅ All 4 client management modules extracted and working
- ✅ Revolutionary architecture with instance-based dependency injection
- ✅ Consistent factory pattern APIs across all client modules
- ✅ Zero duplication between modules
- ✅ All existing functionality preserved (537 tests passing)
- ✅ Clean testing pattern eliminates complex test setup
- ✅ 42 new comprehensive tests added

**Actual Duration**: 8 hours (including architectural revolution)

**Key Architectural Innovation**: Instance-based dependency injection pattern that became the foundation for all future extractions.

---

### Phase 3: Extract Spawning Modules

**Objective**: Separate spawning concerns into focused, testable modules

**Tasks**:

1. **Create awe/spawn/spawner.lua**
   - Extract core spawning logic from `spawn_with_properties`
   - Use `awful.spawn` with proper error handling
   - Remove tag resolution (will use tag_mapper)

2. **Create awe/spawn/configuration.lua**
   - Extract function: `build_spawn_properties`
   - Add spawn configuration validation
   - Handle floating, placement, dimensions, etc.

3. **Create awe/spawn/environment.lua**
   - Extract function: `build_command_with_env`
   - Handle environment variable injection
   - Process JSON decoding quirks

**New Spawning Flow**:
```lua
-- In awe/client_manager.lua (after refactor)
function client_manager.spawn_with_properties(app, tag_spec, config)
  -- 1. Resolve tag using tag_mapper (eliminate duplication!)
  local tag_result = tag_resolver.resolve_string_spec(tag_spec)
  
  -- 2. Build configuration using spawn/configuration
  local properties = spawn_configuration.build_properties(tag_result.tag, config)
  
  -- 3. Handle environment using spawn/environment  
  local command = spawn_environment.build_command(app, config.env_vars)
  
  -- 4. Execute spawn using spawn/spawner
  return spawner.spawn_application(command, properties)
end
```

**Success Criteria**:
- Spawning logic cleanly separated
- Tag resolution delegated to tag_mapper (no duplication)
- Environment handling isolated and testable
- Configuration building reusable across contexts

**Estimated Duration**: 3-4 hours

---

### Phase 4: Extract Error Handling Framework

**Objective**: Create a comprehensive, reusable error handling system

**Tasks**:

1. **Create awe/error/classifier.lua**
   - Extract: `ERROR_TYPES`, `classify_error`
   - Add additional error patterns
   - Provide extensible classification system

2. **Create awe/error/reporter.lua**
   - Extract: `create_error_report`, `create_spawn_summary`
   - Extract: `get_error_suggestions`
   - Add error aggregation and analysis

3. **Create awe/error/formatter.lua**  
   - Extract: `format_error_for_user`
   - Add multiple output formats (CLI, JSON, etc.)
   - Provide consistent error presentation

**Error System Design**:
```lua
-- Consistent error handling across all modules
local error_classifier = require("awe.error.classifier")
local error_reporter = require("awe.error.reporter") 

function some_operation(...)
  -- ... operation logic
  
  if not success then
    local error_type = error_classifier.classify(error_message)
    local error_report = error_reporter.create_report(error_type, context)
    return false, nil, error_report
  end
  
  return true, result, metadata
end
```

**Success Criteria**:
- Consistent error objects across all modules
- Extensible error classification system
- Rich error reporting with actionable suggestions
- Multiple output formats for different contexts

**Estimated Duration**: 2-3 hours

---

### Phase 5: Create Tag Resolution Integration

**Objective**: Eliminate duplicate tag resolution and create clean integration

**Tasks**:

1. **Create awe/tag/resolver.lua**
   - Create wrapper for tag_mapper that handles string inputs
   - Convert CLI string formats to structured formats inline
   - Provide convenient API for AwesomeWM context

2. **Update awe/client_manager.lua**
   - **REMOVE**: `resolve_tag_spec` function entirely (60+ lines)
   - **REPLACE**: All tag resolution with calls to tag_mapper
   - Use awe/tag/resolver for string-to-structured conversion

**String-to-Structured Conversion** (inline in resolver):
```lua
-- awe/tag/resolver.lua
local tag_mapper = require("tag_mapper")
local awesome_interface = require("awe").interfaces.awesome_interface

function resolver.resolve_string_spec(tag_spec, options)
  options = options or {}
  
  -- Convert CLI string format to structured format inline
  local structured_spec, base_tag
  
  if tag_spec == "0" then
    structured_spec = 0  -- relative to current
    base_tag = awesome_interface.get_current_tag()
  elseif tag_spec:match("^[+-]%d+$") then
    structured_spec = tonumber(tag_spec)  -- relative offset
    base_tag = awesome_interface.get_current_tag()  
  elseif tag_spec:match("^%d+$") then
    structured_spec = tag_spec  -- absolute string
    base_tag = awesome_interface.get_current_tag()
  else
    structured_spec = tag_spec  -- named tag
    base_tag = awesome_interface.get_current_tag()
  end
  
  -- Use tag_mapper for actual resolution
  return tag_mapper.resolve_tag(structured_spec, base_tag)
end
```

**Success Criteria**:
- Complete elimination of duplicate tag resolution code
- All tag operations use tag_mapper consistently
- String inputs converted inline without separate adapter modules
- Clean integration between CLI and DSL contexts

**Estimated Duration**: 2-3 hours

---

### Phase 6: Update Dependencies and Integration

**Objective**: Update all existing code to use the new architecture

**Tasks**:

1. **Update tag_mapper/init.lua**
   - Remove interface dependencies (now in awe/)
   - Update imports: `require("awe").interfaces.awesome_interface`
   - Maintain all existing functionality

2. **Update Example Scripts**
   - Modify `examples/spawning/manual_spawn.lua`:
     ```lua
     -- OLD: local acm = require("awesome_client_manager")
     -- NEW: local acm = require("awe.client_manager")
     ```
   - Modify `examples/spawning/manual_client_tracker.lua` similarly
   - Add string-to-structured conversion in scripts as needed
   - Ensure all CLI string inputs continue working

3. **Update Integration Points**
   - Update any other modules that use client_manager
   - Update imports throughout codebase
   - Test all communication paths

**String Format Handling in Scripts**:
```lua
-- In manual_spawn.lua - handle conversion locally
local tag_spec_string = args.tag  -- e.g., "+2"
-- Use existing string-based API - no adapter needed
local pid, snid, msg = acm.spawn_simple(args.app, tag_spec_string)
```

**Success Criteria**:
- All example scripts continue to work with string inputs
- No broken imports or missing dependencies
- Clean integration between all modules
- Maintained backward compatibility

**Estimated Duration**: 3-4 hours

---

### Phase 7: Rockspec and Documentation Updates

**Objective**: Complete the integration and document the new architecture

**Tasks**:

1. **Update diligent-scm-0.rockspec**
   - Add all new awe modules
   - Remove old awesome_client_manager registration
   - Add awe module as main entry point

2. **Update Documentation**
   - Document new module structure in planning/
   - Update developer guide with new import patterns
   - Create examples of using each module independently

3. **Create Module Tests**
   - Add tests for each extracted module
   - Test interface compatibility
   - Validate API consistency

**Success Criteria**:
- All modules properly registered and accessible
- Clear documentation for new architecture
- Test coverage for extracted modules
- Developer guide updated

**Estimated Duration**: 2-3 hours

## Validation and Testing

### Testing Strategy

1. **Unit Tests for Each Module**
   - Test each extracted module independently
   - Use mock interfaces for isolated testing
   - Validate API contracts and error handling

2. **Integration Testing**
   - Run all example scripts to ensure compatibility
   - Test communication between modules
   - Validate end-to-end spawning workflows

3. **Regression Testing**
   - Compare behavior before and after refactoring
   - Ensure no functionality loss
   - Validate performance characteristics

### Success Metrics

- **Code Reduction**: ≥200 lines of duplicate code eliminated
- **Module Count**: 8+ focused modules created from 1 monolithic file
- **API Consistency**: All modules follow standardized patterns
- **Test Coverage**: >80% coverage on extracted modules
- **Example Compatibility**: All existing scripts work without changes
- **Documentation Quality**: Clear module descriptions and usage examples

## Risk Mitigation

### Potential Risks

1. **Breaking Example Scripts**: CLI tools may stop working
   - **Mitigation**: Test all scripts after each phase
   - **Fallback**: Keep old awesome_client_manager until migration complete

2. **API Incompatibilities**: New modules may not integrate cleanly
   - **Mitigation**: Design APIs first, implement second
   - **Validation**: Create integration tests early

3. **Performance Regression**: Module boundaries may add overhead
   - **Mitigation**: Profile before and after refactoring
   - **Optimization**: Inline critical paths if needed

4. **Complex Dependencies**: Circular imports or complex relationships
   - **Mitigation**: Carefully design module boundaries
   - **Architecture**: Use dependency injection and interfaces

### Rollback Plan

If critical issues arise:
1. Keep original `awesome_client_manager.lua` as backup
2. Revert rockspec changes
3. Restore original imports in example scripts
4. Document lessons learned for future attempts

## Timeline and Resource Requirements

### Estimated Total Duration: 15-20 hours

**Phase Breakdown**:
- Phase 1 (Infrastructure): 1-2 hours
- Phase 2 (Client Modules): 4-6 hours  
- Phase 3 (Spawn Modules): 3-4 hours
- Phase 4 (Error Modules): 2-3 hours
- Phase 5 (Tag Integration): 2-3 hours
- Phase 6 (Dependencies): 3-4 hours
- Phase 7 (Documentation): 2-3 hours

### Resource Requirements

- **Development Environment**: Working AwesomeWM setup for testing
- **Testing Tools**: LuaRocks, busted, lua linter
- **Backup Strategy**: Git commits after each phase
- **Validation Environment**: Clean test environment for regression testing

## Expected Benefits

### Immediate Benefits

- **Eliminated Duplication**: 200+ lines of duplicate code removed
- **Better Organization**: Clear separation of concerns
- **Improved Testability**: Smaller, focused modules easier to test
- **Consistent APIs**: Standardized patterns across all modules

### Long-term Benefits

- **Easier Maintenance**: Changes localized to specific modules
- **Better Extensibility**: Easy to add new AwesomeWM functionality
- **Improved Documentation**: Smaller modules easier to document
- **Enhanced Collaboration**: Clear module boundaries reduce conflicts

### Code Quality Metrics

- **Cyclomatic Complexity**: Reduced through smaller functions
- **Coupling**: Loose coupling through clean interfaces
- **Cohesion**: High cohesion within each module
- **Maintainability Index**: Improved through better organization

## Conclusion

This refactoring plan addresses all identified architectural issues while maintaining backward compatibility and improving code quality. The modular approach creates a solid foundation for future AwesomeWM integration work and establishes consistent patterns for the entire project.

The phased approach minimizes risk while ensuring each step can be validated independently. The focus on API consistency and clean interfaces ensures the resulting architecture will be maintainable and extensible.

Success of this refactoring will significantly improve the development experience and code quality for all future work involving AwesomeWM integration.