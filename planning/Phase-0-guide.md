## Objective

Phase 0 establishes the scaffolding, standards, and automation that every later feature will rely on. When this phase is done any contributor can **clone, run `luarocks make`, and watch CI turn green** on the first push.

## Expected Outcomes

* Git repository with agreed directory layout.
* Fully automated GitHub Actions pipeline that executes tests, linting, formatting and coverage gates.
* Shared style & quality configs committed to VCS.
* Initial stub module installable via `luarocks make`.
* Badges in `README.md` for build and coverage.

## Task Breakdown

\### 1. Repository bootstrap

| Task                                                                                | Deliverable                           | Notes                                                                                                                  |
| ----------------------------------------------------------------------------------- | ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Create mono‑repo root `diligent/` with sub‑folders `cli/`, `lua/`, `spec/`, `docs/` | Committed directory tree              | Mirrors roadmap document                                                                                               |
| Add **MIT LICENSE**, `README.md`, `.gitignore`, `.editorconfig`                     | Files present; PR reviewed            | EditorConfig spec reference ([spec.editorconfig.org](https://spec.editorconfig.org/index.html?utm_source=chatgpt.com)) |
| Stub rockspec `diligent‑scm‑0.rockspec` with deps (`luafilesystem`, `dkjson`)       | `luarocks make` installs empty module | LuaRocks rockspec guidelines ([luarocks.org](https://luarocks.org/about?utm_source=chatgpt.com))                       |

\### 2. Toolchain setup

| Area                           | Deliverable                                                                       | Docs                                                                                                  |
| ------------------------------ | --------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| **Unit testing**               | Add Busted + Luassert; example test in `spec/cli_spec.lua`; add `make test` alias | Busted docs ([lunarmodules.github.io](https://lunarmodules.github.io/busted/?utm_source=chatgpt.com)) |
| **Coverage**                   | Integrate `luacov` & generate `luacov.report.out`, minimum threshold 60 %         | LuaCov docs ([luarocks.org](https://luarocks.org/modules/mpeterv/luacov?utm_source=chatgpt.com))      |
| **Formatter**                  | Commit `stylua.toml`; add `make fmt`                                              | StyLua repo ([github.com](https://github.com/JohnnyMorganz/StyLua?utm_source=chatgpt.com))            |
| **Linter**                     | Commit `selene.toml`; add `make lint`                                             | Selene docs ([kampfkarren.github.io](https://kampfkarren.github.io/selene/?utm_source=chatgpt.com))   |
| **Pre‑commit hooks** *(extra)* | `.pre‑commit‑config.yaml` runs fmt, lint                                          | Based on Git pre‑commit                                                                               |

\### 3. Continuous Integration

* **Platform** — GitHub Actions. Single workflow `ci.yml`. Reference syntax & quick‑start labs ([docs.github.com](https://docs.github.com/actions/reference/workflow-syntax-for-github-actions?utm_source=chatgpt.com), [docs.github.com](https://docs.github.com/actions/quickstart?utm_source=chatgpt.com))
* **Container** — Use `archlinux:latest` Docker image so we can `pacman ‑Sy awesome luarocks` before running jobs.
* **Matrix** — Test on Lua 5.3 and 5.4 via `leafo/gh-actions-lua` action ([github.com](https://github.com/leafo/gh-actions-lua?utm_source=chatgpt.com))
* **Stages**

  1. **Setup** — checkout, install deps (`awesome`, `luarocks`, `luacheck` alternatives).
  2. **Lint** — `selene src/` + `stylua --check`.
  3. **Test** — `busted -o utfTerminal -v`; on success upload Luacov report.
  4. **Coverage gate** — fail if `<60 %` using luacov‑checker.
* Optionally upload coverage to Codecov for badge ([about.codecov.io](https://about.codecov.io/tool/luacov/?utm_source=chatgpt.com))

\### 4. Documentation & Badges

* Add **status badges** for build (`actions/workflows/ci.yml`) and coverage (Codecov).
* Extend `README.md` with quick install & developer setup instructions; link to docs of each tool.

\### 5. Quality gates & conventions

* CI blocks merge on: failed tests, coverage <60 %, linter warnings, formatter diff.
* Branch protection rules enforce green pipeline before PR merge.

\### 6. Nice‑to‑haves (optional but recommended)

* Dependabot config for LuaRocks to keep libs fresh.

## Exit Criteria

* `git clone && luarocks make` succeeds on Arch and Ubuntu.
* `make test lint fmt` all green locally.
* `git push` triggers CI that passes on both Lua versions with ≥60 % coverage.
* Project documents (Purpose, Architecture, Feature Requirements, DSL, Roadmap) are linked from README.

