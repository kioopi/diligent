# Diligent

A declarative, per-project workspace manager for AwesomeWM.

[![CI](https://github.com/user/diligent/actions/workflows/ci.yml/badge.svg)](https://github.com/user/diligent/actions/workflows/ci.yml)

## Project Status

**Phase 0 Complete**: Project scaffolding, CI/CD, and D-Bus communication layer implemented.

**Current Features:**
- ✅ Fast D-Bus communication between CLI and AwesomeWM (~12-16ms response time)
- ✅ Working `workon ping` command for testing connectivity  
- ✅ Comprehensive test suite with >60% coverage
- ✅ Clean two-layer communication architecture

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

Diligent uses a **dual-layer D-Bus communication system**:

1. **Direct D-Bus Execution** - For immediate responses and debugging
2. **Signal-Based Commands** - For structured application commands

**Performance**: ~12-16ms ping response time via pure D-Bus communication.

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

## Phase 0 Exit Criteria ✅ Complete
- [x] `git clone && luarocks make` succeeds
- [x] `make test lint fmt` all pass locally  
- [x] CI passes with ≥60% coverage on Lua 5.4
- [x] Modern rockspec with proper dependencies
- [x] Comprehensive toolchain setup
- [x] D-Bus communication layer implemented and tested
- [x] Working CLI with `workon ping` command
- [x] Clean dual-layer communication architecture