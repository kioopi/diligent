# Tag Mapper Module

Technical documentation for the Diligent tag mapper module - a clean, modular system for resolving and managing AwesomeWM tags.

## Architecture Overview

The tag mapper follows a layered architecture that separates concerns and enables easy testing and extension:

```
┌─────────────────────────────────────────────────────────────┐
│                        init.lua                             │
│                   (Public API Layer)                        │
├─────────────────────────────────────────────────────────────┤
│                    integration.lua                          │
│                 (Coordination Layer)                        │
├─────────────────────────────────────────────────────────────┤
│                       core.lua                              │
│                  (Pure Logic Layer)                         │
├─────────────────────────────────────────────────────────────┤
│              interfaces/ Directory                          │
│    awesome_interface.lua  │  dry_run_interface.lua          │
│     (Production)          │    (Simulation)                 │
└─────────────────────────────────────────────────────────────┘
```

## Module Components

### 1. Core Logic (`core.lua`)

Pure functions with zero external dependencies that handle tag resolution logic.

#### Key Functions

**`resolve_tag_specification(tag_spec, base_tag, screen_context)`**
- Resolves tag specifications to structured results
- Handles three tag types:
  - **Relative numeric**: `+1`, `-2` (offset from base_tag)
  - **Absolute string**: `"5"`, `"15"` (specific tag index)
  - **Named tags**: `"editor"`, `"project"` (string names)
- Returns structured data with type, resolved index, overflow info, creation needs
- Pure function - no side effects, only data transformation

**`plan_tag_operations(resources, screen_context, base_tag)`**
- Plans tag operations for multiple resources
- Optimizes duplicate tag creations
- Generates overflow warnings
- Returns structured operation plan

#### Data Structures

```lua
-- Tag Resolution Result
{
  type = "relative" | "absolute" | "named",
  resolved_index = number,        -- For numeric tags
  name = string,                 -- For named tags  
  overflow = boolean,            -- Tag index > 9
  original_index = number,       -- Before overflow handling
  needs_creation = boolean       -- Named tag doesn't exist
}

-- Operation Plan
{
  assignments = {                -- Resource -> tag mappings
    { resource_id, type, resolved_index, name, ... }
  },
  creations = {                  -- Tags to create
    { name, screen, operation = "create" }
  },
  warnings = {                   -- Overflow notifications
    { type = "overflow", resource_id, original_index, final_index }
  },
  metadata = {                   -- Plan metadata
    base_tag, total_operations
  }
}
```

### 2. Interface Layer (`interfaces/`)

Abstraction layer for external API interactions with swappable implementations.

#### AwesomeWM Interface (`awesome_interface.lua`)

Production interface that executes real AwesomeWM operations.

**Key Functions:**
- `get_screen_context(screen)` - Collects screen information from AwesomeWM
- `find_tag_by_name(name, screen)` - Searches existing tags
- `create_named_tag(name, screen)` - Creates new tags via `awful.tag.add`

**Features:**
- Centralizes all AwesomeWM API calls (eliminates 7x duplicate `awful.screen.focused()`)
- Proper error handling and fallbacks
- Safe validation of screen objects

#### Dry-Run Interface (`dry_run_interface.lua`)

Simulation interface for testing and preview functionality.

**Key Functions:**
- Same API as awesome_interface but simulates operations
- `get_execution_log()` - Returns detailed operation log
- `clear_execution_log()` - Resets simulation state

**Features:**
- No actual AwesomeWM changes
- Detailed operation logging
- Tag creation simulation with mock objects
- Perfect for CLI `--dry-run` functionality

### 3. Integration Layer (`integration.lua`)

Coordinates between core logic and interface layers.

**`execute_tag_plan(plan, interface)`**
- Executes operation plans via provided interface
- Handles tag creation and assignment operations
- Returns structured execution results with timing

**`resolve_tags_for_project(resources, base_tag, interface)`**
- High-level coordinator for complete workflow
- Sequence: screen context → planning → execution → results
- Supports both awesome and dry-run interfaces

### 4. Public API (`init.lua`)

Maintains backward compatibility while providing enhanced functionality.

#### Legacy Functions (Backward Compatible)
- `get_current_tag()` - Returns current tag index
- `resolve_tag(tag_spec, base_tag)` - Resolves single tag
- `create_project_tag(project_name)` - Creates/finds project tag

#### New High-Level Functions
- `resolve_tags_for_project(resources, base_tag, interface)` - Batch resolution
- `execute_tag_plan(plan, interface)` - Plan execution

## Usage Examples

### Basic Tag Resolution

```lua
local tag_mapper = require("tag_mapper")

-- Legacy API (backward compatible)
local current_tag = tag_mapper.get_current_tag()
local success, tag = tag_mapper.resolve_tag("+1", current_tag)
local success, project_tag = tag_mapper.create_project_tag("editor")
```

### Advanced Batch Operations

