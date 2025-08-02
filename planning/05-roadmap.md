# Diligent — Development Roadmap

*Last updated: 2 Aug 2025*

> *This roadmap describes incremental, user‑visible milestones.  Every step carries clear acceptance criteria so we can gate merges and track progress.*

---

## Phase 0 — Project Scaffold & Continuous Integration  *(Week 0–1)* ✅ **COMPLETED**

1. **Repo bootstrap** ✅

   * Create `diligent/` mono‑repo with `cli/`, `lua/`, `spec/`, `docs/` directories.
   * Initialise MIT licence, `README.md`, `.editorconfig`, and LuaRocks rockspec stub.

2. **Automated CI** ✅

   * GitHub Actions: Arch Linux container, installs `awesome`, `luarocks`, runs tests.
   * Matrix for Lua 5.3 and 5.4.
   * Fails build if code coverage < 60 %.

3. **Code style** ✅

   * Add `selene.toml` (luacheck alternative) + `stylua.toml`; enforce via CI.

*Exit criteria* ✅ — Repo clones, `luarocks make` yields stub module, CI passes.

---

## Phase 1 — Minimal Viable Prototype (MVP)  *(Week 1–2)* 🚧 **IN PROGRESS**

### Goal

A user can write a **single‑resource DSL file**, run `workon start sample`, and watch that app open on the current tag plus a project tag. No persistence yet.

### Steps

1. **Signal plumbing & Modular Architecture** ✅ **COMPLETED**

   * ✅ Implement CLI `ping` command with D-Bus communication (enhanced beyond original awesome-client approach)
   * ✅ Inside `diligent.lua`, register `diligent::ping` handler with JSON response
   * ✅ **Major Refactoring**: Modular architecture with lua-LIVR validation
     - Extracted utils.lua for payload parsing, validation, and response formatting
     - Created separate handler modules (ping, spawn_test, kill_test)
     - Implemented centralized handler registration system
     - Added robust input validation with detailed error messages
     - Enhanced API with async (`emit_command`) and sync (`dispatch_command`) operations
   * 🚧 Need to implement `start` command and `diligent::start` handler

2. **Tag mapper (comprehensive)** ✅ **COMPLETED** 

   * ✅ **Major Refactoring**: Implemented clean, modular tag mapper architecture
     - Pure core logic with zero external dependencies (`tag_mapper/core.lua`)
     - Interface abstraction layer (`tag_mapper/interfaces/`)
     - Integration coordination layer (`tag_mapper/integration.lua`)
     - Comprehensive dry-run capabilities for CLI preview
   * ✅ Support for all tag types: relative numeric, absolute strings, named tags
   * ✅ Overflow handling with user notifications (cap at tag 9)
   * ✅ Backward-compatible API with enhanced internal architecture
   * ✅ 29 new tests added, bringing total to 447 tests

3. **`app{}` helper + spawner** ⏳ **PENDING**

   * Only keys: `cmd`, `tag` (0), `dir`. No `reuse` logic yet.
   * Tag mapper integration ready - can now leverage modular interface

4. **In‑memory state (volatile)** ⏳ **PENDING**

   * `projects` table holds `{name, clients}` for runtime only.

5. **Manual test case** ⏳ **PENDING**

   * DSL sample opens `gedit`. Ensure tag names & placement correct.
   * Can now use dry-run interface for testing before real execution

*Exit criteria* — Manual test passes; user feedback accepted.

**Current Status**: 
- ✅ Robust D-Bus communication with dual-layer architecture (direct execution + signal-based commands)
- ✅ Modular, testable architecture with lua-LIVR validation
- ✅ Handler registration system supporting both async and sync operations
- ✅ **MAJOR MILESTONE**: Complete tag mapper refactoring with clean architecture
  - Pure logic layer for easy testing and extension
  - Interface abstraction enabling dry-run and multi-interface support
  - Comprehensive test coverage (447 total tests)
  - Production-ready modular design
- 🚧 Ready for DSL parsing and app spawning implementation with tag mapper integration

---

## Phase 2 — Resource Helper Expansion  *(Week 2–3)*

### Goal

Support all four helper types (`app`, `term`, `browser`, `obsidian`) and the `reuse` flag.

#### Steps

1. **Terminal helper**

   * Spawn via `alacritty -e <cmd>`; detect interactive vs cmd.
2. **Browser helper**

   * Open URLs with `xdg-open`.
   * For `window="new"` launch `firefox --new-window`; for `reuse` open tabs.
3. **Obsidian helper**

   * Match window class `obsidian`, `reuse=true` attaches.
4. **`reuse` implementation**

   * Scan `client.get()` for class/role before spawn.
5. **Tag mapper integration** ✅ **COMPLETED**

   * ✅ Full tag specification already implemented in Phase 1
   * ✅ Ready for integration with resource helpers
   * ✅ Dry-run capabilities available for safe testing

