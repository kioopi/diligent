# Feature Requirements Analysis: `start` Command

## Requirements Overview

### Functional Requirements

**Core Functionality:**
1. Parse DSL project files to extract resource definitions
2. Resolve tag specifications for each resource (relative, absolute, named)
3. Execute pre-start hooks if defined
4. Spawn applications through AwesomeWM using the awe module
5. Track spawned clients and maintain in-memory state
6. Provide comprehensive error reporting and recovery
7. Support dry-run mode for validation before execution

**Input Requirements:**
- Accept project name (searches in ~/.config/diligent/projects/)
- Accept file path with --file option
- Support --dry-run flag for preview mode
- Support --layout option for multi-layout projects (future)

**Output Requirements:**
- Real-time progress reporting during startup
- Clear success/failure indicators
- Detailed error messages with actionable suggestions
- Summary of spawned resources and their locations

### Performance Goals

**Startup Speed:**
- Total project startup: < 3 seconds for typical projects (≤5 resources)
- Individual resource spawn: < 500ms per resource
- DSL parsing and validation: < 100ms
- Tag resolution: < 50ms per tag

**Responsiveness:**
- Parallel spawning where possible to minimize total time
- Non-blocking progress updates to CLI
- Quick failure detection (< 100ms for invalid commands)
- Immediate feedback for validation errors

**Resource Efficiency:**
- Minimal memory footprint for state tracking
- Efficient cleanup of failed spawn attempts
- No zombie processes from failed spawns

## System Flow Analysis

### Complete Flow: DSL → Running Client

```
1. CLI Input Processing
   └─ workon start [project|--file path] [--dry-run] [--layout name]

2. DSL Loading & Validation
   ├─ dsl.parser.load_file() → Load and compile DSL
   ├─ dsl.validator.validate() → Schema validation with lua-LIVR
   └─ dsl.tag_spec.parse() → Parse tag specifications

3. Pre-execution Phase
   ├─ Execute hooks.start if defined
   ├─ Validate all commands exist and are executable
   └─ Dry-run mode: Preview all operations without execution

4. Resource Processing (Sequential/Parallel)
   For each resource in DSL:
   ├─ DSL Helper Processing
   │  ├─ dsl.helpers.app.process() → Convert DSL to spawn config
   │  └─ Apply reuse logic if enabled
   ├─ Tag Resolution
   │  ├─ tag_mapper.resolve_tag() → Resolve tag specification
   │  └─ Create/find target tag in AwesomeWM
   ├─ Application Spawning
   │  ├─ awe.spawn.environment.build_command_with_env()
   │  ├─ awe.spawn.configuration.build_spawn_properties()
   │  ├─ awe.spawn.spawner.spawn_with_properties()
   │  └─ Interface: awesome.spawn() via D-Bus
   └─ Client Tracking
      ├─ awe.client.tracker.wait_for_client()
      └─ State management: Track PID, client, tag mapping

5. Post-execution
   ├─ Update in-memory project state
   ├─ Report final status and any warnings
   └─ Return success/failure with detailed results
```

## System Components Involved

### 1. CLI Layer (`cli/commands/start.lua` - **NEW**)
**Responsibilities:**
- Parse command line arguments
- Load and validate DSL project file
- Coordinate overall start process
- Provide user feedback and progress reporting
- Handle errors and exit codes

**Integration Points:**
- `dsl.load_and_validate()` for project loading
- `diligent.dispatch()` for AwesomeWM communication
- Error reporting and user feedback systems

### 2. DSL System (`lua/dsl/`)
**Responsibilities:**
- Load and parse project DSL files
- Validate against schema using lua-LIVR
- Convert DSL resources to spawn configurations
- Handle helper functions (app, term, browser, obsidian)

**Key Modules:**
- `dsl.parser` - File loading and compilation
- `dsl.validator` - Schema validation
- `dsl.helpers.app` - Process app{} definitions
- `dsl.tag_spec` - Tag specification parsing

