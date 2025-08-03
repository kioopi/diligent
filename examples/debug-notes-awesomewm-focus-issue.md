# AwesomeWM Focus Issue Debug Notes

**Date**: August 2, 2025, 17:26  
**Issue**: AwesomeWM focus completely broken - only terminal has focus, no keybindings work, but mouse interactions still work

## Trigger Event
Issue occurred during Section 4 client spawning validation tests, specifically after:
1. Testing `awesome_client_manager` module loading
2. Attempting spawn failure detection test with `nonexistentapp123`
3. Testing successful spawn with `xterm` followed by `client:kill()` operation
4. D-Bus timeout during module reloading attempt

## Critical Findings

### Phase 1: System State Analysis ✅
- **AwesomeWM Process**: Running normally (PID 1471, 0.2% CPU)
- **X Session Errors**: 
  - ⚠️ `awesome: a_glib_poll:477: Last main loop iteration took 0.107471 seconds!` 
  - ⚠️ `xterm: cannot load font "-misc-fixed-medium-r-semicondensed--13-120-75-75-c-60-iso10646-1"`
- **System Resources**: Normal (load avg 1.17, no high CPU/memory processes)
- **Zombie Processes**: None found
- **Remaining Test Processes**: 1 xterm (PID 13461) still running

### Phase 2: AwesomeWM Internal State Diagnosis ❌
- **D-Bus Service**: **COMPLETELY NON-RESPONSIVE**
- **Connection Test**: `dbus_comm.check_awesome_available()` returns `false`
- **D-Bus Constants**: All nil (BUS_NAME, OBJECT_PATH, INTERFACE)
- **Manual D-Bus Query**: `Error org.freedesktop.DBus.Error.NoReply`

## Root Cause Analysis

**Primary Issue**: AwesomeWM's D-Bus service interface has crashed or become unresponsive

**Probable Trigger**: The `client:kill()` operation within our test combined with module reloading attempt:
```lua
-- This sequence likely caused the crash:
client:kill()  -- Force-killed a spawned client
package.loaded["awesome_client_manager"] = nil  -- Attempted module reload
require("awesome_client_manager")  -- Reload during unstable state
```

**Evidence**:
1. Main loop slowdown warning (0.107471s) indicates AwesomeWM was struggling
2. D-Bus timeouts during our testing suggest progressive deterioration
3. Complete D-Bus service failure correlates with testing timeline
4. AwesomeWM process still running but D-Bus interface dead

## Impact Assessment

**Broken**:
- All D-Bus communication with AwesomeWM
- Keyboard focus management 
- AwesomeWM keybindings
- Programmatic client management
- Our client spawning exploration scripts

**Still Working**:
- Mouse interactions (clicking tags, scrolling)
- Basic window manager functionality
- X11 display system
- This terminal session

## Recovery Options

1. **Restart AwesomeWM**: `awesome-client 'awesome.restart()'` (may not work due to D-Bus failure)
2. **Kill and restart AwesomeWM process**: `kill 1471 && exec awesome`
3. **Full X session restart**: Most reliable but loses all window state

## Prevention Strategies

1. **Never use `client:kill()` in D-Bus testing context**
2. **Avoid module reloading during client operations**
3. **Use shorter D-Bus timeouts to detect issues early**
4. **Implement AwesomeWM health checks before each test**
5. **Create safer test applications that auto-exit**

## Next Steps

**Immediate**: Restart AwesomeWM to restore functionality
**Long-term**: Implement robust testing patterns that avoid D-Bus service crashes

---

**Testing Sequence That Triggered Issue**:
```lua
-- 1. Basic module test (OK)
local acm = require("awesome_client_manager")

-- 2. Spawn failure test (OK) 
acm.spawn_simple("nonexistentapp123", "0")

-- 3. Successful spawn with kill (TRIGGER)
local pid = acm.spawn_simple("xterm", "0")
local client = acm.find_by_pid(pid)
client:kill()  -- ⚠️ DANGER: Force kill in D-Bus context

-- 4. Module reload attempt (FATAL)
package.loaded["awesome_client_manager"] = nil
require("awesome_client_manager")  -- ⚠️ System already unstable
```

**Lesson**: D-Bus-based client management requires extreme care with client lifecycle operations.