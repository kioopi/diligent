### **Phase 0: Project Scaffold & Continuous Integration**

This plan will walk you through initializing the repository, setting up the development toolchain, and creating a robust CI pipeline.

#### **Step 1: Repository Bootstrap**

First, we'll create the directory structure and initialize the Git repository. We'll also add standard project files like a `LICENSE`, `.gitignore`, and an `.editorconfig` for consistent coding styles.

```bash
# Create the main project folder and the initial directory structure
mkdir -p diligent/{cli,lua,spec,docs}
cd diligent

# Initialize the Git repository
git init

# Create the README.md file
cat << 'EOF' > README.md
# Diligent

A declarative, per-project workspace manager for AwesomeWM.

*This project is currently in Phase 0: Scaffolding.*
EOF

# Create the MIT LICENSE file
cat << 'EOF' > LICENSE
MIT License

Copyright (c) 2025 [Your Name]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

# Create a .gitignore file for Lua projects
cat << 'EOF' > .gitignore
# LuaRocks
*.rock
*.src.rock
_luarocks/

# Build artifacts
luacov.*.out
luacov.report.out
luacov.stats.out

# OS-specific
.DS_Store
Thumbs.db

# Logs
*.log
EOF

# Create an .editorconfig file for consistent formatting
cat << 'EOF' > .editorconfig
# top-most EditorConfig file
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
```

#### **Step 2: LuaRocks Project Setup**

Next, we'll set up the project to be managed by LuaRocks. This makes dependency management and installation straightforward. We'll create a `.rockspec` file that defines our project and its dependencies.

```bash
# Create the rockspec file. 'scm-0' denotes a development version.
cat << 'EOF' > diligent-scm-0.rockspec
-- Rockspec for Diligent (development version)
package = "diligent"
version = "scm-0"
source = {
   url = "git://github.com/user/diligent" -- Replace with your repo URL
}
description = {
   summary = "A declarative, per-project workspace manager for AwesomeWM.",
   homepage = "https://github.com/user/diligent", -- Replace with your repo URL
   license = "MIT"
}
dependencies = {
   "lua >= 5.3",
   "luafilesystem",
   "dkjson",
   "luaposix"
}
build = {
   type = "builtin",
   modules = {
      ["diligent"] = "lua/diligent/init.lua",
      -- Add other modules here as they are created
   },
   install = {
      bin = { "cli/workon" }
   }
}
EOF

# Create stub files so the rockspec can be built successfully
# A stub for the main module
mkdir -p lua/diligent
cat << 'EOF' > lua/diligent/init.lua
-- Diligent main module
local diligent = {}

function diligent.hello()
  return "Hello from Diligent!"
end

return diligent
EOF

# A stub for the CLI command
cat << 'EOF' > cli/workon
#!/usr/bin/env lua
-- Diligent CLI entry point
print("Diligent CLI is not implemented yet.")
EOF

# Make the CLI script executable
chmod +x cli/workon
```

#### **Step 3: Toolchain Configuration**

Now, we'll set up the tools for ensuring code quality: a formatter (`StyLua`), a linter (`Selene`), and a testing framework (`Busted`). We'll create a `Makefile` to easily run these tools.

