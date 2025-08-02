# Client Spawning Exploration for Diligent

*Last updated: 2 Aug 2025*

## Introduction

This document tracks our exploration and research into AwesomeWM client spawning, tag management, and client tracking capabilities needed to implement the `start` command in Diligent. The `start` command is one of the most critical features of Diligent and will significantly impact user experience, so we need a thorough understanding of the underlying mechanisms before implementation.

### Purpose and Goals

1. **Understand AwesomeWM spawning APIs** - How to reliably spawn clients with properties
2. **Master tag assignment strategies** - Integrate with our existing tag mapper architecture
3. **Develop client tracking systems** - Identify and manage spawned clients for project state
4. **Design error handling patterns** - Handle spawn failures and edge cases gracefully
5. **Create performance benchmarks** - Ensure the `start` command is fast and reliable

### Manual Testing Tool

For interactive testing and exploration, use the manual spawn tool:

**📋 [`examples/spawning/manual_spawn.lua`](../examples/spawning/manual_spawn.lua)**

This tool provides step-by-step spawning with detailed output for exploring individual app behavior:

```bash
# Basic usage
lua examples/spawning/manual_spawn.lua <app> <tag_spec> [options]

# Examples
lua examples/spawning/manual_spawn.lua firefox 0          # Current tag
lua examples/spawning/manual_spawn.lua gedit +2           # Current tag + 2  
lua examples/spawning/manual_spawn.lua xterm "editor"     # Named tag "editor"
lua examples/spawning/manual_spawn.lua nemo 3 --floating  # Tag 3, floating
lua examples/spawning/manual_spawn.lua xcalc 0 --floating --placement=top_left
```

**Features:**
- ✅ Interactive tag resolution with detailed feedback
- ✅ Support for all tag specifications (current, relative, absolute, named)
- ✅ Property application (floating, placement, dimensions)
- ✅ Step-by-step execution with context information
- ✅ Error handling and debugging output
- ✅ Integration with Diligent's tag mapper concepts

Use this tool to test individual applications before implementing batch spawning logic.

---

### Manual Client Tracking Tool

For testing and analyzing client tracking capabilities discovered in Section 3:

**📋 [`examples/spawning/manual_client_tracker.lua`](../examples/spawning/manual_client_tracker.lua)**

This tool provides comprehensive client tracking analysis using all three tracking methods:

```bash
# Basic lookups
lua manual_client_tracker.lua --pid 12345
lua manual_client_tracker.lua --env DILIGENT_PROJECT=my-project  
lua manual_client_tracker.lua --property diligent_role=terminal
lua manual_client_tracker.lua --client "Firefox"

# Comprehensive analysis
lua manual_client_tracker.lua --list-all --verbose
lua manual_client_tracker.lua --validate

# Set tracking info
lua manual_client_tracker.lua --pid 12345 --set-property diligent_project=new-project
```

**Features:**
- ✅ **Multiple lookup methods**: PID, environment variables, client properties, name/class
- ✅ **Comprehensive information display**: Client info, AwesomeWM state, tracking data
- ✅ **Tracking integrity validation**: Detects inconsistencies across methods
- ✅ **Property management**: Set/update client properties
- ✅ **Professional CLI interface**: Uses lua_cliargs with auto-generated help
- ✅ **Detailed diagnostics**: Clear error messages and recommendations

**Example Output:**
```
=== CLIENT INFORMATION ===
Name: Firefox
Class: firefox
PID: 12345

=== ENVIRONMENT VARIABLES ===
  DILIGENT_PROJECT=web-development
  DILIGENT_ROLE=browser

=== CLIENT PROPERTIES ===
  diligent_project=web-development
  diligent_managed=true

✅ TRACKING INTEGRITY: Consistent across all methods
```

This tool complements `manual_spawn.lua` perfectly - spawn clients with one tool, track and analyze them with the other!

---

### Making Diligent Modules Available in AwesomeWM

During our exploration, we discovered how to make Diligent modules available in the AwesomeWM context via D-Bus communication.

**📝 Process: Adding Modules to Rockspec**

To make a Diligent module available in AwesomeWM context:

1. **Add module to `diligent-scm-0.rockspec`:**
   ```lua
   build = {
     type = "builtin",
     modules = {
       -- existing modules...
       ["module_name"] = "lua/path/to/module.lua"
     }
   }
   ```

