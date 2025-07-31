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
2. **Signal-Based Commands** (`send_command()`) - For structured application commands

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

#### Send Structured Commands
```bash
lua -e "
local dbus_comm = require('dbus_communication')
local success, result = dbus_comm.send_command('ping', {timestamp = '2025-01-01T00:00:00Z'})
print('Success:', success, 'Result:', result)
"
```

#### Test Ping Communication
```bash
lua -e "
local dbus_comm = require('dbus_communication')
local success, response = dbus_comm.send_ping({timestamp = '2025-01-01T00:00:00Z'})
print('Success:', success)
if success then
  local parse_success, data = dbus_comm.parse_response(response)
  if parse_success then
    print('Status:', data.status, 'Message:', data.message)
  end
end
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

## Project Structure

```
diligent/
├── cli/                    # Command-line interface
│   └── workon             # Main CLI script
├── lua/                   # Core Lua modules
│   ├── diligent.lua       # AwesomeWM signal handlers
│   └── dbus_communication.lua # D-Bus communication layer
├── spec/                  # Test files
│   ├── *_spec.lua         # Unit tests
│   └── integration_spec.lua # D-Bus integration tests
├── scripts/               # Development scripts
│   └── check-dev-tools.sh # Environment verification script
├── docs/                  # Documentation
├── planning/              # Project planning documents
├── .github/workflows/     # CI/CD configuration
├── diligent-scm-0.rockspec       # Production dependencies
├── diligent-dev-scm-0.rockspec   # Development dependencies
├── Makefile              # Build automation
├── .busted               # Test framework configuration
├── stylua.toml           # Code formatter config
├── selene.toml           # Linter config
├── .luacov               # Coverage tool config
├── .editorconfig         # Editor consistency config
└── .gitignore            # Git ignore rules
```

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

### Lua Conventions

- Use 2-space indentation
- Prefer double quotes for strings
- Always use parentheses for function calls
- Follow AwesomeWM coding patterns for WM integration

### Naming Conventions

- `snake_case` for variables and functions
- `PascalCase` for modules/classes
- `UPPER_CASE` for constants
- Descriptive names over short names

### Documentation

- Add LuaDoc comments for public functions
- Update README.md for user-facing changes
- Update this developer guide for workflow changes
- Keep planning documents current

## Release Process

*Note: This section will be updated as the project matures*

1. Ensure all tests pass and coverage is adequate
2. Update version numbers in rockspec files
3. Tag release: `git tag v1.0.0`
4. Push tags: `git push --tags`
5. GitHub Actions will handle the rest

---

For questions or suggestions about this developer guide, please open an issue or discussion on GitHub.