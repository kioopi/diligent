# Diligent Developer Guide

This guide provides detailed instructions for setting up a development environment, building, testing, and contributing to Diligent.

## Prerequisites

Before you begin, ensure you have the following installed on your system:

### Required System Dependencies

- **Git** - Version control
- **Lua** - 5.4 (check with `lua -v`)
- **LuaRocks** - Lua package manager (check with `luarocks --version`)
- **Make** - Build automation (usually pre-installed on Linux/macOS)
- **LGI** - Lua GObject Introspection for D-Bus communication

### Development Tools

The following tools are required for development but not for end users:

- **StyLua** - Lua code formatter
- **Selene** - Lua linter

#### Installing Development Tools on Arch Linux

```bash
sudo pacman -S lua luarocks stylua selene lua-lgi
```

#### Installing Development Tools on Other Systems

For StyLua:
```bash
# Via cargo (if you have Rust installed)
cargo install stylua

# Or download from GitHub releases
# https://github.com/JohnnyMorganz/StyLua/releases
```

For Selene:
```bash
# Via cargo (if you have Rust installed)
cargo install selene

# Or download from GitHub releases
# https://github.com/Kampfkarren/selene/releases
```

## Project Setup

### 1. Clone the Repository

```bash
git clone https://github.com/user/diligent.git
cd diligent
```

### 2. Install Dependencies

You have two options for installing dependencies:

#### Option A: Development Rockspec (Recommended)

This installs all runtime and development dependencies at once:

```bash
luarocks install --deps-only diligent-dev-scm-0.rockspec
```

#### Option B: Manual Installation

Install runtime dependencies:
```bash
luarocks install --deps-only diligent-scm-0.rockspec
# This installs: luafilesystem, dkjson, luaposix
```

Install development dependencies:
```bash
luarocks install busted luacov
```

### 3. Verify Installation

We provide a comprehensive verification script that checks all tools and dependencies:

```bash
./scripts/check-dev-tools.sh
```

This script will:
- ✅ Check all required system tools and their versions
- ✅ Verify Lua dependencies are installed
- ✅ Test basic project functionality  
- ❌ Report missing tools with installation instructions
- 🎉 Give you next steps if everything is ready

**Manual verification** (if needed):
```bash
# Check that all tools are available
lua -v
luarocks --version
stylua --version
selene --version
busted --version

# Test the CLI
./cli/workon ping
```

## Development Workflow

### Available Make Targets

The project includes a Makefile with common development tasks:

```bash
make all          # Show available targets
make test         # Run tests with coverage
make lint         # Run code linter (Selene)
make fmt          # Format code (StyLua)
make fmt-check    # Check if code is properly formatted
make install      # Install via LuaRocks
make clean        # Clean up generated files
```

### Code Quality Workflow

Before committing changes, always run:

```bash
make fmt lint test
```

This ensures your code is:
- Properly formatted
- Free of linting errors
- Passes all tests with adequate coverage

### Running Tests

#### Basic Test Run
```bash
make test
```

#### Verbose Test Output
```bash
busted -o utfTerminal -v spec/
```

#### Single Test Execution
Run a specific test file or pattern:
```bash
# Run a specific test file
busted spec/integration_spec.lua

# Run tests matching a pattern
busted --pattern="ping" spec/

# Run a specific test by name
busted --filter="should have AwesomeWM available" spec/
```

#### Coverage Report
After running tests, view the coverage report:
```bash
cat luacov.report.out
```

The project requires ≥60% test coverage. The CI pipeline will fail if coverage drops below this threshold.

### Code Formatting

#### Auto-format All Code
```bash
make fmt
```

#### Check Formatting Without Changes
```bash
make fmt-check
```

The project uses StyLua with these settings (see `stylua.toml`):
- 2-space indentation
- 80-character line width
- Auto-prefer double quotes
- Always use call parentheses

### Linting

#### Run Linter
```bash
make lint
```

The project uses Selene with a minimal configuration (see `selene.toml`). 

**Linting Scope:**
- Only lints source code directories: `lua/` and `cli/`
- Excludes test files (`spec/`) since they use Busted-specific globals
- Uses Selene's default rules without specific standard library definitions