### 3. AwesomeWM Handler (`lua/diligent.lua` + **NEW** `diligent::start` handler)
**Responsibilities:**
- Receive start command via D-Bus
- Coordinate resource spawning process
- Return structured responses to CLI
- Handle errors and timeouts

**Integration:**
- Dispatch to appropriate handler modules
- Use awe module for actual spawning operations
- Manage communication protocol with CLI

### 4. awe Module Architecture (`lua/awe/`)
**Current Capabilities:**
- `awe.spawn.spawner` - Core spawning with properties
- `awe.spawn.configuration` - Build spawn properties
- `awe.spawn.environment` - Command and env variable handling
- `awe.client.tracker` - Wait for and track spawned clients
- `awe.tag.resolver` - Tag specification resolution
- `awe.error` - Comprehensive error handling and reporting

**Integration:**
- Factory pattern: `awe.create(interface)` for testing
- Interface abstraction for dry-run and testing
- Clean APIs with consistent return patterns

### 5. Tag Mapper (`lua/tag_mapper/`)
**Responsibilities:**
- Resolve tag specifications (relative, absolute, named)
- Handle tag overflow (fallback to tag 9)
- Integration with AwesomeWM tag system
- Dry-run capabilities for preview

### 6. Communication Layer (`lua/dbus_communication.lua`)
**Responsibilities:**
- Direct D-Bus communication with AwesomeWM
- Typed request/response handling
- Timeout and error management
- Replace shell-based awesome-client

### 7. State Management (**NEW** - In-memory)
**Requirements:**
- Track running projects and their resources
- Map PIDs to project resources
- Enable resume/stop operations
- Volatile storage (lost on AwesomeWM restart)

## Component Interactions

### Data Flow Patterns

1. **CLI → DSL System:**
   ```
   Project name/path → DSL file → Parsed structure → Validated project
   ```

2. **DSL → awe Module:**
   ```
   Resource definitions → Spawn configurations → awe operations
   ```

3. **awe → AwesomeWM:**
   ```
   Spawn configs → AwesomeWM API calls → Client creation → Tracking
   ```

4. **Error Handling:**
   ```
   Any failure → Error classification → User-friendly message → Suggestions
   ```

### Key Integration Points

1. **DSL Helper → awe Spawner:**
   - Convert `app{cmd="...", tag=1, dir="..."}` to spawn configuration
   - Handle reuse logic and validation

2. **Tag Resolution → Spawning:**
   - Resolve tag specs before spawning
   - Handle tag creation and overflow scenarios

3. **State Tracking:**
   - Link spawned PIDs to project resources
   - Enable project lifecycle management

## Performance Considerations

### Bottlenecks & Optimizations

1. **Sequential vs Parallel Spawning:**
   - Current: Sequential processing
   - Optimization: Parallel spawning where tag conflicts don't exist
   - Impact: 3-5x faster startup for multi-resource projects

2. **Tag Resolution Caching:**
   - Cache resolved tags within single start operation
   - Avoid repeated AwesomeWM queries for same tags

3. **Client Wait Optimization:**
   - Asynchronous client waiting
   - Timeout handling to prevent hanging

4. **Error Recovery:**
   - Fast failure detection for invalid commands
   - Graceful degradation when some resources fail

## Success Criteria

### Functional Success
- [ ] Load and validate DSL projects correctly
- [ ] Spawn all resources with proper tag placement
- [ ] Execute hooks in correct order
- [ ] Track all spawned clients in memory
- [ ] Provide clear error messages for all failure modes
- [ ] Support dry-run mode for safe preview

### Performance Success  
- [ ] Total startup < 3s for typical projects
- [ ] Individual spawn < 500ms
- [ ] No zombie processes from failures
- [ ] Graceful handling of resource exhaustion

### User Experience Success
- [ ] Clear progress reporting during startup
- [ ] Actionable error messages with suggestions
- [ ] Consistent behavior across different project types
- [ ] Integration with existing CLI patterns and style

This analysis provides the foundation for implementing the `start` command as the crucial centerpiece of Diligent's functionality, connecting all existing architectural components into a cohesive user experience.