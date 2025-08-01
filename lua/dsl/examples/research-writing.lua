--[[
Research & Writing Project Example

An academic/research workflow demonstrating:
- Document-centric workspace
- Reference management
- Multiple layout support (future feature)
- Complex tag organization

Usage: workon start research-writing
--]]

return {
  name = "research-writing",

  resources = {
    -- Main writing environment
    manuscript = app({
      cmd = "zed ~/research/quantum-paper/manuscript.md",
      dir = "~/research/quantum-paper",
      tag = 0, -- Current tag for main work
    }),

    -- Note-taking and knowledge management
    notes = app({
      cmd = "obsidian --path ~/research/knowledge-base",
      tag = "notes", -- Named tag for reference materials
      reuse = true,
    }),

    -- Reference manager
    references = app({
      cmd = "zotero",
      tag = "refs", -- Named tag for bibliography
      reuse = true,
    }),

    -- PDF viewer for papers
    papers = app({
      cmd = "evince ~/research/papers/",
      dir = "~/research/papers",
      tag = "refs", -- Same tag as references
    }),

    -- Terminal for git, latex compilation, etc.
    terminal = app({
      cmd = "alacritty",
      dir = "~/research/quantum-paper",
      tag = 1, -- Relative: next tag for tools
    }),

    -- Web browser for research
    research_browser = app({
      cmd = "firefox --new-window https://scholar.google.com",
      tag = "web", -- Named tag for web research
    }),

    -- Calculation/analysis tool
    calculator = app({
      cmd = "gnome-calculator",
      tag = 1, -- Same tag as terminal
      reuse = true,
    }),

    -- LaTeX preview (if using LaTeX)
    latex_preview = app({
      cmd = "evince ~/research/quantum-paper/manuscript.pdf",
      tag = 0, -- Same tag as manuscript
      reuse = true,
    }),
  },

  -- Future feature: multiple layouts for different contexts
  layouts = {
    -- Deep writing mode: minimal distractions
    writing = {
      manuscript = 0,
      notes = "notes",
      terminal = 1,
    },

    -- Research mode: access to all references
    research = {
      manuscript = 0,
      notes = "notes",
      references = "refs",
      papers = "refs",
      research_browser = "web",
      terminal = 1,
    },

    -- Review mode: side-by-side comparison
    review = {
      manuscript = 1,
      latex_preview = 2,
      notes = "notes",
      terminal = 3,
    },
  },

  hooks = {
    -- Backup work and sync references
    start = "cd ~/research/quantum-paper && git pull",

    -- Commit progress and backup
    stop = "cd ~/research/quantum-paper && git add -A && git commit -m 'Work session $(date)' || true",
  },
}
