# Diligent — Detailed Feature Requirements (v 1.0)

*Last updated: 29 Jul 2025*

> \*\*This document breaks down every must‑have capability for Diligent v 1.0, explains the rationale, and sprinkles in technology notes and implementation hints gathered from our discussion.\_
> It is the single source of truth when writing tickets / tasks.\_

---

## 1 Glossary

| Term             | Meaning                                                                                           |
| ---------------- | ------------------------------------------------------------------------------------------------- |
| **Project**      | A logical set of resources (windows, files, URLs) described by one DSL file.                      |
| **Resource**     | A single application instance or window (e.g. Zed editor, terminal, browser).                     |
| **Project tag**  | The extra AwesomeWM tag created with the same name as the project.                                |
| **Resolved tag** | The final numeric or named tag on which a resource is placed (after relative‑to‑base conversion). |
| **DSL**          | The Lua description file under `~/.config/diligent/projects/<name>.lua`.                          |

---

## 2 Functional Requirements

### FR‑1 Project Lifecycle

| ID         | Requirement                                                                                                                        | Notes & Technology Hints                                                      |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| **FR‑1.1** | The CLI SHALL support the sub‑commands: `start`, `stop`, `status`, `resume`.                                                       | Use Lua’s `arg` parsing (`arg[1]`) and a simple dispatch table.               |
| **FR‑1.2** | `start` SHALL load the project’s DSL file, signal Awesome, and exit non‑zero on fatal errors (e.g. file not found, malformed DSL). | Schema validation: check for `resources` table first, fall back to `error()`. |
| **FR‑1.3** | `stop` SHALL gracefully terminate the project according to FR‑3 (Graceful Shutdown).                                               |                                                                               |
| **FR‑1.4** | `status` SHALL print human‑readable info: *Running*, *Stopped*, or *Partially running* plus counts of active resources.            | Parse `state.json`; pretty print with `dkjson` + ANSI colors.                 |
| **FR‑1.5** | `resume` SHALL reattach existing windows in `state.json` that are not yet bound (e.g. after Awesome restart).                      |                                                                               |

### FR‑2 Tag Mapping & Collision Handling

| ID         | Requirement                                                                                                                                                    | Notes & Technology Hints                                      |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| **FR‑2.1** | When `start` is issued, the **base tag** SHALL be the currently selected tag (`awful.screen.focused().selected_tag.index`).                                    |                                                               |
| **FR‑2.2** | Numeric tag values in the DSL SHALL be interpreted as *relative* offsets from the base tag.                                                                    | Offset 0 = current tag. Negative offsets not supported in v1. |
| **FR‑2.3** | String tags consisting solely of digits (`"3"`) SHALL be treated as absolute numeric tags.                                                                     |                                                               |
| **FR‑2.4** | String tags containing non‑digit characters (`"editor"`) SHALL refer to named tags; if the tag does not exist, Diligent SHALL create it on the current screen. | Use `awful.tag.add("editor", {screen = s})`.                  |
| **FR‑2.5** | If the resolved numeric tag exceeds `9`, Diligent SHALL place the resource on **tag 9**, add the project tag, and issue a `naughty.notify` warning.            |                                                               |

### FR‑3 Graceful Shutdown & Hooks

| ID         | Requirement                                                                                                                                                                                                                                  | Notes & Technology Hints                                              |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| **FR‑3.1** | The DSL MAY include `hooks.start` (string) and `hooks.stop` (string).                                                                                                                                                                        |                                                                       |
| **FR‑3.2** | `hooks.start` SHALL execute **before** resource spawning; `hooks.stop` **before** sending signals.                                                                                                                                           | Use `awful.spawn.with_shell` for async execution.                     |
| **FR‑3.3** | For each tracked client belonging to the project, Diligent SHALL attempt graceful termination by: 1) sending `SIGINT` if resource type == `terminal & interactive`; else `SIGTERM`. 2) waiting **3 s**; 3) sending `SIGKILL` if still alive. | Use `posix.kill` (from `lsignal`) if PID known; else `client:kill()`. |

### FR‑4 Resource Management

| ID         | Requirement                                                                                                                                                     | Notes & Technology Hints                                |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| **FR‑4.1** | The DSL SHALL support at minimum resource helpers: `app`, `term`, `browser`, `obsidian`.                                                                        |                                                         |
| **FR‑4.2** | Each helper SHALL accept `tag`, `dir`, and `reuse` keys.                                                                                                        |                                                         |
| **FR‑4.3** | If `reuse = true`, Diligent SHALL search existing clients by window class/role defined per helper before spawning a new one.                                    | Example: for `obsidian`, match `c.class == "obsidian"`. |
| **FR‑4.4** | Spawned commands SHALL inherit the environment variable `DILIGENT_PROJECT=<name>` to enable client tracking.                                                    |                                                         |
| **FR‑4.5** | Upon `client::manage`, if a client’s `pid` environment contains `DILIGENT_PROJECT`, Diligent SHALL tag the window with the project tag and update `state.json`. |                                                         |

