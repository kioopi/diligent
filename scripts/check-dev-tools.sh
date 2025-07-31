#!/bin/bash
# Diligent Development Environment Verification Script
# Checks that all required tools and dependencies are available

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track overall status
OVERALL_STATUS=0
MISSING_TOOLS=()
MISSING_DEPS=()

print_header() {
    echo -e "${BLUE}=== Diligent Development Environment Check ===${NC}"
    echo ""
}

print_section() {
    echo -e "${YELLOW}$1${NC}"
}

check_command() {
    local cmd="$1"
    local description="$2"
    local version_flag="${3:---version}"

    if command -v "$cmd" >/dev/null 2>&1; then
        local version
        version=$($cmd $version_flag 2>/dev/null | head -n1 || echo "version unknown")
        echo -e "  ${GREEN}✓${NC} $description: $version"
        return 0
    else
        echo -e "  ${RED}✗${NC} $description: not found"
        MISSING_TOOLS+=("$cmd")
        OVERALL_STATUS=1
        return 1
    fi
}

check_lua_module() {
    local module="$1"
    local description="$2"

    if lua -e "require('$module')" >/dev/null 2>&1; then
        # Try to get version if possible
        local version
        version=$(lua -e "local m = require('$module'); print(m._VERSION or m.version or 'installed')" 2>/dev/null || echo "installed")
        echo -e "  ${GREEN}✓${NC} Lua module $description: $version"
        return 0
    else
        echo -e "  ${RED}✗${NC} Lua module $description: not available"
        MISSING_DEPS+=("$module")
        OVERALL_STATUS=1
        return 1
    fi
}

print_header

# Check core system tools
print_section "System Tools:"
check_command "lua" "Lua interpreter" "-v"
check_command "luarocks" "LuaRocks package manager" "--version"
check_command "make" "Make build tool" "--version"
check_command "git" "Git version control" "--version"

echo ""

# Check development tools
print_section "Development Tools:"
check_command "stylua" "StyLua code formatter" "--version"
check_command "selene" "Selene Lua linter" "--version"
check_command "busted" "Busted test framework" "--version"

echo ""

# Check Lua dependencies
print_section "Lua Dependencies:"
check_lua_module "lfs" "luafilesystem"
check_lua_module "dkjson" "dkjson"
check_lua_module "posix" "luaposix"
check_lua_module "luacov" "luacov"

echo ""

# Check project-specific things
print_section "Project Setup:"

# Check if we're in the right directory
if [[ -f "diligent-scm-0.rockspec" && -f "Makefile" ]]; then
    echo -e "  ${GREEN}✓${NC} Project files: rockspec and Makefile found"
else
    echo -e "  ${RED}✗${NC} Project files: run this script from the project root directory"
    OVERALL_STATUS=1
fi

# Check if CLI is executable
if [[ -x "cli/workon" ]]; then
    echo -e "  ${GREEN}✓${NC} CLI script: executable"
    # Test CLI
    if ./cli/workon ping >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} CLI functionality: basic test passed"
    else
        echo -e "  ${RED}✗${NC} CLI functionality: basic test failed"
        OVERALL_STATUS=1
    fi
else
    echo -e "  ${RED}✗${NC} CLI script: not found or not executable"
    OVERALL_STATUS=1
fi

echo ""

# Summary
if [[ $OVERALL_STATUS -eq 0 ]]; then
    echo -e "${GREEN}🎉 All checks passed! Your development environment is ready.${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  • Run tests: make test"
    echo "  • Check formatting: make fmt-check"
    echo "  • Run linter: make lint"
    echo "  • See 'make all' for all available targets"
else
    echo -e "${RED}❌ Some checks failed. Please fix the issues below:${NC}"
    echo ""

    if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Missing system tools:${NC}"
        for tool in "${MISSING_TOOLS[@]}"; do
            case $tool in
                stylua)
                    echo "  • Install StyLua: https://github.com/JohnnyMorganz/StyLua#installation"
                    ;;
                selene)
                    echo "  • Install Selene: https://github.com/Kampfkarren/selene#installation"
                    ;;
                busted)
                    echo "  • Install Busted: luarocks install busted"
                    ;;
                *)
                    echo "  • Install $tool (check your package manager)"
                    ;;
            esac
        done
        echo ""
    fi

    if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Missing Lua dependencies:${NC}"
        echo "  • Install all dependencies: luarocks install --deps-only diligent-dev-scm-0.rockspec"
        echo ""
    fi

    echo -e "${BLUE}For detailed setup instructions, see: docs/developer-guide.md${NC}"
fi

exit $OVERALL_STATUS
