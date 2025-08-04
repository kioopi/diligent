--[[
Error Handling Factory Module

This module provides error handling functionality through a factory pattern
with dependency injection, following the established awe module architecture.

Features:
- Error classification and type detection
- Structured error reporting and aggregation
- User-friendly error formatting
- Instance-based dependency injection
--]]

local error_factory = {}

-- Create error handler instance with dependency injection
function error_factory.create(interface)
  interface = interface or require("awe").interfaces.awesome_interface

  local classifier = require("awe.error.classifier").create(interface)
  local reporter = require("awe.error.reporter").create(interface)
  local formatter = require("awe.error.formatter").create(interface)

  return {
    classifier = classifier,
    reporter = reporter,
    formatter = formatter,
  }
end

return error_factory
