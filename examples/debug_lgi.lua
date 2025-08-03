#!/usr/bin/env lua5.3
--[[
LGI and D-Bus Diagnostic Script

This script provides detailed information about LGI availability,
package paths, and D-Bus setup for debugging purposes.
--]]

print("=== LGI and D-Bus Diagnostic ===")
print()

-- Print Lua version
print("Lua version:", _VERSION)
print()

-- Print package paths
print("Package path:")
for path in package.path:gmatch("[^;]+") do
  print("  " .. path)
end
print()

print("Package cpath:")
for path in package.cpath:gmatch("[^;]+") do
  print("  " .. path)
end
print()

-- Test LGI loading
print("Testing LGI loading:")
local success, lgi = pcall(require, "lgi")
if success then
  print("✓ LGI loaded successfully")
  print("  Type:", type(lgi))

  -- Test GLib
  local glib_success, GLib = pcall(lgi.require, "GLib")
  if glib_success then
    print("✓ GLib available")
    print("  Type:", type(GLib))
  else
    print("✗ GLib failed:", GLib)
  end

  -- Test Gio
  local gio_success, Gio = pcall(lgi.require, "Gio")
  if gio_success then
    print("✓ Gio available")
    print("  Type:", type(Gio))

    -- Test D-Bus components
    if Gio.DBusConnection then
      print("✓ DBusConnection available")
    else
      print("✗ DBusConnection not available")
    end

    if Gio.bus_get_sync then
      print("✓ bus_get_sync available")
    else
      print("✗ bus_get_sync not available")
    end
  else
    print("✗ Gio failed:", Gio)
  end
else
  print("✗ LGI failed to load:", lgi)
end
print()

-- Test basic file operations (to ensure we can write test files)
print("Testing file operations:")
local test_file = "/tmp/lgi_debug_test_" .. os.time()
local file = io.open(test_file, "w")
if file then
  file:write("test")
  file:close()
  os.remove(test_file)
  print("✓ File operations working")
else
  print("✗ File operations failed")
end
print()

-- Print environment variables that might affect LGI
print("Relevant environment variables:")
local env_vars =
  { "LD_LIBRARY_PATH", "LUA_PATH", "LUA_CPATH", "PKG_CONFIG_PATH" }
for _, var in ipairs(env_vars) do
  local value = os.getenv(var)
  if value then
    print("  " .. var .. "=" .. value)
  else
    print("  " .. var .. "=(not set)")
  end
end
print()

print("=== End Diagnostic ===")
