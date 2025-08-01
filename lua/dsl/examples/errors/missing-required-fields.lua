--[[
Error Example: Missing Required Fields

This example demonstrates validation errors when required fields are missing
from the DSL structure. It shows both top-level required fields (name, resources)
and resource-level required fields (cmd).

Expected errors when running:
  workon validate --file lua/dsl/examples/errors/missing-required-fields.lua

1. "name field is required" - Missing project name
2. After adding name: "cmd field is required" - App resource missing command

This helps users understand the basic structure requirements of Diligent DSL files.
--]]

return {
  -- ❌ ERROR: Missing required 'name' field
  -- Uncomment the line below to fix the first error:
  -- name = "missing-fields-demo",

  resources = {
    editor = app({
      -- ❌ ERROR: Missing required 'cmd' field
      -- The cmd field is required for all app resources
      -- Uncomment the line below to fix this error:
      -- cmd = "nvim ~/notes/todo.txt",

      dir = "/tmp",
      tag = 1,
      reuse = true,
    }),

    -- This resource is valid (when name and cmd are added above)
    terminal = app({
      cmd = "kitty",
      tag = 2,
    }),
  },
}