**Why this approach?**
- The `lua54+awesome` standard libraries aren't available in this Selene version
- Our current code is basic Lua without AwesomeWM-specific APIs yet
- This setup can be enhanced later when we add AwesomeWM integration

## D-Bus Communication Architecture

Diligent uses D-Bus for fast, reliable communication between the CLI and AwesomeWM. The architecture provides two communication layers:

### Communication Layers

1. **Direct D-Bus Execution** (`execute_in_awesome()`) - For immediate Lua execution
2. **Signal-Based Commands** (`emit_command()`) - For structured application commands

### Testing D-Bus Communication

#### Test AwesomeWM Availability
```bash
lua -e "
local dbus_comm = require('dbus_communication')
local available = dbus_comm.check_awesome_available()
print('AwesomeWM available:', available)
" 2>/dev/null
```

#### Execute Direct Lua Code
```bash
lua -e "
local dbus_comm = require('dbus_communication')
local success, result = dbus_comm.execute_in_awesome('return 42')
print('Success:', success, 'Result:', result)
"
```

#### Send async commands 
```bash
lua -e "
local dbus_comm = require('dbus_communication')
local success, result = dbus_comm.emit_command('ping', {timestamp = '2025-01-01T00:00:00Z'})
print('Success:', success, 'Result:', result)
"
```

#### Send sync commands that return results
```bash
lua -e "
local dbus_comm = require('dbus_communication')
local success, result = dbus_comm.dispatch_command('ping', {timestamp = '2025-01-01T00:00:00Z'})
print('Success:', success, 'Result:', result)
"
```

### Direct D-Bus Testing

You can also test D-Bus communication directly without the Lua wrapper:

```bash
# Test basic AwesomeWM connectivity
dbus-send --session --print-reply --dest=org.awesomewm.awful / org.awesomewm.awful.Remote.Eval string:'return "available"' 2>/dev/null

# Execute Lua code directly
dbus-send --session --print-reply --dest=org.awesomewm.awful / org.awesomewm.awful.Remote.Eval string:'return os.date()' 2>/dev/null

# Test number return types
dbus-send --session --print-reply --dest=org.awesomewm.awful / org.awesomewm.awful.Remote.Eval string:'return 42' 2>/dev/null
```

### Performance Notes

The D-Bus communication layer provides excellent performance:
- **Ping response time**: ~12-16ms average
- **Direct execution**: ~2ms for simple operations
- **No file I/O overhead**: Pure memory-based communication

**GLib Warnings**: You may see GLib-CRITICAL warnings during testing. These are cosmetic and don't affect functionality. They occur because our type-detection code attempts different D-Bus type accessors. To suppress them during testing:

```bash
make test 2>/dev/null
```

## AwesomeWM Integration with awe Module

The `awe` module provides a comprehensive, modular API for all AwesomeWM interactions. It uses a  factory pattern with dependency injection that enables clean testing, dry-run support, and flexible configuration.

### Architecture Overview

The awe module is organized into focused submodules:
- **`awe.client`** - Client finding, tracking, properties, and waiting
- **`awe.spawn`** - Application spawning with configuration and environment handling  
- **`awe.error`** - Error classification, reporting, and user-friendly formatting
- **`awe.tag`** - Tag resolution for string-based specifications
- **`awe.interfaces`** - Interface abstractions (awesome, dry-run, mock)

### Basic Usage Patterns

#### Default Usage (Production)
```lua
local awe = require("awe")

-- Client operations
local client = awe.client.tracker.find_by_pid(1234)
local properties = awe.client.properties.get_client_properties(client)

-- Spawning applications
local pid, snid, msg = awe.spawn.spawner.spawn_with_properties("firefox", "+1", {
  floating = true,
  placement = "center"
})

-- Tag resolution
local success, resolved_tag = awe.tag.resolver.resolve_tag_spec("editor")

-- Error handling
local error_report = awe.error.classifier.classify_error("No such file or directory")
local formatted = awe.error.formatter.format_error_for_user(error_report)
```

#### Testing with Mock Interface
```lua
local awe = require("awe")

-- Create test instance with mock interface
local test_awe = awe.create(awe.interfaces.mock_interface)

-- All operations use mock instead of real AwesomeWM
local client = test_awe.client.tracker.find_by_pid(1234)  -- Uses mock
local pid = test_awe.spawn.spawner.spawn_with_properties("test", "0", {})  -- Uses mock
```

