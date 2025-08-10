--[[
Terminal Command Wrapper Tests

Tests terminal command wrapping functionality for spawning terminal applications.
--]]

local assert = require("luassert")

describe("awe.spawn.terminal", function()
  local awe
  local mock_interface
  local terminal

  setup(function()
    _G._TEST = true
    awe = require("awe")
  end)

  teardown(function()
    _G._TEST = nil
  end)

  before_each(function()
    mock_interface = awe.interfaces.mock_interface
    local create_terminal = require("awe.spawn.terminal")
    terminal = create_terminal(mock_interface)
  end)

  describe("wrap_command_for_terminal", function()
    it("should wrap command with alacritty by default", function()
      local result = terminal.wrap_command_for_terminal("nvim notes.md")
      assert.are.equal("alacritty -e nvim notes.md", result)
    end)

    it("should handle different terminal emulators", function()
      local result = terminal.wrap_command_for_terminal("bash", "xterm")
      assert.are.equal("xterm -e bash", result)
    end)

    it("should handle alacritty explicitly", function()
      local result =
        terminal.wrap_command_for_terminal("nvim file.txt", "alacritty")
      assert.are.equal("alacritty -e nvim file.txt", result)
    end)

    it("should handle gnome-terminal with different exec flag", function()
      local result =
        terminal.wrap_command_for_terminal("bash", "gnome-terminal")
      assert.are.equal("gnome-terminal -- bash", result)
    end)

    it("should handle complex commands with arguments", function()
      local result = terminal.wrap_command_for_terminal(
        "nvim file.txt --readonly",
        "alacritty"
      )
      assert.are.equal("alacritty -e nvim file.txt --readonly", result)
    end)

    it("should handle commands with quotes", function()
      local result =
        terminal.wrap_command_for_terminal("echo 'hello world'", "xterm")
      assert.are.equal("xterm -e echo 'hello world'", result)
    end)

    it("should handle interactive parameter (currently ignored)", function()
      -- Interactive parameter is accepted but doesn't change behavior yet
      local result1 =
        terminal.wrap_command_for_terminal("bash", "alacritty", true)
      local result2 =
        terminal.wrap_command_for_terminal("bash", "alacritty", false)
      assert.are.equal("alacritty -e bash", result1)
      assert.are.equal("alacritty -e bash", result2) -- Same for now
    end)

    it("should default interactive to true when not specified", function()
      local result =
        terminal.wrap_command_for_terminal("bash", "alacritty", nil)
      assert.are.equal("alacritty -e bash", result)
    end)

    it("should error on unsupported terminal emulator", function()
      assert.has_error(function()
        terminal.wrap_command_for_terminal("bash", "unsupported-terminal")
      end, "Unsupported terminal emulator: unsupported-terminal")
    end)

    it("should handle empty command", function()
      local result = terminal.wrap_command_for_terminal("", "alacritty")
      assert.are.equal("alacritty -e ", result)
    end)
  end)

  describe("is_supported_terminal", function()
    it("should return true for supported terminals", function()
      assert.is_true(terminal.is_supported_terminal("alacritty"))
      assert.is_true(terminal.is_supported_terminal("xterm"))
      assert.is_true(terminal.is_supported_terminal("gnome-terminal"))
    end)

    it("should return false for unsupported terminals", function()
      assert.is_false(terminal.is_supported_terminal("unsupported-terminal"))
      assert.is_false(terminal.is_supported_terminal("konsole")) -- not implemented yet
    end)

    it("should handle nil input", function()
      assert.is_false(terminal.is_supported_terminal(nil))
    end)

    it("should handle empty string", function()
      assert.is_false(terminal.is_supported_terminal(""))
    end)
  end)

  describe("get_supported_terminals", function()
    it("should return list of supported terminal emulators", function()
      local supported = terminal.get_supported_terminals()
      assert.is_table(supported)
      assert.is_true(#supported > 0)

      -- Check that known terminals are included
      local has_alacritty = false
      local has_xterm = false
      for _, term in ipairs(supported) do
        if term == "alacritty" then
          has_alacritty = true
        end
        if term == "xterm" then
          has_xterm = true
        end
      end
      assert.is_true(has_alacritty)
      assert.is_true(has_xterm)
    end)

    it("should return sorted list", function()
      local supported = terminal.get_supported_terminals()
      local sorted = {}
      for _, term in ipairs(supported) do
        table.insert(sorted, term)
      end
      table.sort(sorted)

      for i, term in ipairs(supported) do
        assert.are.equal(sorted[i], term)
      end
    end)
  end)
end)