*Exit criteria* — DSL example with 3 resources launches & places correctly; CI tests include class matching mocks. Tag mapper ready for integration.

---

## Phase 3 — Persistence & Resume  *(Week 3–4)*

### Goal

Windows survive WM restart; `workon resume` re‑binds or re‑spawns clients.

#### Steps

1. **State Manager** (write/parse JSON)**

   * Atomic write helper, debounce 500 ms.
2. **Environment variable tracking**

   * Inject `DILIGENT_PROJECT`;  parse `/proc/<pid>/environ` in `client::manage`.
3. **Startup hook**

   * On module load, re‑hydrate state; verify each `winid` exists.
4. **`resume` CLI**

   * Walk projects in `state.json`, call Awesome signal to re‑attach missing.

*Exit criteria* — Restart Awesome, run `workon resume`, original windows re‑tagged; automated integration test under Xvfb.

---

## Phase 4 — Graceful Shutdown & Hooks  *(Week 4–5)*

### Goal

`workon stop` terminates projects cleanly; pre‑/post‑hooks run.

#### Steps

1. **Hooks execution**

   * Run `hooks.stop` before signals; capture exit codes.
2. **Signal cascade**

   * Determine PID set; send `SIGINT`/`SIGTERM`; 3‑second timer; `SIGKILL` fallback.
3. **CLI summary**

   * Print per‑resource status icons ✅/⚠️/❌.
4. **Unit tests**

   * Mock `lsignal.kill`; ensure correct sequence.

*Exit criteria* — `workon stop` leaves no orphans; CI asserts log output.

---

## Phase 5 — Layouts & CLI Flags  *(Week 5–6)*

### Goal

Users can define multiple layouts and select one at start time.

#### Steps

1. **DSL parser update** — recognise `layouts` table.
2. **CLI flag `--layout`**

   * Validate against DSL; default to first entry or per‑resource tags.
3. **Tag mapping uses layout table**.
4. **Integration tests**

   * Verify `office` vs `laptop` produce different tag sets.

*Exit criteria* — Example project switches layouts correctly; docs updated.

---

## Phase 6 — Packaging & Release  *(Week 6)*

1. **LuaRocks rockspec finalised** — versions & checksums.
2. **Arch PKGBUILD**

   * For AUR submission (`diligent-git`).
3. **Version 1.0.0 tag**

   * SemVer; changelog generated.

*Exit criteria* — `pacman -U diligent-git.pkg.tar.zst` installs and runs MVP.

---

## Phase 7 — Quality & DX Polishing  *(Ongoing)*

* Increase test coverage to ≥ 80 %.
* Add `--debug` trace flag + log rotation.
* Provide VSCode snippet for DSL boilerplate.

---

## Phase 8 — User Feedback Loop  *(Post‑1.0)*

* Collect issues, prioritise features: multi‑monitor, advanced layouts.
* Monthly patch releases.

---

## Technical Notes

### D-Bus Communication Implementation

**Enhancement over original plan**: Instead of using shell-based `awesome-client`, implemented direct D-Bus communication via LGI (Lua GObject Introspection). This provides:

- More reliable communication (no shell escaping issues)
- Better error handling and timeouts
- Bidirectional communication with typed responses
- Performance improvements

**Files implemented**:
- `lua/dbus_communication.lua` - Direct D-Bus interface to AwesomeWM
- `lua/diligent.lua` - AwesomeWM-side signal handlers
- `cli/workon` - CLI tool with `ping` command working

---

## Milestone Burn‑Down (tentative)

```
Weeks →   1  2  3  4  5  6
Phase 0  ✅✅  (completed)
Phase 1     🚧⏳  (in progress)
Phase 2       ⏳⏳
Phase 3          ⏳⏳
Phase 4             ⏳⏳
Phase 5               ⏳⏳
Phase 6                 ⏳
```

*Chart updated based on current progress. Phase 0 completed ahead of schedule.*

---

### Development Status Summary

- ✅ **Phase 0**: Complete project scaffold, CI/CD, code quality tools
- 🚧 **Phase 1**: 
  - ✅ D-Bus communication layer with dual architecture
  - ✅ Modular handler system with lua-LIVR validation  
  - ✅ Handler registration and response formatting
  - ✅ **MAJOR MILESTONE**: Complete tag mapper refactoring
    - Clean, modular architecture with interface abstraction
    - Pure logic functions with comprehensive testing (447 total tests)
    - Dry-run capabilities for safe preview and testing
    - Production-ready foundation for resource helpers
  - 🚧 DSL parsing and app spawning (next priority)
- ⏳ **Phase 2+**: Tag mapper integration ready, awaiting Phase 1 completion

**Recent Achievement**: Tag mapper transformed from monolithic implementation to exemplary clean architecture that serves as a model for the entire project.

**Next Priority**: Implement `start` command with basic DSL parsing and app spawning, leveraging the new tag mapper architecture.

### End of Document
