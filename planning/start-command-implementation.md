# Start Command Implementation Plan - Test-Driven Development (Updated)

**Last updated:** August 4, 2025  
**Status:** Planning Phase

## Overview

This plan implements the `start` command using strict Test-Driven Development (TDD) principles, following the established CLI architecture patterns used by the `validate` command. Each phase follows the Red-Green-Refactor cycle and maintains complete test coverage.

## Architecture Pattern Analysis

Based on `validate.lua` and `workon`, the established patterns are:

### CLI Architecture Pattern
1. **Main CLI Router** (`cli/workon`) - Uses cliargs with `:command().file()` pattern
2. **Command Scripts** (`cli/commands/*.lua`) - Self-contained scripts that handle their own argument parsing
3. **Support Modules** (`lua/cli/*.lua`) - Reusable modules for common CLI operations
4. **Direct Execution** - Commands can be run directly or via main CLI

### Established Modules
- `lua/cli/validate_args.lua` - Argument validation with standard patterns
- `lua/cli/project_loader.lua` - DSL loading with error classification
- `lua/cli/error_reporter.lua` - Standardized error reporting and exit codes

## Phase 1: Minimal Single App Start (Week 1)

### Goal
Successfully execute: `workon start simple-project` where `simple-project.lua` contains exactly one `app{}` resource.

**Success Criteria:**
- Single application spawns on correct tag
- Application appears in AwesomeWM
- CLI reports success with consistent formatting
- Follows established CLI patterns exactly

### TDD Implementation Steps

#### Step 1.1: CLI Start Command Script Foundation
**🔴 Red Phase - Write Failing Tests:**

```lua
-- spec/cli/commands/start_command_spec.lua
describe("Start Command Script", function()
  describe("argument parsing with cliargs", function()
    it("should parse project name correctly", function()
      -- Mock cliargs behavior
      local mock_cli = {
        parse = function() 
          return {PROJECT_NAME = "my-project"} 
        end
      }
      
      local start_args = require("cli.start_args")
      local success, validated_args = start_args.validate_parsed_args(mock_cli:parse())
      
      assert.is_true(success)
      assert.are.equal("my-project", validated_args.project_name)
      assert.are.equal(start_args.INPUT_TYPE_PROJECT, validated_args.input_type)
    end)
    
    it("should parse --file option correctly", function()
      local mock_cli = {
        parse = function() 
          return {file = "/path/to/project.lua"} 
        end
      }
      
      local start_args = require("cli.start_args")
      local success, validated_args = start_args.validate_parsed_args(mock_cli:parse())
      
      assert.is_true(success)
      assert.are.equal("/path/to/project.lua", validated_args.file_path)
      assert.are.equal(start_args.INPUT_TYPE_FILE, validated_args.input_type)
    end)
  end)
end)
```

**🟢 Green Phase - Implementation:**
```lua
-- lua/cli/start_args.lua (NEW - following validate_args pattern)
local start_args = {}

-- Constants matching validate_args pattern
start_args.INPUT_TYPE_PROJECT = "project"
start_args.INPUT_TYPE_FILE = "file"
start_args.ERROR_MISSING_INPUT = "missing_input"
start_args.ERROR_CONFLICTING_INPUT = "conflicting_input"

local function is_empty(value)
  return value == nil or (type(value) == "string" and value == "")
end

function start_args.validate_parsed_args(args)
  local project_name = args.PROJECT_NAME
  local file_path = args.file

  local has_project = not is_empty(project_name)
  local has_file = not is_empty(file_path)

  if not has_project and not has_file then
    return false, "Must provide either project name or --file option"
  end

  if has_project and has_file then
    return false, "Cannot use both project name and --file option"
  end

  if has_project then
    return true, {
      input_type = start_args.INPUT_TYPE_PROJECT,
      project_name = project_name,
      file_path = nil,
    }
  else
    return true, {
      input_type = start_args.INPUT_TYPE_FILE,
      project_name = nil,
      file_path = file_path,
    }
  end
end

return start_args
```

