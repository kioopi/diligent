--[[
Minimal Project Example

This is the simplest possible Diligent project configuration.
Perfect for quick note-taking or single-application workflows.

Usage: workon start minimal-project
--]]

return {
  name = "minimal-project",

  resources = {
    -- Just open a text editor on the current tag
    editor = app({
      cmd = "gedit ~/notes/scratch.txt",
      tag = 0, -- Current tag (relative offset 0)
      reuse = true, -- Reuse existing gedit window if available
    }),
  },
}