2. **Reinstall via LuaRocks:**
   ```bash
   make install  # (requires sudo for system luarocks path)
   ```

3. **Test availability in AwesomeWM:**
   ```lua
   -- Via dbus_communication.lua
   local success, module = pcall(require, "module_name")
   ```

**🔍 Key Findings from Tag Mapper Integration:**

- ✅ **Main module registration is sufficient** - Only need to register the main `init.lua` file
- ✅ **Sub-modules load automatically** - Internal `require()` calls in init.lua work seamlessly  
- ✅ **No need for individual sub-module registration** - Saves rockspec complexity
- ✅ **Full module architecture available** - Complete functionality accessible in AwesomeWM
- ⚠️ **Screen-dependent functions may fail** - Some AwesomeWM interfaces need live screen context
- ✅ **Dry-run interfaces work perfectly** - Planning functions don't need live AwesomeWM state

**Example: Tag Mapper Integration**
```lua
-- In diligent-scm-0.rockspec, we only needed:
["tag_mapper"] = "lua/tag_mapper/init.lua"

-- This automatically made available:
-- tag_mapper.core, tag_mapper.integration, tag_mapper.interfaces.*, etc.
```

**Performance Impact:**
- Module loading overhead is minimal
- Full Diligent architecture available for complex operations
- Both simplified and full approaches now viable for implementation

This discovery significantly expands our implementation options for the `start` command by providing access to the complete Diligent module ecosystem within AwesomeWM.

---

### Project Resources

This exploration builds on existing Diligent infrastructure:

- **Communication Layer**: [`lua/dbus_communication.lua`](../lua/dbus_communication.lua) - D-Bus communication with AwesomeWM
- **Tag Mapper**: [`lua/tag_mapper/`](../lua/tag_mapper/) - Modular tag resolution and assignment system
- **AwesomeWM Documentation**: [`devdocs/awesome/`](../devdocs/awesome/) - Curated AwesomeWM API documentation
  - [`spawn.lua`](../devdocs/awesome/spawn.lua) - Complete spawning API reference
  - [`remote.lua`](../devdocs/awesome/remote.lua) - D-Bus remote execution interface
  - [`08-client-layout-system.md`](../devdocs/awesome/08-client-layout-system.md) - Client and layout management
- **Existing Examples**: [`examples/`](../examples/) - D-Bus communication test scripts
  - [`dbus_diligent_test.lua`](../examples/dbus_diligent_test.lua) - Full ping/pong communication
  - [`test_dbus_module.lua`](../examples/test_dbus_module.lua) - Module-based communication tests
  - [`test-project.lua`](../examples/test-project.lua) - Sample DSL structure

---

## 1. Core Spawning Research

### Open Questions

- How reliable is `awful.spawn()` with startup notifications?
- What's the best way to apply client properties during spawn?
- How do we handle spawn failures and provide meaningful error messages?
- What are the performance characteristics of different spawning methods?

### Initial Assumptions

Based on [`devdocs/awesome/spawn.lua`](../devdocs/awesome/spawn.lua) research:

1. **Startup Notifications Work**: `awful.spawn(cmd, sn_rules)` can apply properties reliably
2. **Property Application**: Properties can be set via startup notification ID matching
3. **Error Detection**: Failed spawns return error strings instead of PIDs
4. **Async Operation**: Spawning is non-blocking, client creation happens asynchronously

### Validation Experiments

**Experiment 1.1**: Basic Spawning with Properties
```lua
-- Test: Spawn simple application with tag assignment
local pid, snid = awful.spawn("gedit", {
  tag = target_tag,
  floating = false
})
-- Verify: pid is number, snid is string, client appears on correct tag
```

**Experiment 1.2**: Startup Notification Reliability
```lua
-- Test: Multiple rapid spawns with different properties
-- Verify: Each client gets correct properties, no mixing
```

**Experiment 1.3**: Error Handling
```lua
-- Test: Spawn non-existent command
-- Verify: Error message returned, no client created
```

### Results Documentation

**✅ EXPERIMENT 1.1 COMPLETED** - [`examples/spawning/01_basic_spawning.lua`](../examples/spawning/01_basic_spawning.lua)