**🔧 Refactor Phase:**
```lua
-- cli/commands/start.lua (NEW - following validate.lua pattern exactly)
--[[
Start Command Script for Diligent CLI

Implements the start command that launches project workspaces.
Uses the same architectural pattern as validate.lua for consistency.
--]]

-- Setup package path (identical to validate.lua)
local script_dir = arg and arg[0] and arg[0]:match("(.+)/[^/]+$") or "."

local base_paths = {
  script_dir .. "/../?.lua",
  script_dir .. "/../../lua/?.lua",
  script_dir .. "/../../lua/?/init.lua",
  "./lua/?.lua",
  "./lua/?/init.lua",
}

package.path = table.concat(base_paths, ";") .. ";" .. package.path

-- Import required modules (matching validate.lua pattern)
local cli = require("cliargs")
local cli_printer = require("cli_printer")
local start_args = require("cli.start_args")
local project_loader = require("cli.project_loader")
local error_reporter = require("cli.error_reporter")

-- Setup CLI arguments (following cliargs pattern)
cli:set_name("workon start")
cli:set_description("Start project workspaces")

-- Arguments (matching validate.lua exactly)
cli:splat("PROJECT_NAME", "Project name to start (or use --file option)")

-- Options
cli:option("-f, --file=FILE", "Path to DSL file to start")
cli:flag("--dry-run", "Preview operations without execution")

-- Parse arguments (identical pattern to validate.lua)
local args, err = cli:parse()

if not args and err then
  error_reporter.report_and_exit(err, error_reporter.ERROR_INVALID_ARGS)
end

-- Validate parsed arguments (identical pattern)
local args_success, validated_args = start_args.validate_parsed_args(args)
if not args_success then
  error_reporter.report_and_exit(
    validated_args,
    error_reporter.ERROR_INVALID_ARGS
  )
end

-- Phase 1: Only handle project loading, no actual starting yet
-- Load DSL (identical pattern to validate.lua)
local load_success, dsl_or_error

if validated_args.input_type == start_args.INPUT_TYPE_FILE then
  load_success, dsl_or_error =
    project_loader.load_by_file_path(validated_args.file_path)
else
  load_success, dsl_or_error =
    project_loader.load_by_project_name(validated_args.project_name)
end

-- Handle loading errors (identical pattern)
if not load_success then
  local error_type = project_loader.get_error_type(dsl_or_error)
  if error_type == project_loader.ERROR_FILE_NOT_FOUND then
    error_reporter.report_and_exit(
      dsl_or_error,
      error_reporter.ERROR_FILE_NOT_FOUND
    )
  elseif error_type == project_loader.ERROR_PROJECT_NOT_FOUND then
    error_reporter.report_and_exit(
      dsl_or_error,
      error_reporter.ERROR_PROJECT_NOT_FOUND
    )
  else
    error_reporter.report_and_exit(
      dsl_or_error,
      error_reporter.ERROR_VALIDATION
    )
  end
end

-- Phase 1: Minimal implementation - just validate and report success
cli_printer.success("Project loaded successfully: " .. dsl_or_error.name)
cli_printer.info("Resources found: " .. tostring(#dsl_or_error.resources or 0))

-- TODO: In next phases, this is where we'll add:
-- 1. Resource processing
-- 2. D-Bus communication to AwesomeWM
-- 3. Progress reporting
-- 4. Error handling

os.exit(error_reporter.EXIT_SUCCESS)
```

#### Step 1.2: Register Start Command in Main CLI
**🔴 Red Phase:**
```lua
-- spec/cli/workon_spec.lua (UPDATE existing)
describe("Main CLI", function()
  it("should register start command", function()
    -- Test that 'workon start' is recognized as valid command
  end)
end)
```

**🟢 Green Phase:**
```lua
-- cli/workon (UPDATE - add start command registration)
-- Add after line 34:
cli:command("start", "Start project workspaces"):file("cli/commands/start.lua")
```

#### Step 1.3: DSL Resource Processing Module
**🔴 Red Phase:**
```lua
-- spec/dsl/start_processor_spec.lua (NEW)
describe("Start Processor", function()
  local start_processor = require("dsl.start_processor")
  
  describe("resource conversion", function()
    it("should convert single app resource to start request", function()
      local dsl_project = {
        name = "test-project",
        resources = {
          editor = {
            type = "app",
            cmd = "gedit",
            tag = "0",
            dir = "/home/user"
          }
        }
      }
      
      local start_request = start_processor.convert_project_to_start_request(dsl_project)
      
      assert.are.equal("test-project", start_request.project_name)
      assert.are.equal(1, #start_request.resources)
      assert.are.equal("editor", start_request.resources[1].name)
      assert.are.equal("gedit", start_request.resources[1].command)
      assert.are.equal("0", start_request.resources[1].tag_spec)
    end)
    
    it("should handle minimal app resource with defaults", function()
      local dsl_project = {
        name = "minimal",
        resources = {
          app1 = {
            type = "app", 
            cmd = "firefox"
          }
        }
      }
      
      local start_request = start_processor.convert_project_to_start_request(dsl_project)
      
      assert.are.equal("0", start_request.resources[1].tag_spec) -- default
      assert.is_nil(start_request.resources[1].working_dir) -- no default
    end)
  end)
end)
```

