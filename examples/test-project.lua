-- Test DSL file for Phase 1 MVP testing
-- This demonstrates a simple project with a single app resource

local function app(spec)
  return {
    type = "app",
    cmd = spec.cmd,
    dir = spec.dir,
    tag = spec.tag or 0,
  }
end

return {
  name = "test-project",
  resources = {
    editor = app({
      cmd = "gedit",
      tag = 0, -- Current tag
    }),
  },
}
