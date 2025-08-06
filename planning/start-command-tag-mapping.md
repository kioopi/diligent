# Tag Specification Support - Historical Implementation Plan

> **✅ OBJECTIVES ACHIEVED**  
> This plan was superseded by [Tag-Architecture-Restructuring.md](./Tag-Architecture-Restructuring.md) which successfully implemented all tag specification features through a comprehensive architectural restructuring (Phases 1-5 COMPLETE).  
> 
> **🎉 IMPLEMENTATION STATUS**: All advanced tag specifications are now fully supported in the start command:
> - ✅ **Relative tags**: `tag = 1`, `tag = 2` (offset from current tag) 
> - ✅ **Absolute tags**: `tag = "3"`, `tag = "9"` (specific tag numbers)
> - ✅ **Named tags**: `tag = "editor"`, `tag = "browser"` (string names)
> - ✅ **Current tag**: `tag = 0` (stay on current tag)
> - ✅ **Tag overflow handling**: Values >9 overflow to tag 9 with warnings
> - ✅ **Tag creation**: Named tags are created if they don't exist
>
> This document is kept for historical reference and implementation strategy analysis.

---

## ✅ IMPLEMENTATION ACCOMPLISHED (August 2025)

**Tag Specification Support**: ✅ **FULLY IMPLEMENTED** via architectural restructuring

### What Was Actually Built

**Instead of the original plan below, a comprehensive Tag Architecture Restructuring was executed that:**

1. **Fixed Core Bug**: Relative tags now resolve from user's current tag (not hardcoded tag 1)
   - User on tag 2 with `tag = 2` spawns on tag 4 (2+2) ✅
   - Explicit tests verify this behavior ✅

2. **Implemented All Tag Types**:
   - ✅ **Relative**: `tag = 0`, `tag = 1`, `tag = 2` (numeric offsets from current tag)
   - ✅ **Absolute**: `tag = "3"`, `tag = "5"`, `tag = "9"` (string numbers for specific tags)  
   - ✅ **Named**: `tag = "editor"`, `tag = "workspace"` (string names that create/find tags)

3. **Architectural Improvements**:
   - ✅ Single source of truth: tag_mapper handles all tag resolution
   - ✅ Clean data flow: DSL → tag_spec → Handler → tag_mapper → resolved_tag → Spawner
   - ✅ Eliminated duplicate implementations (deleted 4 files)
   - ✅ Comprehensive test coverage (678 tests passing)

4. **User Experience Features**:
   - ✅ Dry-run mode shows tag specifications and resolved tags
   - ✅ Multi-resource projects with mixed tag types
   - ✅ Clear error messages for invalid tag specifications
   - ✅ Consistent CLI output and error reporting

### Key Metrics Achieved
- **678 test successes** (increased from 674)
- **0 failures, 0 errors** in test suite
- **4 files removed** (duplicate implementations eliminated)
- **Single source of truth** architecture established
- **Primary bug resolved** with explicit verification tests

---

## Original Plan (Historical Reference)

## Implementation Strategy

### TDD Approach
Following the established pattern with **Red-Green-Refactor** cycles:
1. Write failing tests for tag specification scenarios
2. Implement minimal code to pass tests
3. Refactor and integrate with existing modules

### Phase 3: Advanced Tag Specifications

#### Step 3.1: Enhanced DSL Tag Processing ⭐ **PRIORITY**
**Goal**: Update `dsl/start_processor.lua` to properly parse and validate tag specifications

**🔴 Red Phase - Write Failing Tests:**
- Test relative tag specs: `tag = 1`, `tag = -1`
- Test absolute tag specs: `tag = "3"`, `tag = "9"`
- Test named tag specs: `tag = "editor"`, `tag = "browser"`
- Test validation errors for invalid specs

**🟢 Green Phase - Implementation:**
- Integrate `dsl.tag_spec.parse()` into start_processor
- Add tag specification validation before resource conversion
- Include parsed tag info in start request structure

**🔧 Refactor Phase:**
- Error handling for invalid tag specifications
- Clear error messages for DSL validation failures

#### Step 3.2: Enhanced Start Handler with Tag Resolution
**Goal**: Update `diligent/handlers/start.lua` to resolve tag specs using tag_mapper

**🔴 Red Phase - Write Failing Tests:**
- Mock tag_mapper interface for different tag types
- Test successful resolution for all tag spec types
- Test tag resolution failures and error handling
- Test tag overflow scenarios (tag > 9 → fallback to tag 9)