```lua
local tag_mapper = require("tag_mapper")
local dry_run_interface = require("tag_mapper.interfaces.dry_run_interface")

-- Define resources with tag specifications
local resources = {
  { id = "vim", tag = "+1" },      -- Relative: current + 1
  { id = "terminal", tag = "5" },   -- Absolute: tag 5
  { id = "browser", tag = "editor" } -- Named: find/create "editor"
}

-- Preview operations (dry-run)
local results = tag_mapper.resolve_tags_for_project(
  resources, 
  current_tag, 
  dry_run_interface
)

-- Check what would happen
local log = dry_run_interface.get_execution_log()
for _, operation in ipairs(log) do
  print(operation.operation .. ": " .. (operation.tag_name or ""))
end

-- Execute for real
local real_results = tag_mapper.resolve_tags_for_project(
  resources,
  current_tag
  -- awesome_interface used by default
)
```

### Core Logic Testing

```lua
local tag_mapper_core = require("tag_mapper.core")

-- Mock screen context for testing
local screen_context = {
  current_tag_index = 3,
  available_tags = {
    { name = "1", index = 1 },
    { name = "2", index = 2 },
    { name = "existing_tag", index = 8 }
  },
  tag_count = 3
}

-- Test tag resolution
local result = tag_mapper_core.resolve_tag_specification(
  "+2",  -- relative offset
  3,     -- base tag
  screen_context
)

-- result.type == "relative"
-- result.resolved_index == 5
-- result.overflow == false
```

## Testing Strategy

### Pure Logic Testing
Core functions can be tested in complete isolation with mock data structures:

```lua
describe("tag_mapper_core", function()
  describe("resolve_tag_specification", function()
    it("handles relative offsets", function()
      local result = tag_mapper_core.resolve_tag_specification(
        2, 3, mock_screen_context
      )
      assert.equals("relative", result.type)
      assert.equals(5, result.resolved_index)
    end)
    
    it("handles overflow conditions", function()
      local result = tag_mapper_core.resolve_tag_specification(
        "15", 0, mock_screen_context
      )
      assert.equals(9, result.resolved_index)
      assert.is_true(result.overflow)
      assert.equals(15, result.original_index)
    end)
  end)
end)
```

### Interface Testing
Simple interface mocking instead of complex global API mocking:

```lua
local mock_interface = {
  get_screen_context = function() return test_screen_context end,
  create_named_tag = function(name) return { name = name, index = 10 } end,
  find_tag_by_name = function(name) return nil end
}

local results = integration.resolve_tags_for_project(
  test_resources, 3, mock_interface
)
```

## Extension Points

### Adding New Interface Types

Create new interface implementing the standard contract:

```lua
local custom_interface = {}

function custom_interface.get_screen_context(screen)
  -- Implementation
end

function custom_interface.find_tag_by_name(name, screen)
  -- Implementation
end

function custom_interface.create_named_tag(name, screen)
  -- Implementation  
end

return custom_interface
```

### Adding New Tag Types

Extend `resolve_tag_specification()` in core.lua:

```lua
-- Add new condition in resolve_tag_specification
if is_special_syntax(tag_spec) then
  return {
    type = "special",
    -- custom resolution logic
  }
end
```

### Multi-Screen Support

The architecture is ready for multi-screen extension:

```lua
function tag_mapper.resolve_tags_multi_screen(project_data, screen_assignments)
  -- Use interface abstraction for multiple screens
  -- Plan operations per screen
  -- Execute in parallel
end
```

## Performance Characteristics

- **API Call Reduction**: 85% reduction (1x vs 7x `awful.screen.focused()`)
- **Complexity**: O(n) for n resources
- **Memory**: Minimal overhead with structured data
- **Caching**: Screen context cached per operation

## Error Handling

### Core Layer
- Input validation with descriptive error messages
- Graceful handling of edge cases (negative offsets, overflow)
- Structured error returns

### Interface Layer
- Safe fallbacks for missing AwesomeWM APIs
- Screen validation and default handling
- Operation failure recovery

### Integration Layer
- Comprehensive error tracking in execution results
- Partial failure handling (continue on non-critical errors)
- Detailed failure reporting

## Dependencies

- **Core**: Zero external dependencies (pure Lua)
- **Awesome Interface**: AwesomeWM APIs (`awful.screen`, `awful.tag`)
- **Dry-Run Interface**: Zero external dependencies
- **Integration**: Only depends on core and interface modules

## File Organization

```
lua/tag_mapper/
├── init.lua                    # Main module with public API
├── core.lua                    # Pure logic functions
├── integration.lua             # Coordination layer
└── interfaces/
    ├── awesome_interface.lua   # Production AwesomeWM interface
    └── dry_run_interface.lua   # Simulation interface
```

This architecture enables:
- **Easy testing** with pure functions and interface mocking
- **Safe experimentation** with dry-run capabilities  
- **Future extension** for multi-screen and layout systems
- **Clean maintenance** with separated concerns and comprehensive testing