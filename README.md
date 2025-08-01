# Diligent

A declarative, per-project workspace manager for AwesomeWM.

[![CI](https://github.com/user/diligent/actions/workflows/ci.yml/badge.svg)](https://github.com/user/diligent/actions/workflows/ci.yml)

## Project Status

**Phase 0 Complete**: Project scaffolding, CI/CD, and D-Bus communication layer implemented.  
**Phase 1 Architecture**: Major modular refactoring completed with production-ready foundation.

**Current Features:**
- ✅ Fast D-Bus communication between CLI and AwesomeWM (~12-16ms response time)
- ✅ **DSL Validation System**: Complete project configuration validation with helpful error messages
- ✅ **Project Validation**: `workon validate` command for immediate DSL feedback  
- ✅ **Modular Architecture**: Clean handler system with lua-LIVR validation
- ✅ **Dual Communication Layer**: Async signals (`emit_command`) and sync dispatch (`dispatch_command`)
- ✅ **Robust Error Handling**: Structured validation and error responses
- ✅ **Handler Registration System**: Extensible architecture for new commands
- ✅ Comprehensive test suite with >95% coverage (387+ tests)

## Installation

### Prerequisites

- **Lua 5.4** - `lua --version`
- **LuaRocks** - `luarocks --version` 
- **AwesomeWM** with D-Bus support - `awesome --version | grep -i dbus`
- **LGI** (Lua GObject Introspection) - for D-Bus communication

### System Dependencies

Install the required system packages:

```bash
# Arch Linux
sudo pacman -S lua luarocks awesome lua-lgi

# Ubuntu/Debian
sudo apt install lua5.4 luarocks awesome gir1.2-glib-2.0 lua-lgi

# Fedora
sudo dnf install lua luarocks awesome lua-lgi
```

### Installation Methods

#### Option 1: From Source (Development)

```bash
# Clone the repository
git clone https://github.com/user/diligent.git
cd diligent

# Install development dependencies
luarocks install --deps-only diligent-dev-scm-0.rockspec

# Verify installation
./scripts/check-dev-tools.sh
make test

# Test CLI functionality
./cli/workon ping
```

#### Option 2: Via LuaRocks (Coming Soon)

```bash
# Install stable release (when available)
luarocks install diligent

# Test installation
workon ping
```

### AwesomeWM Configuration

Add the Diligent module to your AwesomeWM configuration:

```lua
-- In your ~/.config/awesome/rc.lua, add after other require statements:
local diligent = require("diligent")

-- The module will automatically register signal handlers for CLI communication
```

Restart AwesomeWM to load the module:
```bash
awesome-client "awesome.restart()"
```

### Verification

Test the D-Bus communication:

```bash
# Test connectivity with AwesomeWM
./cli/workon ping

# Expected output:
# ✓ AwesomeWM is available via D-Bus
# ✓ Ping sent successfully  
# ℹ Response: {"status":"success","message":"pong",...}
```

### Troubleshooting

**Command not found**: Ensure the `cli/` directory is in your PATH or use the full path `./cli/workon`.

**D-Bus connection failed**: 
- Verify AwesomeWM is running with D-Bus support
- Check that the Diligent module is loaded in your AwesomeWM config
- Ensure LGI is properly installed: `lua -e "require('lgi')"`

**Permission issues**: Make sure the CLI script is executable:
```bash
chmod +x cli/workon
```

## Usage Guide

### Available Commands

Diligent provides a growing set of CLI commands for managing workspace projects:

```bash
# Test connectivity with AwesomeWM
workon ping

# Validate project configuration files
workon validate <project-name>
workon validate --file <path-to-dsl-file>

# Get help and see all available commands
workon --help
```

### Project Configuration Validation

Diligent includes a powerful validation system that helps you catch configuration errors early:

```bash
# Validate a project by name (looks in ~/.config/diligent/projects/)
workon validate my-project

# Validate a specific DSL file
workon validate --file ~/my-projects/webapp.lua

# Test with example files
workon validate --file lua/dsl/examples/web-development.lua
```

**Successful validation output:**
```
✓ DSL syntax valid
✓ Required fields present (name, resources)
✓ Project name: "web-development"
✓ Resource 'editor': app helper valid (tag: relative offset 0)
✓ Resource 'browser': app helper valid (tag: absolute tag 3)
✓ Resource 'database': app helper valid (tag: named "db")
✓ Hooks configured: start, stop

✓ Validation passed: 9 checks passed, 0 errors
```

**Error example output:**
```
✗ Validation failed:
✗   resource 'editor': cmd field is required
```

### Configuration Directory

Diligent looks for project configuration files in:
```
~/.config/diligent/projects/
├── my-webapp.lua
├── research-notes.lua
└── client-work.lua
```

## DSL Reference

Diligent uses a declarative Domain Specific Language (DSL) written in Lua for defining project workspaces. Each project is defined as a Lua file that returns a configuration table.

### Basic Structure

Every Diligent project file follows this structure:

```lua
return {
  name = "project-name",        -- Required: project identifier
  
  resources = {                 -- Required: applications to launch
    -- Resource definitions go here
  },
  
  hooks = {                     -- Optional: lifecycle commands
    -- Hook definitions go here  
  }
}
```

### Resources

Resources define the applications that make up your workspace. Currently, Diligent supports the `app{}` resource type:

#### App Resources

The `app{}` helper creates application resources with the following fields:

```lua
resources = {
  editor = app({
    cmd = "nvim ~/project",     -- Required: command to execute
    dir = "~/project",          -- Optional: working directory
    tag = 1,                    -- Optional: tag specification (default: 0)
    reuse = false              -- Optional: reuse existing windows (default: false)
  })
}
```

**Field Details:**

- **`cmd`** (string, required): Shell command to execute
- **`dir`** (string, optional): Working directory for the command
- **`tag`** (number|string, optional): Tag placement specification (see Tag System below)
- **`reuse`** (boolean, optional): Whether to reuse existing application windows

### Tag System

Diligent provides three ways to specify where applications should be placed:

#### 1. Relative Tags (Numbers)
Place applications relative to a base tag:

```lua
tag = 0   -- Current tag (base + 0)
tag = 1   -- Next tag (base + 1)  
tag = 2   -- Two tags ahead (base + 2)
tag = -1  -- Previous tag (base - 1) [future feature]
```

#### 2. Absolute Tags (String Numbers)
Place applications on specific numbered tags:

```lua
tag = "1"  -- Always on tag 1
tag = "2"  -- Always on tag 2
tag = "9"  -- Always on tag 9 (max: 9)
```

#### 3. Named Tags (Strings)
Create or use named tags for logical grouping:

```lua
tag = "editor"      -- Create/use tag named "editor"
tag = "browser"     -- Create/use tag named "browser"  
tag = "database"    -- Create/use tag named "database"
```

**Named tag rules:**
- Must start with a letter
- Can contain letters, numbers, underscore, or dash
- Examples: `"dev"`, `"web_browser"`, `"client-work"`

### Hooks

Hooks allow you to run commands before and after workspace operations:

```lua
hooks = {
  start = "docker-compose up -d && sleep 2",  -- Run before opening applications
  stop = "docker-compose down"               -- Run when closing workspace
}
```

**Available hooks:**
- **`start`**: Execute before launching applications
- **`stop`**: Execute when shutting down workspace

### Complete Examples

#### Minimal Project
```lua
return {
  name = "quick-notes",
  
  resources = {
    editor = app({
      cmd = "gedit ~/notes/scratch.txt",
      tag = 0,      -- Current tag
      reuse = true  -- Reuse existing window
    })
  }
}
```

#### Web Development Project
```lua
return {
  name = "webapp-dev",
  
  resources = {
    -- Code editor on current tag
    editor = app({
      cmd = "code ~/projects/webapp",
      dir = "~/projects/webapp", 
      tag = 0,      -- Relative: current tag
      reuse = true
    }),
    
    -- Terminal for development server
    terminal = app({
      cmd = "alacritty -e npm run dev",
      dir = "~/projects/webapp",
      tag = 1       -- Relative: next tag
    }),
    
    -- Browser for testing
    browser = app({
      cmd = "firefox --new-window http://localhost:3000",
      tag = "3",    -- Absolute: always tag 3
      reuse = true
    }),
    
    -- Database tools on named tag
    database = app({
      cmd = "dbeaver",
      tag = "db",   -- Named: create/use "db" tag
      reuse = true
    })
  },
  
  hooks = {
    start = "docker-compose up -d && sleep 2",
    stop = "docker-compose down"
  }
}
```

### Validation and Error Handling

Diligent provides comprehensive validation with helpful error messages:

**Common validation errors:**
- `"name field is required"` - Missing project name
- `"cmd field is required"` - Missing command in app resource
- `"absolute tag must be between 1 and 9, got 10"` - Invalid absolute tag
- `"invalid tag name format: must start with letter..."` - Invalid named tag format

**Test validation with error examples:**
```bash
# Test different error scenarios
workon validate --file lua/dsl/examples/errors/missing-required-fields.lua
workon validate --file lua/dsl/examples/errors/invalid-tag-specifications.lua  
workon validate --file lua/dsl/examples/errors/type-validation-errors.lua
```

### Architecture Overview

Diligent features a **production-ready modular architecture**:

**Communication Layer:**
1. **Direct D-Bus Execution** (`dispatch_command`) - For synchronous commands with return values
2. **Signal-Based Commands** (`emit_command`) - For asynchronous operations
3. **Handler Registration System** - Extensible, testable command processing

**Core Components:**
- **Modular Handlers** - Separate modules for each command (ping, spawn_test, kill_test)
- **lua-LIVR Validation** - Robust input validation with detailed error messages
- **Centralized Utils** - Payload parsing, validation, and response formatting
- **Comprehensive Testing** - Mockable architecture with extensive test coverage

**Performance**: ~12-16ms ping response time via optimized D-Bus communication.

## Planning Documents
- [Purpose & Vision](planning/01-Purpose.md)
- [Feature Requirements](planning/02-Feature-requirements.md)  
- [Architecture Overview](planning/03-Architecture-overview.md)
- [DSL Reference](planning/04-DSL.md)
- [Development Roadmap](planning/05-roadmap.md)

## Quick Start

```bash
git clone https://github.com/user/diligent.git
cd diligent
luarocks install --deps-only diligent-dev-scm-0.rockspec

# Verify setup and test CLI
./scripts/check-dev-tools.sh
./cli/workon ping

# Try the DSL validation system
./cli/workon validate --file lua/dsl/examples/web-development.lua
./cli/workon validate --file lua/dsl/examples/errors/missing-required-fields.lua

# Run development tasks
make test lint fmt
```

For detailed setup instructions, testing, and contribution guidelines, see the [Developer Guide](docs/developer-guide.md).

## Development Progress

For detailed milestones, current status, and upcoming features, see the [Development Roadmap](planning/05-roadmap.md).