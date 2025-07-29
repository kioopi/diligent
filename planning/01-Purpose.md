# Diligent — Purpose & Vision

*Last updated: 29 Jul 2025*

---

## 1 Why does Diligent exist?

Modern developers juggle **many parallel projects**—each with its own editor session, terminals, log tails, browser tabs, documentation, and note‑taking tools. Manually recreating that “workspace constellation” costs focus every time you switch contexts.

**Diligent** eliminates this drag by letting you *declare* the desired workspace once, then summon or dismiss it with a single command. Think of it as a project‑centric “session manager” tightly integrated with AwesomeWM’s tag system.

---

## 2 What can you do with Diligent v 1.0?

* **Start a project workspace** via `workon start api‑server`, instantly:

  * opens your editor in the project directory
  * brings up one or more terminals (shell, `nvim README.md`, `tail -f log`)
  * attaches an existing Obsidian window to the project or launches a new one
  * spawns a browser window with predefined URLs (Jira ticket, CI dashboard)
  * annotates each window so Diligent can track & restore it later

* **Stop a workspace** (`workon stop api‑server`) gracefully—running processes receive `SIGTERM`/`SIGINT`, your `stop` hook (e.g. `docker compose down`) runs, windows close, and the project tag disappears.
* **Run multiple projects side‑by‑side.** Every project gets its own tag for quick overview, but windows also land on numeric or named tags relative to where you launched it—avoiding collisions by design.
* **Resume after an AwesomeWM restart**—Diligent’s state file tells the WM which windows belong to which project so they re‑attach automatically.

---

## 3 How does it roughly work?

```
 +--------------+           awesome-client signals         +-------------------+
 |  CLI  workon |  ────────────────────────────────▶      |  Awesome Module   |
 |  (Lua file)  | <───────────────────────────────────    |  diligent.lua      |
 +--------------+          result / error table          +-------------------+
```

1. **Command‑line:** You type `workon start foo`. The CLI reads `~/.config/diligent/projects/foo.lua` and sends `diligent::start` to Awesome.
2. **Awesome side:** `diligent.lua` parses the DSL, maps tags relative to the current tag, creates the extra project tag, spawns resources, and records everything to `~/.cache/diligent/state.json`.
3. **Tracking:** As each new client arrives, the module tags it both with its designated numeric/tag and the project tag, then stores its window ID.
4. **Teardown:** `workon stop foo` signals `diligent::stop`; the module runs the `stop` hook, signals processes, and cleans state.

---

## 4 Typical workflow snapshot

| Action         | Keyboard/Command                     | What Diligent does                                        |
| -------------- | ------------------------------------ | --------------------------------------------------------- |
| Morning start  | `mod+Enter` → `workon start webshop` | Full workspace appears on tags 1‑3, plus tag **webshop**. |
| Quick hot‑fix  | `workon start cli‑tool` on tag 4     | Uses tags 4‑5, own tag **cli‑tool**.                      |
| Switch context | click on tag **cli‑tool**            | All windows for that side project pop into view.          |
| Finish hot‑fix | `workon stop cli‑tool`               | Gracefully closes its windows, leaves webshop intact.     |

---

## 5 Non‑Goals (v 1.0)

* Running background services—leave that to `systemd`, `docker‑compose`, etc. (You *can* call them from DSL hooks.)
* Advanced tiling/geometry presets—basic tag placement only. Future versions may integrate gap/column layouts.
* Multi‑monitor placement—v 1 pins everything to the current screen.
* Wayland‑native window property tracking—waiting on Awesome v5.

---

## 6 Looking ahead

After the minimal “workspace up/down” flow is solid, we’ll extend Diligent with:

* **Layout variants** (office vs laptop)
* **Multi‑screen awareness**
* **Per‑project keybindings**
* **Automatic restoration after power loss**
