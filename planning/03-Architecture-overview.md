# Diligent — Architecture Overview (v 1.0)

*Last updated: 29 Jul 2025*

---

## 1 High‑Level View

```
+-------------+         awesome-client          +-----------------+
|   workon    | ─── emit Lua signal JSON ───▶  |  diligent.lua   |
|   (CLI)     | ◀── result JSON table ────┘    |  (Awesome mod)  |
+-------------+                                 +--------┬--------+
                                                        │
                                                        │ resource spawn
                                                        ▼
                                              +--------------------+
                                              |  Resource Spawner  |
                                              +--------┬-----------+
                                                        │
                                                        │ client::manage hook
                                                        ▼
                                              +--------------------+
                                              |  Client Tracker    |
                                              +--------┬-----------+
                                                        │ state update
                                                        ▼
                                              +--------------------+
                                              |  State Manager     |
                                              +--------------------+
```

*All components *right* of the arrow live inside AwesomeWM; `workon` is an external CLI.*

---

## 2 Components

### 2.1 CLI — `workon`

* **Language:** Lua script installed on `$PATH`.
* **Sub‑commands:** `start`, `stop`, `status`, `resume`, `--debug`.
* **Main tasks**

  * Parse arguments, load DSL file into Lua table (for quick validation).
  * Encode payload as JSON and send it to Awesome using `awesome-client`:

    ```bash
    awesome-client "awesome.emit_signal('diligent::start', '<json>')"
    ```
  * Listen (blocking, ≤5 s) for `diligent::report` and pretty‑print results.
* **Why outside Awesome?** Keeps WM rc.lua lean; easy shell integration.

### 2.2 Awesome Module — `diligent.lua`

* **Loaded** once in `rc.lua` (`require'diligent'`).
* **Responsibilities**

  1. *Signal bus*: Listens for `diligent::*` signals from CLI.
  2. *DSL Interpreter*: Loads project file, evaluates helpers to produce resource spec.
  3. *Tag Mapper*: Applies relative/absolute rules, creates project tag.
  4. *Resource Spawner*: Delegates each spec to helper functions.
  5. *Client Tracker*: Hooks `client::manage` / `client::unmanage` to maintain state.
  6. *State Manager*: Persists JSON under `~/.cache/diligent/state.json` (atomic writes).
  7. *Reporter*: Emits `diligent::report` when operations finish (success/error list).

### 2.3 DSL Helpers (API)

* **`app{cmd, dir, tag, reuse}`** – generic X11 app (class‑match on `reuse`).
* **`term{cmd, dir, tag, reuse}`** – terminal via `alacritty -e` (interactive flag).
* **`browser{urls, window, tag, reuse}`** – open new or existing browser window.
* **`obsidian{path, tag, reuse}`** – reuse class `obsidian` if possible.
* Each helper returns a **resource table** consumed by the spawner.

### 2.4 Resource Spawner

* Chooses spawn command based on helper type.
* Sets env `DILIGENT_PROJECT` before `awful.spawn.with_shell`.
* Tags client once it appears (`client::manage`).

### 2.5 Client Tracker

* On `client::manage`:

  * Reads `/proc/$pid/environ` to extract `DILIGENT_PROJECT`.
  * Adds Awesome property `diligent_project` to client.
  * Merges client info into in‑memory `projects[project].clients`.
* On `client::unmanage`:

  * Marks client stopped; may respawn if project still running & `persistent=true`.

### 2.6 State Manager

* In‑memory model ←→ JSON file.
* Writes are **debounced** (0.5 s) to avoid thrash when many windows start.
* Atomic write pattern: temp file + `os.rename` + `fsync`.

### 2.7 Notification Sub‑system

* Thin wrapper around `naughty.notify`.
* Alerts user when: tag overflow → tag 9, spawn failures, graceful shutdown timeouts.

### 2.8 Tag Mapper

* Accepts `base_tag` and raw `tag` spec.
* Logic:

  1. **number** ⇒ `base_tag + n` (cap at 9 then overflow to 9).
  2. **"digits"** ⇒ tonumber(string).
  3. **name** ⇒ locate `awful.tag.find_by_name`; create if missing.

### 2.9 IPC Layer

* Unidirectional CLI → Awesome: `awesome-client` sending Lua string.
* Return path: Awesome emits `diligent::report(table)`; CLI polls via `awesome-client` `awesome.register_signal_handler` (implemented by waiting for stdout). Simpler alternative: module prints JSON to `/tmp/diligent.sock` and CLI reads—**post‑v1**.

---

## 3 Key Design Decisions

### DD‑1 Use Awesome signals over DBus

* **Pros:** zero external deps, pure Lua, same privilege domain.
* **Cons:** Need `awesome-client` parsing; stdout capture is crude but acceptable.

### DD‑2 Environment variable for client binding

* Chosen over X11 property because it works on both X11 and upcoming Wayland support in Awesome v5, and requires no XCB bindings.

### DD‑3 Single in‑WM module vs external daemon

* Embedding logic inside Awesome guarantees lifecycle with the WM and avoids extra processes; event loop already exists.

### DD‑4 Tag overflow strategy

* No wrapping to keep mental model simple. Tag 9 is the fallback and user is notified.

### DD‑5 Atomic JSON state file

* Prevents corruption on crash; enables resume after power loss.

---

## 4 Flow Diagrams

### 4.1 Start Sequence (sequence diagram)

```
workon           awesome              diligent.lua           awful.spawn
  |   start ▶       |                     |                     |
  |──────── signal────────▶|             |                     |
  |                        |─ load DSL ─▶|                     |
  |                        |─ tag map ───▶|                     |
  |                        |─ spawn res ─▶|─── command ───────▶|
  |                        |<─ client manage hook ─────────────|
  |                        |── state update ─▶|                |
  |                        |── report ok/fail ─▶|              |
  |◀────── receive JSON report ────────────────|               |
```

### 4.2 Stop Sequence

```
workon stop  ▶ signal 'diligent::stop' ▶  diligent.lua
                                          ├─ run hooks.stop
                                          ├─ send SIGINT/TERM
                                          ├─ wait & SIGKILL
                                          ├─ close windows
                                          └─ purge state
```

---

## 5 Interfaces Summary

1. **CLI ↔ Awesome signals**
   *Name:* `diligent::start|stop|status|resume`
   *Payload:* JSON string (project name, file path, options)
2. **Awesome module API** (internal)
   *`spawn(resource_tbl)`* – returns promise, pushes to state
   *`resolve_tag(tag_spec, base)`* – returns tag object
3. **State file**
   Path: `~/.cache/diligent/state.json`
   Schema documented in Feature Requirements FR‑5.

---

## 6 External Libraries

* **luafilesystem** – path ops & permissions.
* **dkjson** – JSON encode/decode.
* **lsignal / luaposix** – POSIX kill & signal constants.
* **lunotify (optional)** – could wrap `naughty` for test mode.

---

## 7 Testing Strategy

1. **Unit tests**—Busted for pure Lua functions (`tag_mapper`, `state_manager`).
2. **Integration**—`xvfb-run awesome -c tests/rc_fake.lua` spawns mock clients.
3. **End‑to‑end**—GitHub Actions matrix (Arch Linux container) installs Awesome, runs CLI scripts verifying state transitions.

---

### End of Document

