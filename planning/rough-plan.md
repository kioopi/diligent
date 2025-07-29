# Diligent — Design & Requirements Document

*Last updated: 29 Jul 2025*

---

## 1 Purpose

Provide a **declarative, per‑project workspace manager** for AwesomeWM. A user describes the windows, files, and URLs a project needs via a simple Lua DSL; then starts/stops that workspace with one shell command (`workon`).

---

## 2 Feature Requirements (v1)

| #    | Requirement                      | Decision                                                                                                                                                          |
| ---- | -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2.1  | **Multiple concurrent projects** | Supported. Each project gets an extra tag named after the project and may place resources on numeric or named tags.                                               |
| 2.2  | **Tag mapping**                  | *Relative* numeric tags are offsets from the tag active when `workon start` is invoked. *Absolute* tags are either numeric strings ("3") or tag names ("editor"). |
| 2.3  | **Collision handling**           | If a resolved numeric tag exceeds `9`, resources fall back to **tag 9** and a notification is shown. No modulo wrapping.                                          |
| 2.4  | **Single‑screen focus**          | All resources and the project tag are created on the current screen only. Multi‑screen placement is deferred to a future release.                                 |
| 2.5  | **Reuse vs new window**          | Per‑resource `reuse` flag in DSL.                                                                                                                                 |
| 2.6  | **Lifecycle hooks**              | Optional `hooks.start` / `hooks.stop` shell snippets.                                                                                                             |
| 2.7  | **Graceful shutdown**            | Send `SIGTERM` (or `SIGINT` for interactive terminals); force‑kill after timeout. Run `hooks.stop` first.                                                         |
| 2.8  | **Persistence**                  | JSON state file under `~/.cache/diligent/state.json` remembers running projects & window IDs.                                                                     |
| 2.9  | **Error handling**               | Continue launching remaining resources; CLI prints a summary of failures.                                                                                         |
| 2.10 | **CLI layout**                   | `workon <cmd> <project>` where `<cmd>` ∈ {`start`, `stop`, `status`, `resume`}.                                                                                   |
| 2.11 | **Dependencies**                 | Use **LuaRocks** to install third‑party libs (`luafilesystem`, `dkjson`, `lsignal`), vendoring if needed.                                                         |

---

## 3 Architecture Overview

### 3.1 Components

1. **CLI (`workon`)**

   * Lua script available on `$PATH`.
   * Parses sub‑commands, loads project file, and communicates with Awesome via `awesome-client` (signals `diligent::start`, `diligent::stop`, etc.).
2. **Awesome Module (`diligent.lua`)**

   * Loaded in `rc.lua`.
   * Handles signals, spawns resources, applies tag mapping, tracks clients.
   * Saves/loads persistent state.
3. **Resource Spawner**

   * Helpers: `app`, `term`, `browser`, `obsidian`, …
   * Applies `reuse` logic; sets `DILIGENT_PROJECT` env var for tracking.
4. **Client Tracker**

   * On `client::manage`, inspects the new client’s PID → env → project.
   * Stores `c:set_property("diligent_project", name)` for restart resilience.
5. **Notification Subsystem**

   * Uses `naughty.notify` to warn about tag overflow (placing on tag 9) and startup errors.

### 3.2 Data Flow (start sequence)

```
workon start myproj
   └── awesome-client → emit_signal('diligent::start', '/…/myproj.lua')
         └── diligent.lua
               ├─ load DSL
               ├─ capture base_tag
               ├─ resolve tags (fallback to 9 if >9)
               ├─ create project tag on current screen
               ├─ spawn resources
               └─ respond with result table (success/errors) → CLI prints
```

---

## 4 DSL Skeleton (reference)

```lua
return {
  name = "myproj",

  resources = {
    zed = app { tag = 0 },          -- relative (current tag)
    term_shell = term { tag = 1 },  -- relative +1
    browser = browser { tag = "3" },
    logs = term { tag = "logs" },   -- named tag (absolute)
  },

  layouts = {
    office = {
      zed = 0, term_shell = 1, browser = "3", logs = "logs",
    },
  },

  hooks = {
    start = "systemctl --user start myproj-dev",
    stop  = "systemctl --user stop  myproj-dev",
  },
}
```

---

## 5 External Libraries via LuaRocks

| Library                 | Purpose                                              |
| ----------------------- | ---------------------------------------------------- |
| **luafilesystem (lfs)** | Path resolution, directory traversal                 |
| **dkjson**              | JSON encode/decode for state file and CLI‑module IPC |
| **lsignal / luaposix**  | Sending signals for graceful shutdown                |

*Project will include a `diligent-scm-0.rockspec` for easy install.*

---

## 6 Implementation Roadmap (Milestones)

1. **Repo scaffolding & CI**
2. **CLI MVP** (`start`, signal send, result print)
3. **Awesome module skeleton** (signal handlers, tag mapping, notifications)
4. **Resource spawner & tracker**
5. **Persistence**
6. **Graceful shutdown & hooks**
7. **Unit tests (busted + xvfb)**
8. **Docs & examples**

---

## 7 Open Topics for Later Releases

* Multi‑screen placement rules.
* Layout presets with gap/column settings.
* Per‑project keybindings.
* Wayland‑native tracking once Awesome v5 lands.

---

### End of Document