```bash
# Create the StyLua formatter configuration
cat << 'EOF' > stylua.toml
column_width = 80
indent_type = "Spaces"
indent_width = 2
quote_style = "AutoPreferDouble"
call_parentheses = "Always"
EOF

# Create the Selene linter configuration
cat << 'EOF' > selene.toml
std = "lua54"
EOF

# Create a Makefile for common development tasks
cat << 'EOF' > Makefile
.PHONY: all test lint fmt fmt-check clean

# Variables
LUA_VERSION ?= 5.4
STYLUA = stylua
SELENE = selene
BUSTED = busted

# Targets
all:
	@echo "Available targets: test, lint, fmt, fmt-check, clean"

test:
	@echo "Running tests..."
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

clean:
	@echo "Cleaning up..."
	@rm -f luacov.*.out luacov.report.out luacov.stats.out
EOF

# Create an initial test file to ensure Busted is working
cat << 'EOF' > spec/core_spec.lua
local assert = require "luassert"

describe("Diligent Core", function()
  it("should load the main module", function()
    local diligent = require("diligent")
    assert.is_table(diligent)
  end)

  it("should have a hello function", function()
    local diligent = require("diligent")
    assert.is_function(diligent.hello)
    assert.are.equal("Hello from Diligent!", diligent.hello())
  end)
end)
EOF

# Create a LuaCov config file to exclude test files from coverage reports
cat << 'EOF' > .luacov
-- LuaCov configuration
exclude = {
  "spec"
}
EOF
```

#### **Step 4: Continuous Integration with GitHub Actions**

With the local toolchain ready, we'll automate it using GitHub Actions. This workflow will run on every push and pull request to ensure that all changes meet our quality standards.

```bash
# Create the GitHub Actions workflow directory
mkdir -p .github/workflows

# Create the CI workflow file
cat << 'EOF' > .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [ main ] # Adjust to your default branch
  pull_request:
    branches: [ main ] # Adjust to your default branch

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
        luarocks install luafilesystem
        luarocks install dkjson
        luarocks install luaposix

    - name: Lint Code
      run: make lint

    - name: Check Formatting
      run: make fmt-check

    - name: Run Tests with Coverage
      run: make test

    - name: Check Coverage
      run: |
        echo "Checking coverage..."
        # Extract the total coverage percentage from the report
        COVERAGE=$(tail -n 1 luacov.report.out | grep -o '[0-9.]*%' | sed 's/%//')
        # Round it to an integer
        COVERAGE_INT=$(printf "%.0f" $COVERAGE)
        MIN_COVERAGE=60
        echo "Current coverage is ${COVERAGE_INT}%"
        if [ $COVERAGE_INT -lt $MIN_COVERAGE ]; then
          echo "Error: Code coverage is below the ${MIN_COVERAGE}% threshold."
          exit 1
        else
          echo "Code coverage check passed."
        fi
EOF
```

#### **Step 5: Finalizing Documentation**

Finally, let's update the `README.md` to reflect the project's status and provide instructions for new contributors.

```bash
# Overwrite README.md with the new, more detailed version
cat << 'EOF' > README.md
# Diligent

A declarative, per-project workspace manager for AwesomeWM.

[![CI](https://github.com/user/diligent/actions/workflows/ci.yml/badge.svg)](https://github.com/user/diligent/actions/workflows/ci.yml)
<!-- Add a coverage badge here once integrated with a service like Codecov -->

Diligent eliminates context-switching drag by letting you *declare* your project workspace once, then summon or dismiss it with a single command.

## Project Status

This project is in active development. The current focus is **Phase 0: Project Scaffolding & Continuous Integration**.

### Planning Documents
- [Purpose & Vision](planing/01-Purpose.md)
- [Feature Requirements](planing/02-Feature-requirements.md)
- [Architecture Overview](planing/03-Architecture-overview.md)
- [DSL Reference](planing/04-DSL.md)
- [Development Roadmap](planing/05-roadmap.md)

## Developer Setup

To get started with developing Diligent, you'll need a working Lua environment and LuaRocks.

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/user/diligent.git # Replace with your repo URL
    cd diligent
    ```

2.  **Install dependencies:**
    You will need `busted`, `luacov`, and the dependencies listed in the `.rockspec` file.
    ```bash
    luarocks install busted luacov
    luarocks make
    ```

3.  **Run the toolchain:**
    - `make lint`: Check for code style issues.
    - `make fmt`: Format all Lua files.
    - `make test`: Run the test suite with coverage.
EOF
```

---

This completes the detailed plan for Phase 0. After executing all these steps, you will have a robust project foundation with automated quality checks, ready for Phase 1 development to begin.