#### Dry-Run Mode
```lua
local awe = require("awe")

-- Create dry-run instance that logs operations without executing
local dry_awe = awe.create(awe.interfaces.dry_run_interface)

-- Operations are logged but don't affect AwesomeWM
dry_awe.spawn.spawner.spawn_with_properties("firefox", "+1", {})  -- Logged only
```

### Detailed Module Usage

#### Client Management (`awe.client`)

**Finding Clients:**
```lua
local awe = require("awe")

-- Find by process ID
local client = awe.client.tracker.find_by_pid(1234)

-- Find by environment variable
local clients = awe.client.tracker.find_by_env("PROJECT_NAME", "myproject")

-- Find by property
local editor_clients = awe.client.tracker.find_by_property("role", "editor")

-- Find by name or class
local firefox = awe.client.tracker.find_by_name_or_class("firefox")

-- Get all tracked clients
local all_clients = awe.client.tracker.get_all_tracked_clients()
```

**Managing Client Properties:**
```lua
-- Get client properties
local properties = awe.client.properties.get_client_properties(client)

-- Set client property
local success = awe.client.properties.set_client_property(client, "role", "editor")

-- Get client information
local info = awe.client.info.get_client_info(client)

-- Read process environment
local env_vars = awe.client.info.read_process_env(1234)
```

**Waiting for Clients:**
```lua
-- Wait for client to appear and set properties
local success, client = awe.client.wait.wait_and_set_properties(1234, {
  role = "editor",
  floating = true
}, {timeout = 10})
```

#### Application Spawning (`awe.spawn`)

**Environment Handling:**
```lua
-- Build command with environment variables
local command = awe.spawn.environment.build_command_with_env("firefox", {
  DISPLAY = ":0",
  PROJECT_ROOT = "/home/user/project"
})
```

**Spawn Configuration:**
```lua
-- Build spawn properties
local properties = awe.spawn.configuration.build_spawn_properties(resolved_tag, {
  floating = true,
  placement = "top_right",
  width = 800,
  height = 600
})
```

**Core Spawning:**
```lua
-- Spawn with full configuration
local pid, snid, msg = awe.spawn.spawner.spawn_with_properties("firefox", "+2", {
  floating = true,
  placement = "center",
  env_vars = {DISPLAY = ":0"},
  timeout = 10
})

-- Simple spawning
local pid, snid, msg = awe.spawn.spawner.spawn_simple("gedit", "0")
```

#### Error Handling (`awe.error`)

**Error Classification:**
```lua
-- Classify error messages
local error_report = awe.error.classifier.classify_error("bash: nonexistent: command not found")
-- Returns: {type = "COMMAND_NOT_FOUND", ...}

-- Get error type constants
local ERROR_TYPES = awe.error.classifier.ERROR_TYPES
```

**Error Reporting:**
```lua
-- Create comprehensive error report
local report = awe.error.reporter.create_error_report({
  {type = "COMMAND_NOT_FOUND", message = "bash: nonexistent: command not found"},
  {type = "TIMEOUT", message = "Client did not appear within 5 seconds"}
})

-- Create spawn summary
local summary = awe.error.reporter.create_spawn_summary(pid, snid, errors, timing)

-- Get actionable suggestions
local suggestions = awe.error.reporter.get_error_suggestions("COMMAND_NOT_FOUND")
```

**Error Formatting:**
```lua
-- Format errors for user display
local formatted = awe.error.formatter.format_error_for_user(error_report)
print(formatted)  -- User-friendly error message with suggestions
```

#### Tag Resolution (`awe.tag`)

**String-Based Tag Resolution:**
```lua
-- Resolve various tag specification formats
local success, tag = awe.tag.resolver.resolve_tag_spec("0")        -- Current tag
local success, tag = awe.tag.resolver.resolve_tag_spec("+2")       -- Current + 2
local success, tag = awe.tag.resolver.resolve_tag_spec("-1")       -- Current - 1
local success, tag = awe.tag.resolver.resolve_tag_spec("3")        -- Absolute tag 3
local success, tag = awe.tag.resolver.resolve_tag_spec("editor")   -- Named tag "editor"

-- With options
local success, tag = awe.tag.resolver.resolve_tag_spec("editor", {
  create_missing = true,
  timeout = 5
})
```