**Key Findings:**

1. **Return Value Patterns**:
   - ✅ Successful spawns return `(number_pid, string_snid)`
   - ✅ Failed spawns return `(error_string, nil)`
   - ✅ Error detection is reliable via `type(pid) == "string"`

2. **Property Application**:
   - ✅ Tag assignment works: `awful.spawn(cmd, {tag = target_tag})`
   - ✅ Floating property works: `{floating = true, placement = awful.placement.top_left}`
   - ✅ Properties applied via startup notification system

3. **Startup Notifications**:
   - ✅ SNID format: `awesome/command/session-sequence-display_TIME`
   - ✅ SNID buffer tracks pending property applications
   - ✅ Multiple concurrent spawns each get unique SNIDs

4. **Error Handling**:
   - ✅ Invalid commands immediately return descriptive error strings
   - ✅ No zombie processes or hanging operations observed
   - ✅ SNID is `nil` for failed spawns

**Confirmed Assumptions:**
- ✅ Startup notifications work reliably for property application
- ✅ Error detection is immediate and clear
- ✅ Async operation doesn't block AwesomeWM

**Updated Understanding:**
- Error strings are detailed: `"Failed to execute child process \"gedit\" (No such file or directory)"`
- SNID buffer persists entries across multiple spawns
- Property application happens automatically when client appears

---

## 2. Tag Management Integration

### Open Questions

- How do we integrate `awful.spawn()` with our existing tag mapper?
- What's the best timing for tag assignment (during spawn vs after client creation)?
- How do we handle tag creation when spawning to non-existent named tags?
- Can we use dry-run capabilities for spawn planning?

### Initial Assumptions

Based on [`lua/tag_mapper/`](../lua/tag_mapper/) architecture:

1. **Tag Resolution First**: Use tag mapper to resolve tag specifications before spawning
2. **Interface Integration**: `awesome_interface.lua` provides necessary tag operations
3. **Error Propagation**: Tag resolution errors should prevent spawning
4. **Dry-Run Support**: We can preview tag operations before actual spawning

### Validation Experiments

**Experiment 2.1**: Tag Mapper Integration
```lua
-- Test: Resolve tag spec (0, "editor", "+2") before spawn
-- Verify: Tag exists or is created, spawn uses resolved tag
```

**Experiment 2.2**: Named Tag Creation
```lua
-- Test: Spawn to non-existent named tag
-- Verify: Tag is created automatically, client assigned correctly
```

**Experiment 2.3**: Tag Assignment Timing
```lua
-- Test: Compare property-based vs post-spawn tag assignment
-- Verify: Which method is more reliable?
```

### Results Documentation

**✅ EXPERIMENT 2.1 COMPLETED** - [`examples/spawning/02_tag_mapper_integration.lua`](../examples/spawning/02_tag_mapper_integration.lua)

**✅ EXPERIMENT 2.2 COMPLETED** - [`examples/spawning/02_tag_mapper_module_test.lua`](../examples/spawning/02_tag_mapper_module_test.lua)

**Module Availability Results:**
- ✅ Added `["tag_mapper"] = "lua/tag_mapper/init.lua"` to `diligent-scm-0.rockspec`
- ✅ `require("tag_mapper")` works successfully in AwesomeWM context
- ✅ All tag_mapper functions available: `get_current_tag()`, `resolve_tag()`, `create_project_tag()`, etc.
- ⚠️ Some functions require AwesomeWM to be in normal state (screens available)
- ✅ Core functionality and dry-run interfaces work without live AwesomeWM state

**Key Findings:**

1. **Tag Mapper Module Status**:
   - ✅ **UPDATED**: Diligent tag mapper modules ARE NOW available in AwesomeWM context  
   - ✅ Adding `["tag_mapper"] = "lua/tag_mapper/init.lua"` to rockspec was sufficient
   - ✅ All sub-modules load automatically via internal requires
   - ✅ Successfully created simplified tag mapper functions using basic AwesomeWM APIs
   - ✅ Functionality equivalent to tag mapper core features

2. **Tag Resolution Performance**:
   - ✅ **Excellent Performance**: 10 resolutions in 0.002s (0.0002s each)
   - ✅ **Spawn Integration**: 3 spawns in 0.004s (0.001s each)
   - ✅ Sub-millisecond resolution makes it suitable for real-time use

