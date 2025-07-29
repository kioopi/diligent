# Diligent — DSL Reference & Examples

*Last updated: 29 Jul 2025*

---

## 1 Philosophy

The DSL is **just Lua**.  You write a table, return it, and Diligent interprets it. This means:

* You may use variables, functions, comments.
* Editor support is automatic (Lua syntax highlighting).
* When in doubt, run `lua -l diligent_dsl_checker yourfile.lua` to catch syntax errors.

---

## 2 Top‑Level Schema

```lua
return {
  name      = "project‑id",        -- mandatory, must be unique
  resources = { … },               -- mandatory, at least one
  layouts   = { … },               -- optional (future multi‑layout)
  hooks     = { start=…, stop=… }, -- optional
}
```

### 2.1 `name` (string)

Human‑readable ID used for the project tag and state tracking.

### 2.2 `resources` (table)

*Keys* are **resource labels** (any identifier).  *Values* are created via helper functions:

* `app{…}` – generic X11 application
* `term{…}` – terminal window (shell or command)
* `browser{…}` – browser window with URLs
* `obsidian{…}` – Obsidian note workspace

### 2.3 `layouts` (table)

Optional named layouts mapping resource labels → tag specs (number, string digit, or name). If omitted, each resource uses its own `tag` key.

### 2.4 `hooks` (table)

Shell snippets executed **before** start/stop.

```lua
hooks = {
  start = "systemctl --user start myproj-dev",
  stop  = "systemctl --user stop  myproj-dev",
}
```

---

## 3 Tag Spec Recap

| Form             | Example  | Meaning                   |
| ---------------- | -------- | ------------------------- |
| **number**       | `1`      | Relative offset from base |
| **digit string** | `"3"`    | Absolute numeric tag 3    |
| **name string**  | `"logs"` | Absolute tag by name      |

If resolved > 9, placement falls back to tag 9 and a warning pops up.

---

## 4 Resource Helper Reference

### 4.1 `app{}`

| Key     | Type   | Default | Notes                          |
| ------- | ------ | ------- | ------------------------------ |
| `cmd`   | string | —       | Full shell command             |
| `dir`   | string | cwd     | Working directory              |
| `tag`   | see §3 | 0       | Where to place window          |
| `reuse` | bool   | false   | Attach to first matching class |

### 4.2 `term{}`

Same keys as `app{}` but `cmd` runs **inside** terminal (`alacritty -e`).  Extra key `interactive` (bool, default *true*) influences shutdown signal (`SIGINT`).

### 4.3 `browser{}`

| Key                                                              | Type           | Default | Notes                                    |
| ---------------------------------------------------------------- | -------------- | ------- | ---------------------------------------- |
| `urls`                                                           | list of string | —       | Opened via `xdg-open` or profile window  |
| `window`                                                         | "new"/"reuse"  | "new"   | open new browser window or reuse tab set |
| plus common keys: `tag`, `reuse` (class match on `firefox` etc.) |                |         |                                          |

### 4.4 `obsidian{}`

| Key                                              | Type   | Default | Notes              |
| ------------------------------------------------ | ------ | ------- | ------------------ |
| `path`                                           | string | —       | Vault path to open |
| inherits `tag` and `reuse` (class == "obsidian") |        |         |                    |

More helper types (VSCode, Slack, etc.) can be added by placing functions in `~/.config/diligent/helpers.lua`.

---

## 5 Example Configurations

### 5.1 Minimal One‑Tag Project

```lua
-- ~/.config/diligent/projects/note.lua
return {
  name = "note",
  resources = {
    obs = obsidian {
      path = "~/notes/work",
      tag  = 0,     -- same tag we launch from
      reuse = true, -- reuse if already open
    },
  },
}
```

Launch: `workon start note`.

### 5.2 Full‑Stack Web Project (relative tags)

```lua
return {
  name = "webshop",
  resources = {
    editor = app {
      cmd = "zed",
      dir = "~/code/webshop",
      tag = 0,
    },
    api_term = term {
      cmd = "nvim api/README.md",
      dir = "~/code/webshop",
      tag = 1,   -- base+1
    },
    shell = term {
      dir = "~/code/webshop",
      tag = 1,
    },
    browser = browser {
      urls = {
        "https://jira.example.com/browse/WS-42",
        "https://localhost:5173",
      },
      tag = 2,   -- base+2
    },
  },
  hooks = {
    start = "systemctl --user start webshop-dev",
    stop  = "systemctl --user stop  webshop-dev",
  },
}
```

Start on tag 4 → resources appear on tags 4‑6; project tag **webshop** is also created.

### 5.3 Absolute / Named Tags with Layout Variants

```lua
return {
  name = "monorepo",

  resources = {
    root_term = term { dir = "~/code", tag = "1" },
    backend   = app  { cmd = "zed ~/code/backend",  tag = "backend" },
    frontend  = app  { cmd = "zed ~/code/frontend", tag = "frontend" },
    docs      = browser { urls = {"http://localhost:8000"}, tag = "web" },
  },

  layouts = {
    office = { root_term="1", backend="backend", frontend="frontend", docs="web" },
    laptop = { root_term="1", backend="1", frontend="2", docs="2" },
  },
}
```

Pick layout via CLI: `workon start monorepo --layout laptop` (CLI flag TBD).

---

## 6 Extending the DSL

Because the DSL is Lua, users can:

* Compute tags programmatically:

  ```lua
  local base = os.getenv("DILIGENT_BASE") or 0
  resources = {
    heavy_tool = app { cmd = "blender", tag = tonumber(base)+3 },
  }
  ```
* Import helper functions:

  ```lua
  local shared = require("diligent.shared")
  resources = shared.mk_web_project("~/code/myproj", 0)
  ```

---

## 7 Validation & Debugging

Run:

```bash
lua -e "assert(loadfile('myproj.lua'))()"  # syntax check
workon start myproj --debug                 # verbose CLI + WM log
```

Inside Awesome, open `~/.cache/diligent/debug.log` for live traces.

---

### End of Document