### Integration with D-Bus Communication

The awe module works seamlessly with the existing D-Bus communication layer:

```lua
local dbus_comm = require("dbus_communication")
local awe = require("awe")

-- Execute awe operations in AwesomeWM via D-Bus
local lua_code = string.format([[
  local awe = require("awe")
  local success, tag = awe.tag.resolver.resolve_tag_spec("%s")
  return success and tag.name or "failed"
]], tag_spec)

local success, result = dbus_comm.execute_in_awesome(lua_code)
```

### Factory Pattern and Dependency Injection

The awe module's  architecture enables clean testing and flexible configuration:

#### Factory Pattern Benefits

1. **Clean Testing**: No hacky `package.loaded` overwriting
2. **Multiple Instances**: Can have real, mock, and dry-run instances simultaneously  
3. **Consistent API**: Same pattern across all 15+ modules
4. **Easy Extension**: Add new modules following the same pattern

#### Creating Custom Interfaces

```lua
-- Create custom interface for specialized testing
local custom_interface = {
  get_clients = function() return custom_client_list end,
  spawn = function(cmd) return custom_spawn_logic(cmd) end,
  -- ... other interface methods
}

-- Use custom interface
local custom_awe = awe.create(custom_interface)
```

### Best Practices

#### Use Appropriate Module Level
```lua
-- Good: Use specific modules for focused operations
local clients = awe.client.tracker.find_by_pid(1234)
local error_type = awe.error.classifier.classify_error(msg)

-- Avoid: Importing entire awe when you need one function
-- (Though this is acceptable for scripts that use multiple modules)
```

#### Error Handling
```lua
-- Always check success returns
local success, result, metadata = awe.tag.resolver.resolve_tag_spec("editor")
if not success then
  local formatted_error = awe.error.formatter.format_error_for_user({
    type = "TAG_RESOLUTION_FAILED",
    message = result,  -- Error message when success=false
    context = metadata
  })
  print(formatted_error)
  return
end
```

#### Testing Pattern
```lua
-- In tests, always use factory pattern
describe("My AwesomeWM Feature", function()
  local awe
  
  before_each(function()
    awe = require("awe").create(require("awe").interfaces.mock_interface)
  end)
  
  it("should spawn application", function()
    local pid, snid, msg = awe.spawn.spawner.spawn_simple("test", "0")
    assert.is_not_nil(pid)
  end)
end)
```

### Extending awe Module

To add new functionality to the awe module:

1. **Create new submodule** following the factory pattern
2. **Add to main awe/init.lua** 
3. **Include in factory function**
4. **Write comprehensive tests**
5. **Document API patterns**

Example new module structure:
```lua
-- lua/awe/newmodule/init.lua
local function create_newmodule(interface)
  return {
    operation1 = function(...) ... end,
    operation2 = function(...) ... end,
  }
end

return create_newmodule
```

## Project Structure