3. **Tag Specification Support**:
   - ✅ Current tag (0): Works perfectly
   - ✅ Relative tags (+2, -1): Correct offset calculation
   - ✅ Absolute tags ("3"): Direct index resolution
   - ✅ Named tags ("test_tag"): Auto-creation with `awful.tag.add()`
   - ✅ Error handling: Clear messages for invalid specs

4. **Dry-Run Capabilities**:
   - ✅ `use_existing` action for existing tags
   - ✅ `create_new` action for missing named tags
   - ✅ Accurate index and screen information
   - ✅ Error reporting for impossible requests

5. **Integration Patterns**:
   - ✅ Two-step process: resolve tag → spawn with tag
   - ✅ Automatic tag creation for named tags
   - ✅ Seamless integration with `awful.spawn()`
   - ✅ Proper error propagation throughout the chain

**Updated Understanding:**
- ✅ **BREAKTHROUGH**: Full Diligent tag mapper modules ARE available in AwesomeWM after rockspec update
- ✅ Only the main module needs to be registered - sub-modules load automatically
- ✅ Both simplified and full approaches are now viable options
- ✅ Performance is excellent for production use (sub-millisecond operations)  
- ✅ Named tag creation works seamlessly with the spawn workflow

**Implementation Strategy Options:**
1. **Full Tag Mapper** (NEW): Use complete tag mapper architecture with dry-run interface
2. **Simplified Approach**: Use basic AwesomeWM APIs for minimal overhead
3. **Hybrid**: CLI uses full tag mapper, AwesomeWM uses simplified for execution

**Recommended**: Start with full tag mapper since it's now available and provides comprehensive functionality.

---

## 3. Client Tracking & Properties

### Open Questions

- How do we reliably identify spawned clients for project tracking?
- What client properties are available for matching (PID, class, instance)?
- How do we handle clients that don't appear immediately?
- What's the best way to associate clients with projects?

### Initial Assumptions

Based on AwesomeWM documentation and existing handler patterns:

1. **PID Tracking**: Client PID can be matched to spawn PID for identification
2. **Custom Properties**: We can set custom properties like `c.diligent_project`
3. **Environment Variables**: `DILIGENT_PROJECT` can be injected and read from `/proc/PID/environ`
4. **Signal Hooks**: `client::manage` signal provides client creation notifications

### Validation Experiments

**Experiment 3.1**: PID-based Client Matching
```lua
-- Test: Spawn client, track PID, match to managed client
-- Verify: PID matching is reliable across different applications
```

**Experiment 3.2**: Environment Variable Injection
```lua
-- Test: Set DILIGENT_PROJECT before spawn, read from client process
-- Verify: Environment variable correctly passed and readable
```

**Experiment 3.3**: Client Property Management
```lua
-- Test: Set custom properties on managed clients
-- Verify: Properties persist and are accessible
```

### Results Documentation

**✅ EXPERIMENT 3.1 COMPLETED** - [`examples/spawning/03_pid_client_matching.lua`](../examples/spawning/03_pid_client_matching.lua)

**✅ EXPERIMENT 3.2 COMPLETED** - [`examples/spawning/03_environment_variable_injection.lua`](../examples/spawning/03_environment_variable_injection.lua)

**✅ EXPERIMENT 3.3 COMPLETED** - [`examples/spawning/03_client_property_management.lua`](../examples/spawning/03_client_property_management.lua)

**Key Findings:**

1. **PID-based Client Matching**:
   - ✅ **100% success rate** for tested applications (xterm, nemo)
   - ✅ **Fast matching**: Clients appear and match within 1-2 seconds
   - ✅ **Reliable identification**: PID from `awful.spawn()` matches client PID
   - ✅ **Client tracking system**: Can monitor multiple spawns simultaneously
   - ⚠️ **Application dependency**: Some apps (like complex GUI apps) may behave differently

2. **Environment Variable Injection**:
   - ✅ **Perfect reliability**: `env` command injection works 100% of the time
   - ✅ **Complex data support**: Multiple variables with special characters work
   - ✅ **Persistent access**: Variables readable via `/proc/PID/environ`
   - ✅ **Rich metadata**: Can store project name, workspace, timestamps, etc.
   - ✅ **Cross-process visibility**: Environment variables accessible to child processes