### FR‑5 Persistence & Resume

| ID         | Requirement                                                                                                                                            | Notes & Technology Hints |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------ |
| **FR‑5.1** | Diligent SHALL maintain `~/.cache/diligent/state.json` containing: project name, layout name (if any), resolved tag per resource, window IDs, PIDs.    |                          |
| **FR‑5.2** | The file SHALL be updated atomically (write temp file, `os.rename`).                                                                                   |                          |
| **FR‑5.3** | On Awesome startup, the module SHALL parse `state.json` and reattach still‑alive windows; missing ones are spawned if the project is marked *running*. |                          |

### FR‑6 Error Handling & Reporting

| ID         | Requirement                                                                                                                     | Notes & Technology Hints |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| **FR‑6.1** | Resource spawn failures SHALL be collected; `workon start` exits **0** if at least one resource succeeded, **1** if all failed. |                          |
| **FR‑6.2** | The CLI SHALL print a summary table: ✔ success, ✖ failed, ⚠ reused.                                                             |                          |
| **FR‑6.3** | The Awesome module SHALL emit `diligent::report` signal containing the result table which the CLI reads (timeout = 5 s).        |                          |

### FR‑7 CLI & IPC

| ID         | Requirement                                                                                                          | Notes & Technology Hints |
| ---------- | -------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| **FR‑7.1** | The CLI SHALL communicate with Awesome exclusively via `awesome-client` executing Lua expressions that emit signals. |                          |
| **FR‑7.2** | All payloads SHALL be JSON‑encoded strings to avoid Lua expression escaping issues.                                  | Use `dkjson.encode`.     |
| **FR‑7.3** | Path to `awesome-client` SHALL be autodetected via `$PATH`; fallback error prompts to install `awesome`.             |                          |

### FR‑8 Dependencies & Packaging

| ID         | Requirement                                                                                                                               | Notes & Technology Hints |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| **FR‑8.1** | The project SHALL build/install via **LuaRocks** (`luarocks make`).                                                                       |                          |
| **FR‑8.2** | The rockspec SHALL declare external deps: `luafilesystem`, `dkjson`, `lsignal` with minimum versions tested.                              |                          |
| **FR‑8.3** | The project README SHALL document Arch Linux install path: `pacman -S luarocks awesome`, then `luarocks install diligent-scm-0.rockspec`. |                          |

---

## 3 Non‑Functional Requirements

| ID        | Requirement                                                                                                                      | Notes |
| --------- | -------------------------------------------------------------------------------------------------------------------------------- | ----- |
| **NFR‑1** | **Startup latency** for `workon start` SHOULD be ≤ 1 s before resource commands begin launching (excluding the apps themselves). |       |
| **NFR‑2** | **Memory footprint** of the Awesome module SHOULD add ≤ 5 MiB RSS.                                                               |       |
| **NFR‑3** | **Code coverage** via busted tests SHALL be ≥ 80 % for core Lua modules.                                                         |       |
| **NFR‑4** | **Documentation**: Every public Lua function SHALL contain LuaDoc comments.                                                      |       |
| **NFR‑5** | **Logging**: A debug flag (`workon --debug`) SHOULD print verbose info to `stderr` and write `~/.cache/diligent/debug.log`.      |       |

---

## 4 Out‑of‑Scope (v 1.0)

* Multi‑monitor placement
* Advanced tiling layouts (gaps, columns)
* Automatic background service management
* Wayland‑native window tracking

These items are captured in the **Open Topics** section of the design doc for v 1.1+ planning.

---

## 5 Development Hints Cheat‑Sheet

* **Signals vs DBus**: Awesome already exposes `awesome.emit_signal`; avoid DBus to keep deps minimal.
* **PID‑to‑env lookup**: `/proc/<pid>/environ` read via `io.open`; watch for `\0` separators.
* **Atomic writes**: `tmpfile = path..".tmp"; write; fsync; os.rename(tmpfile, path)`.
* **Tag lookup utility**: cache `tags_by_name[s][name]` per screen for O(1) re‑use.
* **Unit test strategy**: use `xvfb-run awesome -c test_rc.lua` to simulate clients; stub out `awful.spawn`.