```
diligent/
├── cli/                    # Command-line interface
│   ├── commands/           # CLI command implementations
│   └── workon             # Main CLI script
├── lua/                   # Core Lua modules
│   ├── awe/               # AwesomeWM integration layer (modular architecture)
│   │   ├── init.lua       # Main awe module with factory pattern
│   │   ├── interfaces/    # Interface abstractions
│   │   │   ├── init.lua   # Interface factory
│   │   │   ├── awesome_interface.lua    # Live AwesomeWM interface
│   │   │   ├── dry_run_interface.lua    # Dry-run interface
│   │   │   └── mock_interface.lua       # Mock interface for testing
│   │   ├── client/        # Client management modules
│   │   │   ├── init.lua   # Client factory with dependency injection
│   │   │   ├── tracker.lua              # Client finding & tracking
│   │   │   ├── properties.lua           # Client property management
│   │   │   ├── info.lua   # Client information retrieval
│   │   │   └── wait.lua   # Client waiting & polling
│   │   ├── spawn/         # Application spawning modules
│   │   │   ├── init.lua   # Spawn factory with dependency injection
│   │   │   ├── spawner.lua              # Core spawning logic
│   │   │   ├── configuration.lua        # Spawn configuration building
│   │   │   └── environment.lua          # Environment variable handling
│   │   ├── error/         # Error handling framework
│   │   │   ├── init.lua   # Error factory with dependency injection
│   │   │   ├── classifier.lua           # Error classification
│   │   │   ├── reporter.lua             # Error reporting & aggregation
│   │   │   └── formatter.lua            # User-friendly formatting
│   │   └── tag/           # Tag operation modules
│   │       ├── init.lua   # Tag factory with dependency injection
│   │       └── resolver.lua             # String-based tag resolution wrapper
│   ├── tag_mapper/        # Pure tag resolution logic
│   │   ├── init.lua       # Main tag mapper (updated - uses awe interfaces)
│   │   ├── core.lua       # Core tag resolution algorithms
│   │   └── integration.lua # AwesomeWM integration utilities
│   ├── diligent.lua       # AwesomeWM signal handlers
│   ├── dbus_communication.lua # D-Bus communication layer
│   ├── json_utils.lua     # JSON utilities
│   └── cli_printer.lua    # CLI output formatting
├── spec/                  # Test files (643 tests total)
│   ├── awe/               # awe module comprehensive tests
│   │   ├── *_spec.lua     # Individual module tests
│   │   ├── client/        # Client module tests (42 tests)
│   │   ├── spawn/         # Spawn module tests (32 tests)
│   │   ├── error/         # Error module tests (47 tests)
│   │   └── tag/           # Tag module tests (14 tests)
│   ├── tag_mapper/        # Tag mapper tests
│   ├── support/           # Test infrastructure
│   │   ├── mock_awesome.lua    # Canonical mock framework
│   │   └── test_helpers.lua    # Standardized test patterns
│   ├── *_spec.lua         # Core module unit tests
│   └── integration_spec.lua # D-Bus integration tests
├── examples/              # Usage examples and demonstrations
│   └── spawning/          # AwesomeWM spawning examples (using awe modules)
├── scripts/               # Development scripts
│   └── check-dev-tools.sh # Environment verification script
├── docs/                  # Documentation
│   ├── coding-guidelines.md    # Coding standards and API patterns
│   ├── developer-guide.md      # This file
│   └── testing-guidelines.md   # Testing standards and patterns
├── planning/              # Project planning documents
│   └── 07-awe-module-refactoring-plan.md # Architecture documentation
├── .github/workflows/     # CI/CD configuration
├── diligent-scm-0.rockspec       # Production dependencies (single entry point pattern)
├── diligent-dev-scm-0.rockspec   # Development dependencies
├── Makefile              # Build automation
├── .busted               # Test framework configuration
├── stylua.toml           # Code formatter config
├── selene.toml           # Linter config
├── .luacov               # Coverage tool config
├── .editorconfig         # Editor consistency config
└── .gitignore            # Git ignore rules
```

### Key Architecture Notes

- **awe module**:  modular architecture with dependency injection
- **Factory Pattern**: Enables clean testing and dry-run support across all modules
- **Single Entry Point**: `require("awe")` provides access to all submodules without rockspec clutter
- **643 Tests**: Comprehensive test coverage with clean isolation using factory pattern
- **Production Validated**: All example scripts working with modular API in real AwesomeWM

## Testing Strategy

### Test Configuration

The project uses Busted for testing with a `.busted` configuration file that:
- Sets the Lua path to include our `lua/` directory (`lua/?.lua;lua/?/init.lua`)
- Enables verbose output and coverage reporting by default
- Allows tests to `require("diligent")` without needing to install the module

**Why this approach?**
- Tests run against the source code, not an installed version
- No need to reinstall after every code change during development
- Centralizes test configuration in one place

### Test Organization

- **Unit tests** - Test individual functions and modules in isolation
- **Integration tests** - Test component interactions  
- **End-to-end tests** - Test complete workflows (planned for later phases)

### Writing Tests

Tests use the Busted framework with Luassert for assertions:

```lua
local assert = require("luassert")

describe("Module Name", function()
  it("should do something", function()
    local result = my_function()
    assert.are.equal("expected", result)
  end)
end)
```

