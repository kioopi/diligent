# Diligent — Architecture Overview (v 2.0)

*Last updated: 4 Aug 2025*

---

## 1 High‑Level View

```
+-------------+        D-Bus Protocol           +------------------+
|   workon    | ——— Direct D-Bus calls ———▶   |   AwesomeWM      |
|   (CLI)     | ◀—— Typed responses ————┘       |   + diligent     |
+-------------+                                 +--------┬---------+
       │                                              │
       │ lua/dbus_communication.lua                  │ 
       │                                              │
       ▼                                              ▼
+------------------+                          +------------------+
|   DSL System     |                          |   awe Module     |
|                  |                          |                  |
| • parser.lua      |                          | • 15+ modules      |
| • validator.lua   |                          | • Factory pattern  |
| • helpers/app.lua |                          | • DI architecture  |
| • tag_spec.lua    |                          | • client/spawn/... |
+--------┬---------+                          +--------┬---------+
         │                                           │
         │ DSL integration needed                    │
         │                                           │
         ▼                                           ▼
+----------------------------------------------------------+
|                   Future Integration                    |
|  DSL → Resource Specs → awe.spawn → AwesomeWM      |
+----------------------------------------------------------+
```

* modular architecture with D-Bus communication and comprehensive AwesomeWM integration.*

---

## 2 Components

### 2.1 CLI — `workon`

* **Language:** Lua script with modular command architecture
* **Current Commands:** `ping`, `validate` (not `start`, `stop` yet)
* **Architecture:** Uses lua_cliargs with separate command modules in `cli/commands/`
* **Main tasks**
  * Parse arguments using structured command system
  * Direct D-Bus communication via `lua/dbus_communication.lua`
  * Execute Lua code in AwesomeWM with typed responses
  * Validate DSL files using comprehensive `lua/dsl/` system
* **Communication:** Direct D-Bus calls to `org.awesomewm.awful.Remote.Eval`

### 2.2 D-Bus Communication Layer — `dbus_communication.lua`

* ** Enhancement:** Replaces shell-based `awesome-client` with direct D-Bus
* **Responsibilities**
  1. *Direct D-Bus calls*: Via LGI (Lua GObject Introspection)
  2. *Type handling*: Automatic type detection and conversion
  3. *Error handling*: Graceful timeout and connection management
  4. *Compatibility*: Same interface as old shell approach but more reliable
* **Benefits:** Eliminates shell escaping, provides typed responses, better error handling

### 2.3 AwesomeWM Module — `diligent.lua`

* **Current Role:** Signal coordination and handler registration (no longer monolithic)
* **Responsibilities**
  1. *Signal bus*: Registers handlers for diligent signals
  2. *Handler coordination*: Delegates to specialized handler modules
  3. *Validation*: Uses lua-LIVR for input validation
  4. *Response formatting*: Standardized success/error responses
* **Architecture:** Modular with separate handler files, not monolithic

### 2.4 awe Module —  AwesomeWM Integration

* **Architecture:** 15+ focused modules with instance-based dependency injection
* **Factory Pattern:** `awe.create(interface)` enables clean testing and dry-run support
* **Module Organization:**
  * `awe/client/` - Client management (tracker, properties, info, wait)
  * `awe/spawn/` - Application spawning (spawner, configuration, environment)
  * `awe/error/` - Error handling (classifier, reporter, formatter)
  * `awe/tag/` - Tag resolution wrapper
  * `awe/interfaces/` - Interface abstractions (awesome, dry-run, mock)

#### Key Features:
* **Instance-based DI:** Eliminates hacky test patterns
* **Interface abstraction:** Multiple interface types (awesome, mock, dry-run)
* **Production validation:** 15 working example scripts
* **Comprehensive testing:** 643 tests with factory pattern
* **Clean APIs:** Consistent function signatures and return patterns

### 2.5 DSL System — Complete Modular Architecture

* **Location:** `lua/dsl/` with full modular breakdown
* **Components:**
  * `dsl/parser.lua` - File loading, compilation, sandbox
  * `dsl/validator.lua` - Schema validation with detailed errors
  * `dsl/tag_spec.lua` - Tag specification parsing
  * `dsl/helpers/` - Helper registry and implementations
* **Current State:** `app` helper fully implemented, infrastructure ready for more
* **Integration:** Ready to connect to awe spawning backend

### 2.6 Tag Mapper — Enhanced with Interface Integration