3. **Client Property Management**:
   - ✅ **Custom properties work**: Can set `c.diligent_project`, `c.diligent_role`, etc.
   - ✅ **Property persistence**: Properties survive AwesomeWM operations
   - ✅ **Efficient discovery**: Can find clients by properties quickly
   - ✅ **Complex metadata**: Support for strings, booleans, numbers
   - ✅ **100% success rate**: All property assignments successful

**Updated Understanding:**
- ✅ **Triple tracking strategy**: PID matching + environment variables + client properties
- ✅ **Robust identification**: Multiple fallback methods for client association
- ✅ **Rich project metadata**: Can store comprehensive project state on clients
- ✅ **Real-time tracking**: Immediate client identification after spawn
- ✅ **Production ready**: All methods reliable enough for production use

**Implementation Strategy:**
1. **Primary**: Use PID matching for immediate client identification
2. **Secondary**: Inject environment variables for process-level association
3. **Tertiary**: Set client properties for AwesomeWM-level metadata and discovery
4. **Comprehensive**: Combine all three methods for maximum reliability

---

## 4. Error Handling & Edge Cases

### Open Questions

- What can go wrong during spawning and how do we detect it?
- How do we handle timeouts for clients that never appear?
- What should happen when spawning partially succeeds (some clients spawn, others fail)?
- How do we provide useful feedback to users about spawn failures?

### Initial Assumptions

1. **Timeout Handling**: We need timeouts for spawn operations
2. **Partial Failure Recovery**: System should handle mixed success/failure scenarios
3. **User Feedback**: Clear error messages help with debugging
4. **Graceful Degradation**: Partial project startup is better than complete failure

### Validation Experiments

**Experiment 4.1**: Spawn Failure Detection
```lua
-- Test: Spawn invalid commands, missing binaries
-- Verify: Errors detected immediately, no zombie processes
```

**Experiment 4.2**: Client Appearance Timeouts
```lua
-- Test: Long-starting applications, GUI applications with splash screens
-- Verify: Reasonable timeout handling, no false failures
```

**Experiment 4.3**: Partial Spawn Scenarios
```lua
-- Test: Project with mix of valid/invalid commands
-- Verify: Valid commands succeed, invalid ones fail gracefully
```

### Results Documentation

*[To be filled during exploration]*

---

## 5. Integration Testing

### Open Questions

- What's the complete end-to-end workflow for spawning a project?
- How do we test the full integration without disrupting development?
- What are the performance characteristics under various loads?
- How do we validate the complete system works as expected?

### Initial Assumptions

1. **End-to-End Flow**: DSL → Tag Resolution → Spawn → Track → State Management
2. **Testing Strategy**: Use isolated test projects to avoid disruption
3. **Performance Expectations**: Sub-second startup for typical projects
4. **Validation Methods**: Automated verification of client placement and properties

### Validation Experiments

**Experiment 5.1**: Complete Project Startup
```lua
-- Test: Full DSL parsing → multiple client spawn → tag assignment
-- Verify: All clients appear correctly placed with proper properties
```

**Experiment 5.2**: Performance Benchmarking
```lua
-- Test: Projects with varying numbers of resources (1, 5, 10+ clients)
-- Verify: Startup time scales reasonably, no blocking issues
```

**Experiment 5.3**: State Management Integration
```lua
-- Test: Spawn tracking integrates with project state management
-- Verify: Client lifecycle properly tracked in project state
```

### Results Documentation

*[To be filled during exploration]*

---

## Next Steps

1. **Create Exploration Examples**: Build working examples in [`examples/spawning/`](../examples/spawning/) directory
2. **Systematic Testing**: Execute experiments for each topic area
3. **Document Findings**: Record results and insights in this document
4. **Refine Assumptions**: Update understanding based on experimental results
5. **Implementation Planning**: Use validated knowledge to design robust `start` command

## Implementation Notes

- Follow TDD principles: write tests for spawn behavior before implementation
- Use existing modular architecture patterns from tag mapper
- Integrate with current D-Bus communication layer
- Maintain compatibility with existing DSL structure
- Ensure error handling follows project standards

---

*This document will be updated as we conduct experiments and gather real-world data about AwesomeWM spawning behavior.*