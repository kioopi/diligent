--[[
CLI Printer Module for Diligent

Provides colored output functions for the command-line interface.
This module extracts the print helper functions from the main CLI script
for better maintainability and testability.
--]]

local cli_printer = {}

-- Helper function to print colored output with success indicator
function cli_printer.success(msg)
  print("\027[32m✓\027[0m " .. msg)
end

-- Helper function to print colored output with error indicator
function cli_printer.error(msg)
  print("\027[31m✗\027[0m " .. msg)
end

-- Helper function to print colored output with info indicator
function cli_printer.info(msg)
  print("\027[34mℹ\027[0m " .. msg)
end

return cli_printer
