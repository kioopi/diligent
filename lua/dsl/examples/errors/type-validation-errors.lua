--[[
Error Example: Type Validation Errors

This example demonstrates type validation errors when fields have the wrong
data types or incorrect structure. Shows common mistakes users might make
with field types and resource structure.

Expected errors when running:
  workon validate --file lua/dsl/examples/errors/type-validation-errors.lua

1. "name must be a string" - Project name is wrong type
2. "cmd must be a string" - Command field is wrong type  
3. "dir must be a string" - Directory field is wrong type
4. "reuse must be a boolean" - Reuse field is wrong type
5. Resource structure validation errors

This helps users understand the type requirements for each DSL field.
--]]

return {
  -- ❌ ERROR: name must be a string, not a number
  name = 123,

  resources = {
    -- ❌ ERROR: Multiple type validation issues in this resource
    editor = app({
      -- ❌ ERROR: cmd must be a string, not a table
      cmd = { "nvim", "file.txt" }, -- Arrays are not supported, use a single command string

      -- ❌ ERROR: dir must be a string, not a number
      dir = 456,

      -- ❌ ERROR: reuse must be a boolean, not a string
      reuse = "yes", -- Should be true/false, not "yes"/"no"

      tag = 1, -- This is valid
    }),

    -- ❌ ERROR: Resource must use app() helper function, not plain string
    browser = "firefox", -- Should be: browser = app({cmd = "firefox"})

    -- ❌ ERROR: Resource missing entirely - just a value
    terminal = nil,

    -- ✅ VALID resource for comparison:
    -- text_editor = app({
    --   cmd = "gedit",           -- string ✓
    --   dir = "/home/user",      -- string ✓
    --   tag = 2,                 -- number ✓
    --   reuse = true             -- boolean ✓
    -- })
  },

  -- ❌ ERROR: hooks must be a table, not a string
  hooks = "invalid", -- Should be: hooks = {start = "command", stop = "command"}

  -- ❌ ERROR: Unknown field (typo)
  resoruces = { -- Typo: should be "resources"
    -- This will be ignored but shows a common mistake
  },
}