**🟢 Green Phase - Implementation:**
- Inject tag_mapper into start handler via awe module
- Add base_tag resolution (current tag from AwesomeWM)
- Replace hardcoded tag handling with tag_mapper.resolve_tag()
- Handle tag creation for named tags

**🔧 Refactor Phase:**
- Optimize tag resolution for multiple resources
- Add caching for repeated tag lookups within single start operation

#### Step 3.3: Integration with awe.spawn.spawner
**Goal**: Ensure spawner properly handles resolved tag objects

**🔴 Red Phase - Write Failing Tests:**
- Test spawner with resolved tag objects (not just strings)
- Test with named tags that need creation
- Test with absolute and relative resolved tags

**🟢 Green Phase - Implementation:**
- Already mostly implemented - spawner uses awe.tag.resolver internally
- Verify compatibility with tag_mapper resolved tags
- Ensure consistent tag object structure

#### Step 3.4: CLI Enhancement for Tag Specifications
**Goal**: Update CLI to show tag resolution details in output and dry-run mode

**🔴 Red Phase - Write Failing Tests:**
- Test dry-run output shows resolved tag info
- Test success output includes actual tag placement
- Test error messages for tag resolution failures

**🟢 Green Phase - Implementation:**
- Enhance dry-run mode to show resolved tags
- Update success reporting to include tag resolution details
- Add specific error handling for tag-related failures

### Integration Architecture

#### Data Flow Enhancement:
```
DSL Project → tag_spec.parse() → start_processor → D-Bus → start_handler → tag_mapper.resolve_tag() → awe.spawn.spawner → AwesomeWM
```

#### Key Integration Points:

1. **DSL Processing**: `dsl/start_processor.lua` validates and parses tag specs
2. **Tag Resolution**: `diligent/handlers/start.lua` resolves tags before spawning
3. **Spawning**: `awe/spawn/spawner.lua` receives resolved tag objects
4. **Error Handling**: Consistent error reporting for tag-related failures

### Testing Strategy

**Unit Tests (Following Established Patterns):**
- `spec/dsl/start_processor_spec.lua` - Enhanced with tag spec tests
- `spec/diligent/handlers/start_handler_spec.lua` - Enhanced with tag resolution tests
- `spec/integration/tag_resolution_integration_spec.lua` - **NEW**

**Test Coverage Goals:**
- All tag specification types (relative, absolute, named)
- Tag overflow scenarios
- Tag creation for named tags
- Error conditions and validation failures
- Integration with existing mock infrastructure

### Example Project Files for Testing

**Create test DSL files demonstrating different tag specs:**
```lua
-- examples/advanced-tags-project.lua
return {
  name = "advanced-tags",
  resources = {
    editor = app({cmd = "gedit", tag = "editor"}),      -- Named tag
    browser = app({cmd = "firefox", tag = "3"}),        -- Absolute tag  
    terminal = app({cmd = "alacritty", tag = 1}),       -- Relative tag +1
    current = app({cmd = "code", tag = 0}),             -- Current tag
  }
}
```

### Success Criteria

**Functional Requirements:**
- [ ] All tag specification types work correctly
- [ ] Tag overflow handling (>9 → tag 9) with warnings
- [ ] Named tag creation when they don't exist
- [ ] Integration with existing tag_mapper module
- [ ] Consistent error handling and reporting

**Performance Requirements:**
- [ ] Tag resolution < 50ms per tag (as specified in requirements)
- [ ] Efficient caching for repeated tag lookups
- [ ] No performance regression from Phase 1

**User Experience:**
- [ ] Clear error messages for invalid tag specifications
- [ ] Dry-run mode shows resolved tag information
- [ ] Success output includes actual tag placement details

## Implementation Order

1. **Step 3.1** - DSL tag processing (foundation)
2. **Step 3.2** - Start handler tag resolution (core functionality)  
3. **Step 3.3** - Spawner integration verification (compatibility)
4. **Step 3.4** - CLI enhancements (user experience)

## Risk Mitigation

**Low Risk**: Existing tag_mapper module is well-tested and proven
**Medium Risk**: Integration complexity between multiple modules
**Mitigation**: Comprehensive integration tests and mock-based unit tests

This plan builds directly on the solid Phase 1 foundation while leveraging existing, proven tag resolution infrastructure.