### Test Coverage

- Place test files in `spec/` directory
- Name test files with `_spec.lua` suffix
- Aim for ≥60% code coverage
- Exclude test files from coverage (configured in `.luacov`)

## Continuous Integration

The project uses GitHub Actions for CI/CD:

- Runs on every push and pull request
- Tests on Lua 5.3 and 5.4
- Verifies formatting, linting, and test coverage
- Uses Arch Linux container for consistent environment

See `.github/workflows/ci.yml` for full configuration.

## Building and Installation

### Development Installation

Install the current development version:

```bash
make install
# or
luarocks make
```

### Testing Installation

After installation, test that the CLI is available:

```bash
workon help
# or test D-Bus communication
workon ping
```

### Uninstalling

```bash
luarocks remove diligent
```

## Common Development Tasks

### Adding a New Feature

1. Create feature branch: `git checkout -b feature/my-feature`
2. Write tests first (TDD approach)
3. Implement the feature
4. Ensure all quality checks pass: `make fmt lint test`
5. Update documentation if needed
6. Commit with descriptive message
7. Push and create pull request

### Adding New Dependencies

#### Runtime Dependencies

Add to `diligent-scm-0.rockspec`:
```lua
dependencies = {
   "lua >= 5.3, < 5.5",
   "new-dependency >= 1.0"
}
```

#### Development Dependencies

Add to `diligent-dev-scm-0.rockspec`:
```lua
dependencies = {
   -- existing dependencies...
   "new-dev-dependency >= 1.0"
}
```

### Debugging

#### Enable Verbose Output

Most tools support verbose modes:
```bash
busted -v spec/                    # Verbose tests
selene --display-style=rich .      # Rich linter output
```

#### Check Tool Versions

```bash
lua -v && luarocks --version && stylua --version && selene --version
```

## Troubleshooting

### Common Issues

#### "Module not found" errors
- Ensure you've installed dependencies: `luarocks install --deps-only diligent-dev-scm-0.rockspec`
- Check Lua path: `lua -e "print(package.path)"`

#### StyLua/Selene not found
- Install system packages or via cargo
- Ensure they're in your PATH: `which stylua selene`

#### Test failures
- Run with verbose output: `busted -v spec/`
- Check that all dependencies are installed
- Verify Lua version compatibility
- For integration tests: ensure AwesomeWM is running with D-Bus support

#### D-Bus communication issues
- Verify AwesomeWM is running: `pgrep awesome`
- Check D-Bus support: `awesome --version | grep -i dbus`
- Test direct D-Bus: `dbus-send --session --print-reply --dest=org.awesomewm.awful / org.awesomewm.awful.Remote.Eval string:'return "test"'`
- Ensure LGI is installed: `lua -e "require('lgi')"`

#### Coverage too low
- Add more test cases
- Remove dead code
- Check `.luacov` excludes are correct

### Getting Help

- Check existing issues on GitHub
- Review planning documents in `planning/`
- Ask questions in discussions or issues

## Code Style Guidelines

For comprehensive coding standards and API design patterns, see **[Coding Guidelines](coding-guidelines.md)**.

### Quick Reference

- Use 2-space indentation
- Prefer double quotes for strings
- Always use parentheses for function calls
- Follow established API patterns for consistency

### API Design Standards

All functions should follow these patterns:
- **Signature**: `function module.operation(primary_input, context, options)`
- **Returns**: `return success, result, metadata`
- **Validation**: Always validate inputs with clear error messages

### Documentation Requirements

- Use Lua Language Server annotations for type safety
- Add LuaDoc comments for all public functions
- Update README.md for user-facing changes
- Update this developer guide for workflow changes
- Keep planning documents current

**See [Coding Guidelines](coding-guidelines.md) for detailed examples and patterns.**

## Release Process

*Note: This section will be updated as the project matures*

1. Ensure all tests pass and coverage is adequate
2. Update version numbers in rockspec files
3. Tag release: `git tag v1.0.0`
4. Push tags: `git push --tags`
5. GitHub Actions will handle the rest

---

For questions or suggestions about this developer guide, please open an issue or discussion on GitHub.
