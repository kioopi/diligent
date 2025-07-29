# Diligent

A declarative, per-project workspace manager for AwesomeWM.

[![CI](https://github.com/user/diligent/actions/workflows/ci.yml/badge.svg)](https://github.com/user/diligent/actions/workflows/ci.yml)

## Project Status

Currently in **Phase 0: Project Scaffolding & Continuous Integration**.

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

# Verify everything is set up correctly
./scripts/check-dev-tools.sh

# Run development tasks
make test lint fmt
```

For detailed setup instructions, testing, and contribution guidelines, see the [Developer Guide](docs/developer-guide.md).

## Exit Criteria
- [x] `git clone && luarocks make` succeeds
- [x] `make test lint fmt` all pass locally
- [x] CI passes with ≥60% coverage on Lua 5.3 & 5.4
- [x] Modern rockspec with proper dependencies
- [x] Comprehensive toolchain setup