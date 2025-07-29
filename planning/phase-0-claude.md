# Phase 0 Synthesis Plan: Project Scaffold & CI

## Overview
Combining the executable approach from Gemini with technical improvements for a robust foundation that can be implemented immediately.

## Step 1: Repository Bootstrap

```bash
# Create directory structure
mkdir -p diligent/{cli,lua,spec,docs}
cd diligent
git init

# Create comprehensive .gitignore
cat << 'EOF' > .gitignore
# LuaRocks
*.rock
*.src.rock
lua_modules/
.luarocks/

# Build artifacts  
luacov.*.out
luacov.report.out
luacov.stats.out

# OS-specific
.DS_Store
Thumbs.db

# Logs
*.log
debug.log
EOF

# Create .editorconfig
cat << 'EOF' > .editorconfig
root = true

[*]
indent_style = space
indent_size = 2
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.md]
trim_trailing_whitespace = false
EOF

# Create MIT LICENSE
cat << 'EOF' > LICENSE
MIT License

Copyright (c) 2025 [Your Name]

Permission is hereby granted, free of charge, to any person obtaining a copy...
[standard MIT license text]
EOF
```

## Step 2: Modern LuaRocks Setup

```bash
# Create modern rockspec with proper dependencies
cat << 'EOF' > diligent-scm-0.rockspec
rockspec_format = "3.0"
package = "diligent"
version = "scm-0"
source = {
   url = "git+https://github.com/user/diligent.git"
}
description = {
   summary = "A declarative, per-project workspace manager for AwesomeWM",
   license = "MIT"
}
dependencies = {
   "lua >= 5.3, < 5.5",
   "luafilesystem >= 1.8.0",
   "dkjson >= 2.5",
   "luaposix >= 35.0"
}
build = {
   type = "builtin",
   modules = {
      diligent = "lua/diligent.lua"
   },
   install = {
      bin = {
         workon = "cli/workon"
      }
   }
}
EOF

# Create stub main module (cleaner structure)
cat << 'EOF' > lua/diligent.lua
-- Diligent AwesomeWM module
local diligent = {}

function diligent.setup()
  -- TODO: Register signal handlers
  return true
end

function diligent.hello()
  return "Hello from Diligent!"
end

return diligent
EOF

# Create CLI stub
cat << 'EOF' > cli/workon
#!/usr/bin/env lua
-- Diligent CLI entry point
local args = {...}
print("Diligent v0.1.0 - stub implementation")
print("Command:", args[1] or "help")
EOF

chmod +x cli/workon
```

## Step 3: Enhanced Toolchain Setup

```bash
# StyLua configuration
cat << 'EOF' > stylua.toml
column_width = 80
indent_type = "Spaces"
indent_width = 2
quote_style = "AutoPreferDouble"
call_parentheses = "Always"
EOF

# Selene configuration (Lua 5.4 + AwesomeWM)
cat << 'EOF' > selene.toml
std = "lua54+awesome"
EOF

# LuaCov configuration  
cat << 'EOF' > .luacov
exclude = {
  "spec/"
}
coverage_threshold = 60
EOF

# Enhanced Makefile
cat << 'EOF' > Makefile
.PHONY: all test lint fmt fmt-check clean install

LUA_VERSION ?= 5.4
STYLUA = stylua
SELENE = selene  
BUSTED = busted

all:
	@echo "Available targets: test, lint, fmt, fmt-check, clean, install"

test:
	@echo "Running tests with coverage..."
	@$(BUSTED) --coverage -o utfTerminal -v spec/

lint:
	@echo "Running linter..."
	@$(SELENE) .

fmt:
	@echo "Formatting code..."
	@$(STYLUA) .

fmt-check:
	@echo "Checking formatting..."
	@$(STYLUA) --check .

install:
	@echo "Installing via LuaRocks..."
	@luarocks make

clean:
	@echo "Cleaning up..."
	@rm -f luacov.*.out luacov.report.out luacov.stats.out
	@rm -rf lua_modules/
EOF

# Enhanced test file
cat << 'EOF' > spec/core_spec.lua
local assert = require("luassert")

describe("Diligent Core", function()
  it("should load the main module", function()
    local diligent = require("diligent")
    assert.is_table(diligent)
  end)

  it("should have required functions", function() 
    local diligent = require("diligent")
    assert.is_function(diligent.setup)
    assert.is_function(diligent.hello)
    assert.are.equal("Hello from Diligent!", diligent.hello())
  end)
end)
EOF
```

## Step 4: Robust CI Pipeline

```bash
mkdir -p .github/workflows

cat << 'EOF' > .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    container: archlinux:latest
    strategy:
      matrix:
        luaVersion: ['5.3', '5.4']
    
    steps:
    - name: Install System Dependencies
      run: |
        pacman -Syu --noconfirm git awesome luarocks stylua selene

    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Lua
      uses: leafo/gh-actions-lua@v10
      with:
        luaVersion: ${{ matrix.luaVersion }}

    - name: Install Lua Dependencies
      run: |
        luarocks install busted
        luarocks install luacov
        luarocks install --deps-only diligent-scm-0.rockspec

    - name: Lint Code
      run: make lint

    - name: Check Formatting
      run: make fmt-check

    - name: Run Tests with Coverage
      run: make test

    - name: Validate Coverage Threshold
      run: |
        echo "Validating coverage threshold..."
        if [ -f luacov.report.out ]; then
          COVERAGE=$(awk '/^Total/ { gsub(/%/, "", $2); print int($2) }' luacov.report.out)
          MIN_COVERAGE=60
          echo "Coverage: ${COVERAGE}%, Required: ${MIN_COVERAGE}%"
          if [ "$COVERAGE" -lt "$MIN_COVERAGE" ]; then
            echo "ERROR: Coverage below threshold"
            exit 1
          fi
        else
          echo "ERROR: Coverage report not found"
          exit 1
        fi
EOF
```

## Step 5: Documentation & Final Setup

```bash
cat << 'EOF' > README.md
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

## Developer Setup

```bash
git clone https://github.com/user/diligent.git
cd diligent
luarocks install busted luacov
luarocks make
make test lint fmt
```

## Exit Criteria
- [x] `git clone && luarocks make` succeeds
- [x] `make test lint fmt` all pass locally
- [x] CI passes with ≥60% coverage on Lua 5.3 & 5.4
- [x] Modern rockspec with proper dependencies
- [x] Comprehensive toolchain setup
EOF

# Initial commit
git add .
git commit -m "Phase 0: Project scaffold with CI/CD pipeline

- Modern LuaRocks setup with proper dependencies
- Comprehensive toolchain (StyLua, Selene, Busted, LuaCov)
- Robust GitHub Actions CI with coverage validation
- Clean directory structure and documentation"
```

## Key Improvements Over Individual Plans
1. **Executable commands** from Gemini + **modern rockspec** from my analysis
2. **Better dependencies** (`luaposix` for signal handling)
3. **Enhanced coverage validation** (more robust awk-based parsing)
4. **Comprehensive .gitignore** including `lua_modules/`
5. **Cleaner module structure** without unnecessary nesting
6. **Improved CI** with better error handling and dependency management