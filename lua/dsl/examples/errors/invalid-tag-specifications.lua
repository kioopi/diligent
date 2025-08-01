--[[
Error Example: Invalid Tag Specifications

This example demonstrates various tag specification validation errors.
Tags can be numbers (relative offsets), string digits (absolute tags 1-9),
or named strings (must start with letter, contain only letters/numbers/underscore/dash).

Expected errors when running:
  workon validate --file lua/dsl/examples/errors/invalid-tag-specifications.lua

1. "absolute tag must be between 1 and 9, got 0" - Invalid absolute tag
2. "absolute tag must be between 1 and 9, got 10" - Absolute tag out of range  
3. "invalid tag name format: must start with letter..." - Invalid named tag format
4. "tag must be a number or string, got boolean" - Wrong tag type

This helps users understand the tag specification rules in Diligent DSL.
--]]

return {
  name = "invalid-tags-demo",

  resources = {
    -- ❌ ERROR: Absolute tag 0 is invalid (must be 1-9)
    browser1 = app({
      cmd = "firefox",
      tag = "0", -- String "0" is interpreted as absolute tag, but 0 is invalid
    }),

    -- ❌ ERROR: Absolute tag 10 is out of range (must be 1-9)
    browser2 = app({
      cmd = "google-chrome",
      tag = "10", -- Absolute tags only support 1-9
    }),

    -- ❌ ERROR: Invalid named tag format (starts with number)
    editor = app({
      cmd = "nvim",
      tag = "2invalid-name", -- Named tags must start with a letter
    }),

    -- ❌ ERROR: Wrong tag type (boolean instead of number/string)
    terminal = app({
      cmd = "kitty",
      tag = true, -- Tags must be numbers or strings
    }),

    -- ❌ ERROR: Invalid named tag with special characters
    ide = app({
      cmd = "code",
      tag = "my@tag", -- Named tags can only contain letters, numbers, underscore, dash
    }),

    -- ✅ VALID examples (for comparison):
    -- Relative tags (numbers):
    -- tag = 0     -- Current tag
    -- tag = 1     -- Next tag
    -- tag = -1    -- Previous tag (in future versions)

    -- Absolute tags (string digits 1-9):
    -- tag = "1"   -- Absolute tag 1
    -- tag = "9"   -- Absolute tag 9

    -- Named tags (valid format):
    -- tag = "editor"     -- Simple name
    -- tag = "dev_env"    -- With underscore
    -- tag = "web-browser" -- With dash
  },
}