* **Location:** `lua/tag_mapper/` with clean modular architecture
* **Interface Integration:** Uses awe interfaces for AwesomeWM interaction
* **Capabilities:** All tag types (relative, absolute, named) with comprehensive testing
* **Architecture:** Pure logic core + interface abstraction + integration layer

---

## 3 Key Design Decisions

### DD‑1 Direct D-Bus over awesome-client (Updated)

* **Change:** Replaced shell-based `awesome-client` with direct D-Bus calls
* **Pros:** Eliminates shell escaping, typed responses, better error handling, more reliable
* **Implementation:** LGI (Lua GObject Introspection) for direct D-Bus communication
* **Result:** More robust and faster communication layer

### DD‑2 Modular Architecture with Dependency Injection (New)

* **Decision:**  modular architecture with factory pattern and DI
* **Benefits:** Clean testing, multiple interface support, extensible design
* **Implementation:** 15+ focused modules with `awe.create(interface)` pattern
* **Impact:** Exemplary architecture that exceeds original scope

### DD‑3 DSL System Modularity (New)

* **Decision:** Separate DSL system with parser, validator, helpers
* **Benefits:** Extensible helper system, comprehensive validation, clean separation
* **Current State:** Complete infrastructure with `app` helper, ready for expansion

### DD‑4 Interface Abstraction for Testing (New)

* **Decision:** Multiple interface types (awesome, mock, dry-run)
* **Benefits:** Clean testing without mocking hacks, dry-run capabilities
* **Implementation:** Interface layer in `awe/interfaces/` with consistent APIs

### DD‑5 Environment variable for client binding (Unchanged)

* Works on both X11 and Wayland, no XCB dependencies needed

### DD‑6 Tag overflow strategy (Enhanced)

* Same logic but now implemented through modular tag_mapper with interface support

---

## 4 Current Implementation Status

### ✅ **COMPLETED - Production Ready**
- **D-Bus Communication:** Full replacement of awesome-client
- **awe Module Architecture:** 15+ modules with 643 tests
- **DSL Infrastructure:** Complete with `app` helper and validation
- **Tag Mapper:** Enhanced with interface integration
- **CLI Commands:** `ping` and `validate` working

### 🚧 **IN PROGRESS - Integration Needed**
- **DSL-to-spawning integration:** Connect DSL `app{}` helper to awe.spawn backend
- **In-memory state management:** Not yet implemented
- **Complete CLI:** `start`, `stop`, `status`, `resume` commands pending

### ⏳ **FUTURE PHASES**
- Additional DSL helpers (`term`, `browser`, `obsidian`)
- Complete state persistence system
- Full project lifecycle management

---

## 5 Interfaces Summary

1. **CLI ↔ AwesomeWM D-Bus**
   *Protocol:* `org.awesomewm.awful.Remote.Eval`
   *Transport:* Direct D-Bus method calls with typed responses
   *Benefits:* Reliable, fast, typed communication

2. **awe Module API** ( Enhancement)
   *Pattern:* `awe.create(interface)` for dependency injection
   *Modules:* client, spawn, error, tag with consistent APIs
   *Testing:* Clean factory pattern enables comprehensive testing

3. **DSL System API**
   *Entry:* `dsl.load_and_validate(filepath)`
   *Validation:* Schema-driven with detailed error context
   *Helpers:* Extensible registry system

---

## 6 External Libraries

* **luafilesystem** – path ops & permissions
* **dkjson** – JSON encode/decode
* **lgi** – D-Bus communication (replaces shell awesome-client)
* **lua_cliargs** – CLI argument parsing
* **penlight** – Lua utilities
* **lua-livr** – Input validation

---

## 7 Testing Strategy

1. **Unit tests** — 643 comprehensive tests using Busted
2. **Factory pattern testing** — Clean DI eliminates test complexity
3. **Interface mocking** — Multiple interface types for different test scenarios
4. **Integration testing** — Real AwesomeWM integration via D-Bus
5. **Production validation** — 15 working example scripts

---

## 8 Architecture Evolution

### From Original Design:
- Shell-based awesome-client communication
- Monolithic diligent.lua module
- Basic DSL interpreter
- Simple component structure

### To Current Reality:
- Direct D-Bus communication layer
-  modular architecture with 15+ modules
- Comprehensive DSL system with validation
- Factory pattern with dependency injection
- Production-validated spawning system

**Key Insight:** The architecture has evolved far beyond the original design, creating a much stronger foundation for rapid feature development.

---

### End of Document