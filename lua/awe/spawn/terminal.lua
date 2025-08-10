--[[
Terminal Command Wrapper Module

Handles terminal command wrapping for spawning terminal applications.
--]]

---Create terminal wrapper module with injected interface
---@param _interface table Interface implementation (awesome, dry_run, mock)
---@return table terminal Terminal wrapper module functions
local function create_terminal(_interface)
  local terminal = {}

  -- Terminal emulator configurations
  local TERMINAL_CONFIGS = {
    alacritty = { exec_flag = "-e" },
    xterm = { exec_flag = "-e" },
    ["gnome-terminal"] = { exec_flag = "--" },
  }

  ---Wrap command for terminal execution
  ---@param command string Command to wrap
  ---@param terminal_emulator string|nil Terminal emulator to use (default: "alacritty")
  ---@param interactive boolean|nil Interactive mode (default: true, currently ignored)
  ---@return string wrapped_command Terminal-wrapped command
  function terminal.wrap_command_for_terminal(
    command,
    terminal_emulator,
    interactive
  )
    terminal_emulator = terminal_emulator or "alacritty"
    interactive = interactive == nil and true or interactive

    local config = TERMINAL_CONFIGS[terminal_emulator]
    if not config then
      error("Unsupported terminal emulator: " .. tostring(terminal_emulator))
    end

    return terminal_emulator .. " " .. config.exec_flag .. " " .. command
  end

  ---Check if terminal emulator is supported
  ---@param terminal_emulator string|nil Terminal emulator name
  ---@return boolean supported True if terminal is supported
  function terminal.is_supported_terminal(terminal_emulator)
    if not terminal_emulator or terminal_emulator == "" then
      return false
    end
    return TERMINAL_CONFIGS[terminal_emulator] ~= nil
  end

  ---Get list of supported terminal emulators
  ---@return table supported_terminals Sorted list of supported terminal names
  function terminal.get_supported_terminals()
    local supported = {}
    for term_name, _ in pairs(TERMINAL_CONFIGS) do
      table.insert(supported, term_name)
    end
    table.sort(supported)
    return supported
  end

  return terminal
end

return create_terminal
