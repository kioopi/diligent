--[[
Web Development Project Example

A full-stack web development setup demonstrating:
- Multiple resource types with different tag specifications
- Hooks for project lifecycle management
- Mixed relative, absolute, and named tag usage

Usage: workon start web-development
--]]

return {
  name = "web-development",

  resources = {
    -- Code editor on current tag
    editor = app({
      cmd = "zed ~/projects/webapp",
      dir = "~/projects/webapp",
      tag = 0, -- Relative: current tag
      reuse = true, -- Reuse existing Zed window
    }),

    -- Development server terminal on next tag
    dev_server = app({
      cmd = "alacritty -e bash -c 'npm run dev; exec bash'",
      dir = "~/projects/webapp",
      tag = 1, -- Relative: base + 1
    }),

    -- General terminal for git commands, etc.
    terminal = app({
      cmd = "alacritty",
      dir = "~/projects/webapp",
      tag = 1, -- Same tag as dev server
    }),

    -- Browser for testing on absolute tag 3
    browser = app({
      cmd = "firefox --new-window http://localhost:3000",
      tag = "3", -- Absolute: always tag 3
    }),

    -- API documentation on named tag
    docs = app({
      cmd = "firefox --new-window http://localhost:8080/docs",
      tag = "docs", -- Named: create/use "docs" tag
      reuse = true,
    }),

    -- Database admin tool on named tag
    database = app({
      cmd = "dbeaver",
      tag = "db", -- Named: create/use "db" tag
      reuse = true,
    }),
  },

  hooks = {
    -- Start background services before opening apps
    start = "docker-compose up -d && sleep 2",

    -- Clean shutdown of services
    stop = "docker-compose down",
  },
}
