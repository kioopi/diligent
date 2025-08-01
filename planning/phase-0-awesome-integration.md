# Phase 0 Completion: AwesomeWM Communication Proof-of-Concept

*Last updated: 29 Jul 2025*

## Objective
Prove that Diligent can communicate with AwesomeWM and manage basic application lifecycle before declaring Phase 0 complete.

## What We Need to Prove
1. **Bidirectional communication** between CLI and AwesomeWM via `awesome-client`
2. **Application spawning** through AwesomeWM's APIs
3. **Process tracking** and termination capabilities
4. **Signal handling** for basic commands

## Implementation Plan (Following TDD)

### Step 1: Communication Layer (TDD)

#### 1.1 Write Tests for CLI Communication
Create `spec/cli_communication_spec.lua`:
- Test JSON payload creation
- Test awesome-client command execution (mocked)
- Test response parsing
- Test error handling when AwesomeWM not available

#### 1.2 Write Tests for AwesomeWM Module  
Create `spec/awesome_module_spec.lua`:
- Test signal registration
- Test signal handler execution (mocked AwesomeWM APIs)
- Test JSON payload parsing
- Test response emission

#### 1.3 Implement Communication Layer
**CLI Side** (`lua/cli_communication.lua`):
```lua
local cli_comm = {}

function cli_comm.emit_command(command, payload)
  -- Send JSON via awesome-client
  -- Return success/failure and response
end

function cli_comm.check_awesome_available()
  -- Test if awesome-client works
end

return cli_comm
```

**AwesomeWM Side** (enhance `lua/diligent.lua`):
```lua
function diligent.setup()
  awesome.connect_signal("diligent::ping", handle_ping)
  awesome.connect_signal("diligent::spawn_test", handle_spawn_test)
  awesome.connect_signal("diligent::kill_test", handle_kill_test)
end
```

### Step 2: Application Management (TDD)

#### 2.1 Write Tests for Application Spawning
Create `spec/app_manager_spec.lua`:
- Test application spawn with PID tracking
- Test application termination by PID
- Test process status checking
- Test error handling for failed spawns

#### 2.2 Implement Application Manager
**Create** `lua/app_manager.lua`:
```lua
local app_manager = {}

function app_manager.spawn_app(command, callback)
  -- Use awful.spawn.with_line_callback or awful.spawn
  -- Track PID and return handle
end

function app_manager.kill_app(pid)
  -- Send SIGTERM, wait, then SIGKILL if needed
end

function app_manager.is_running(pid)
  -- Check if process is still alive
end

return app_manager
```

### Step 3: Integration Commands

#### 3.1 Add Basic CLI Commands
Enhance `cli/workon` to support:
- `workon ping` - Test AwesomeWM communication
- `workon spawn <command>` - Spawn a test application
- `workon kill <pid>` - Kill a tracked application
- `workon status` - Show AwesomeWM connection status

#### 3.2 Wire Up AwesomeWM Handlers
Complete the AwesomeWM module signal handlers:
- `diligent::ping` → respond with "pong" + timestamp
- `diligent::spawn_test` → spawn app, return PID
- `diligent::kill_test` → kill by PID, return success/fail

### Step 4: Manual Verification

#### 4.1 Create Integration Test Script
**Create** `scripts/test-awesome-integration.sh`:
```bash
#!/bin/bash
# Script to manually test AwesomeWM integration
# Must be run while AwesomeWM is running

echo "Testing Diligent <-> AwesomeWM communication..."

# Test 1: Ping
echo "1. Testing ping..."
./cli/workon ping

# Test 2: Spawn application
echo "2. Testing spawn..."
PID=$(./cli/workon spawn "xterm")

# Test 3: Kill application  
echo "3. Testing kill..."
./cli/workon kill $PID

echo "Integration test complete!"
```

#### 4.2 Create AwesomeWM Test Config
**Create** `scripts/test-awesome-config.lua`:
```lua
-- Minimal AwesomeWM config for testing Diligent
-- Copy to ~/.config/awesome/rc.lua for testing

require("awful")
local diligent = require("diligent")

-- Setup Diligent
diligent.setup()

-- Minimal AwesomeWM setup for testing
-- ... basic awful configuration
```

### Step 5: Documentation & Testing

#### 5.1 Update Documentation
- Add AwesomeWM integration testing section to developer guide
- Document manual testing procedures
- Update architecture docs with actual implementation details

#### 5.2 CI Considerations
- Mock AwesomeWM APIs in CI tests (no actual AwesomeWM)
- Add integration test badge to README  
- Document that full testing requires AwesomeWM

## Success Criteria

### Automated Tests (TDD)
- [x] All communication layer tests pass (mocked)
- [ ] All application manager tests pass (mocked)
- [x] Code coverage remains ≥60%
- [x] All existing quality gates pass

### Manual Integration Tests
- [x] `workon ping` successfully communicates with AwesomeWM (basic test)
- [ ] `workon spawn xterm` opens xterm and returns PID
- [ ] `workon kill <pid>` successfully terminates the process
- [x] Error handling works when AwesomeWM is not running

### Quality Standards
- [x] All code follows TDD (tests written first)
- [x] Code is modular and testable
- [x] Documentation updated
- [x] No breaking changes to existing API

## Implementation Order

1. **Write failing tests** for communication layer ✅ **COMPLETED**
2. **Implement communication** to make tests pass ✅ **COMPLETED**
3. **Write failing tests** for app management ⏳ **NEXT**
4. **Implement app management** to make tests pass
5. **Create integration test script**
6. **Manual testing** with actual AwesomeWM
7. **Documentation updates**
8. **Final commit** completing Phase 0

## Current Progress (WIP)

### ✅ Completed
- **CLI Communication Layer** (`lua/cli_communication.lua`)
  - JSON payload encoding with error handling
  - Shell escaping for safe `awesome-client` execution  
  - Response parsing and validation
  - AwesomeWM availability checking
  - **22 passing tests** with comprehensive mocking

- **AwesomeWM Signal Handlers** (`lua/diligent.lua`)
  - Signal registration system (`diligent::ping`, `diligent::spawn_test`, `diligent::kill_test`)
  - JSON payload parsing with error handling
  - Mock response generation for testing
  - Proper response emission back to CLI
  - **All tests passing** with mocked AwesomeWM APIs

- **CLI Tool Enhancement** (`cli/workon`)
  - Help system with command descriptions
  - `workon ping` command for basic communication testing
  - Colored output for better user experience
  - Error handling for unknown commands
  - Graceful failure when AwesomeWM not available

### 🔄 In Progress
- Application manager for real process spawning/killing
- Integration test scripts for manual AwesomeWM testing

### 📋 Remaining Tasks
- Write failing tests for application manager
- Implement real process management with PIDs
- Create manual integration test script
- Full AwesomeWM integration testing

## Technical Details

### Communication Protocol
- **Format**: JSON payloads over awesome-client
- **Signals**: `diligent::<command>` pattern
- **Response**: JSON response via `diligent::response` signal
- **Timeout**: 5 second timeout for responses

### Error Handling
- Graceful degradation when AwesomeWM unavailable
- Clear error messages for users
- Proper cleanup on failures
- Logging for debugging

### Testing Strategy
- **Unit tests**: Mock AwesomeWM APIs for CI
- **Integration tests**: Manual testing with real AwesomeWM
- **Error scenarios**: Test all failure modes
- **Edge cases**: Network timeouts, malformed responses

This proves the fundamental feasibility of Diligent's core architecture before moving to Phase 1 DSL implementation.