**🟢 Green Phase:**
```lua
-- lua/dsl/start_processor.lua (NEW)
local start_processor = {}

function start_processor.convert_project_to_start_request(dsl_project)
  local resources = {}
  
  for name, resource_def in pairs(dsl_project.resources or {}) do
    if resource_def.type == "app" then
      table.insert(resources, {
        name = name,
        command = resource_def.cmd,
        tag_spec = resource_def.tag or "0",
        working_dir = resource_def.dir,
        reuse = resource_def.reuse or false
      })
    end
  end
  
  return {
    project_name = dsl_project.name,
    resources = resources
  }
end

return start_processor
```

#### Step 1.4: AwesomeWM Start Handler
**🔴 Red Phase:**
```lua
-- spec/diligent/handlers/start_handler_spec.lua (NEW)
describe("Start Handler", function()
  local start_handler = require("diligent.handlers.start")
  local mock_awe = require("spec.helpers.mock_awe")
  
  describe("single resource start", function()
    it("should spawn single app successfully", function()
      local payload = {
        project_name = "test-project",
        resources = {
          {
            name = "editor",
            command = "gedit", 
            tag_spec = "0"
          }
        }
      }
      
      local awe_mock = mock_awe.create_mock()
      awe_mock.spawn.spawner.spawn_with_properties = function(cmd, tag, config)
        return 1234, "snid-123", "SUCCESS: Spawned gedit"
      end
      
      local handler = start_handler.create(awe_mock)
      local success, result = handler.execute(payload)
      
      assert.is_true(success)
      assert.are.equal("test-project", result.project_name)
      assert.are.equal(1, #result.spawned_resources)
      assert.are.equal(1234, result.spawned_resources[1].pid)
    end)
    
    it("should handle spawn failure gracefully", function()
      local payload = {
        project_name = "test-project",
        resources = {
          {
            name = "invalid",
            command = "nonexistent-app",
            tag_spec = "0"
          }
        }
      }
      
      local awe_mock = mock_awe.create_mock()
      awe_mock.spawn.spawner.spawn_with_properties = function(cmd, tag, config)
        return nil, nil, "ERROR: Command not found"
      end
      
      local handler = start_handler.create(awe_mock)
      local success, result = handler.execute(payload)
      
      assert.is_false(success)
      assert.matches("Command not found", result.error)
      assert.are.equal("invalid", result.failed_resource)
    end)
  end)
end)
```

**🟢 Green Phase:**
```lua
-- lua/diligent/handlers/start.lua (NEW)
local start_handler = {}

function start_handler.create(awe_module)
  local handler = {}
  
  function handler.execute(payload)
    local spawned_resources = {}
    
    -- Phase 1: Sequential processing of resources
    for _, resource in ipairs(payload.resources or {}) do
      local pid, snid, message = awe_module.spawn.spawner.spawn_with_properties(
        resource.command,
        resource.tag_spec,
        {
          working_dir = resource.working_dir,
          reuse = resource.reuse
        }
      )
      
      if pid then
        table.insert(spawned_resources, {
          name = resource.name,
          pid = pid,
          snid = snid,
          command = resource.command,
          tag_spec = resource.tag_spec
        })
      else
        return false, {
          error = message or "Unknown spawn failure",
          failed_resource = resource.name,
          project_name = payload.project_name
        }
      end
    end
    
    return true, {
      project_name = payload.project_name,
      spawned_resources = spawned_resources,
      total_spawned = #spawned_resources
    }
  end
  
  return handler
end

-- Validator following established pattern
start_handler.validator = {
  project_name = "required|string",
  resources = "required|list_of_objects"
}

return start_handler
```

#### Step 1.5: Integration with D-Bus Communication
**🔴 Red Phase:**
```lua
-- spec/integration/start_command_integration_spec.lua (NEW)
describe("Start Command Integration", function()
  it("should coordinate full start process via D-Bus", function()
    -- Test full flow: CLI -> DSL loading -> D-Bus -> AwesomeWM -> Response
    -- This uses real dbus_communication module but with test environment
  end)
end)
```

**🟢 Green Phase:**
```lua
-- lua/diligent.lua (UPDATE - register start handler)
function diligent.setup()
  diligent.register_handler("diligent::ping", ping_handler)
  diligent.register_handler("diligent::spawn_test", spawn_test_handler)
  diligent.register_handler("diligent::kill_test", kill_test_handler)
  
  -- NEW: Register start handler
  local start_handler = require("diligent.handlers.start")
  local awe = require("awe")
  diligent.register_handler("diligent::start", start_handler.create(awe))
  
  return true
end
```

