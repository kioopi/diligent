--[[
Diligent Error Handling Factory Module

This module provides error handling functionality through a factory pattern
with dependency injection. Enhanced version of the awe/error framework
with support for tag resolution errors.

Features:
- Error classification and type detection
- Structured error reporting and aggregation
- User-friendly error formatting
- Tag resolution specific error handling
--]]

local error_factory = {}

-- Create error handler instance with dependency injection
function error_factory.create(interface)
  local classifier = require("diligent.error.classifier").create(interface)
  local reporter = require("diligent.error.reporter").create(interface)
  local formatter = require("diligent.error.formatter").create(interface)

  return {
    classifier = classifier,
    reporter = reporter,
    formatter = formatter,
  }
end

return error_factory
