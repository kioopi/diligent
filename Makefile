.PHONY: all test lint fmt fmt-check clean install check

LUA_VERSION ?= 5.4
STYLUA = stylua
SELENE = selene
BUSTED = busted

all:
	@echo "Available targets: test, lint, fmt, fmt-check, clean, install, check"

check:
	@echo "Verifying development environment..."
	@./scripts/check-dev-tools.sh

test:
	@echo "Running tests with coverage..."
	@$(BUSTED) spec/

lint:
	@echo "Running linter..."
	@$(SELENE) lua/* cli/*

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