**🔧 Refactor Phase - Update CLI Command:**
```lua
-- cli/commands/start.lua (UPDATE - add D-Bus communication)
-- Add after DSL loading success:

-- Convert DSL to start request
local start_processor = require("dsl.start_processor")
local start_request = start_processor.convert_project_to_start_request(dsl_or_error)

-- Send to AwesomeWM via D-Bus
local dbus_communication = require("dbus_communication")
local comm_success, response = dbus_communication.dispatch_command("diligent::start", start_request)

if not comm_success then
  error_reporter.report_and_exit(
    "Failed to communicate with AwesomeWM: " .. tostring(response),
    error_reporter.ERROR_VALIDATION
  )
end

-- Parse and display results
if response.success then
  cli_printer.success("Started " .. response.project_name .. " successfully")
  cli_printer.info("Spawned " .. tostring(response.total_spawned) .. " resources")
  
  for _, resource in ipairs(response.spawned_resources or {}) do
    cli_printer.info("  ✓ " .. resource.name .. " (PID: " .. resource.pid .. ")")
  end
else
  error_reporter.report_and_exit(
    "Start failed: " .. (response.error or "Unknown error"),
    error_reporter.ERROR_VALIDATION
  )
end
```

### Phase 1 Testing Strategy

#### Unit Tests (Following Established Pattern)
- `spec/cli/start_args_spec.lua` - Argument validation (mirrors validate_args_spec.lua)
- `spec/dsl/start_processor_spec.lua` - DSL conversion logic
- `spec/diligent/handlers/start_handler_spec.lua` - AwesomeWM handler logic

#### Integration Tests
- `spec/cli/commands/start_command_spec.lua` - CLI script integration
- Uses established mock patterns from validate command tests

#### End-to-End Tests  
- `spec/integration/start_command_integration_spec.lua` - Full system test
- Uses real AwesomeWM environment like existing tests

#### Test Coverage Requirements (Matching Project Standards)
- **Unit Tests:** 100% line coverage per module
- **Integration Tests:** All success/failure code paths
- **E2E Tests:** Representative user scenarios

---

## Phase 2: Multiple Resources Support (Week 2)

### Goal
Support projects with multiple `app{}` resources, spawning them sequentially with proper error handling.

### Key Changes from Phase 1
- Update start_processor to handle multiple resources
- Enhance start_handler for sequential spawning with partial failure handling
- Add progress reporting during multi-resource starts
- Maintain established CLI patterns throughout

---

## Phase 3: Advanced Tag Specifications (Week 3)

### Goal
Full support for relative (`+1`, `-1`), absolute (`"3"`), and named (`"editor"`) tag specifications.

### Integration Points
- Leverage existing tag_mapper module
- Use awe.tag.resolver for tag resolution
- Follow established error handling patterns

---

## Phase 4: Pre-Start Hooks (Week 4)

### Goal
Execute `hooks.start` shell commands before resource spawning.

### Architecture Consistency
- Create `lua/cli/hook_executor.lua` following established CLI module patterns
- Add hook validation to start_args module
- Maintain error_reporter integration for hook failures

---

## Phase 5: Dry-Run Mode (Week 5)

### Goal
Implement `--dry-run` flag using existing awe interface abstraction.

### Leverage Existing Architecture
- Use awe.create(dry_run_interface) pattern already established
- Follow cliargs flag pattern from existing commands
- Reuse CLI output formatting patterns

---

## Phase 6: Enhanced Error Handling (Week 6)

### Goal
Production-ready error handling with user-friendly messages and recovery suggestions.

### Consistency with Existing Error Patterns
- Extend error_reporter module with start-specific error types
- Follow established error classification patterns
- Maintain consistent CLI output formatting

---

## Updated Architecture Benefits

### Consistency with Existing Codebase
- **CLI Pattern Reuse**: Identical structure to validate.lua ensures maintainability
- **Module Reuse**: Leverages existing validate_args, project_loader, error_reporter
- **Testing Patterns**: Follows established test organization and mock patterns

### Reduced Implementation Risk
- **Proven Patterns**: Uses architecture already validated in production
- **Module Compatibility**: Integrates seamlessly with existing CLI infrastructure
- **Testing Infrastructure**: Reuses existing test helpers and CI setup

### Maintainability
- **Consistent Style**: Developers familiar with validate.lua can easily work on start.lua
- **Shared Components**: Changes to CLI infrastructure benefit all commands
- **Standard Error Handling**: Unified error reporting across all commands

This updated plan ensures the start command implementation follows the exact patterns established by the validate command, maximizing code reuse and maintaining architectural consistency throughout the project.