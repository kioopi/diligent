# Diligent

A declarative, per-project workspace manager for AwesomeWM.

[![CI](https://github.com/user/diligent/actions/workflows/ci.yml/badge.svg)](https://github.com/user/diligent/actions/workflows/ci.yml)

## Project Status

**Phase 0 Complete**: Project scaffolding, CI/CD, and D-Bus communication layer implemented.  
**Phase 1 Architecture**: Major modular refactoring completed with production-ready foundation.

**Current Features:**
- ✅ Fast D-Bus communication between CLI and AwesomeWM (~12-16ms response time)
- ✅ Working `workon ping` command for testing connectivity  
- ✅ **Modular Architecture**: Clean handler system with lua-LIVR validation
- ✅ **Dual Communication Layer**: Async signals (`emit_command`) and sync dispatch (`dispatch_command`)
- ✅ **Robust Error Handling**: Structured validation and error responses
- ✅ **Handler Registration System**: Extensible architecture for new commands
- ✅ Comprehensive test suite with >60% coverage

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

# Run development tasks
make test lint fmt
```

For detailed setup instructions, testing, and contribution guidelines, see the [Developer Guide](docs/developer-guide.md).

## Development Progress

For detailed milestones, current status, and upcoming features, see the [Development Roadmap](planning/05-roadmap.md).