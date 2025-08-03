# Diligent Coding Guidelines

**Version**: 1.0  
**Date**: August 3, 2025  
**Status**: Active

## Overview

This document establishes coding standards and API design patterns for the Diligent project. These guidelines ensure consistency, maintainability, and quality across all Lua modules and scripts.

## Table of Contents

- [API Design Standards](#api-design-standards)
- [Function Design Patterns](#function-design-patterns)
- [Error Handling Standards](#error-handling-standards)
- [Documentation Standards](#documentation-standards)
- [Code Organization](#code-organization)
- [Testing Guidelines](testing-guidelines.md)
- [Language Server Annotations](#language-server-annotations)
- [Module Structure](#module-structure)

## API Design Standards

### Function Signature Pattern

All public functions should follow this consistent signature pattern:

```lua
function module.operation(primary_input, context, options)
  -- primary_input: main data (tag_spec, app_name, pid, etc.)
  -- context: environmental data (base_tag, screen_context, etc.)
  -- options: configuration (timeout, properties, etc.)
end
```

**Examples**:

```lua
-- Good: Consistent parameter ordering
function tag_mapper.resolve_tag(tag_spec, base_tag, options)
function client_manager.spawn_application(app_name, tag_spec, spawn_config)
function error_reporter.create_report(error_type, context, options)

-- Bad: Inconsistent parameter ordering
function tag_mapper.resolve_tag(options, tag_spec, base_tag)
function client_manager.spawn_application(spawn_config, app_name, tag_spec)
```

### Return Pattern

All functions should return values in this consistent pattern:

```lua
return success, result, metadata
-- success: boolean success indicator
-- result: actual result data or error message
-- metadata: additional context (timing, warnings, etc.)
```

**Examples**:

```lua
-- Good: Consistent return pattern
function tag_mapper.resolve_tag(tag_spec, base_tag)
  local success, tag = pcall(resolve_tag_internal, tag_spec, base_tag)
  if success then
    return true, tag, {resolved_index = tag.index, timing = 0.001}
  else
    return false, "Tag resolution failed: " .. tag, {attempted_spec = tag_spec}
  end
end

-- Usage
local success, tag, metadata = tag_mapper.resolve_tag("+2", 3)
if success then
  print("Resolved to tag:", tag.name, "in", metadata.timing, "seconds")
else
  print("Error:", tag)  -- tag contains error message when success=false
end

-- Bad: Inconsistent return patterns
function bad_example1(input)
  if error then
    return nil, "error message"  -- Different pattern
  else
    return result  -- No success indicator
  end
end

function bad_example2(input)
  if error then
    error("Something failed")  -- Throws instead of returning
  else
    return true, result, extra, more, params  -- Too many return values
  end
end
```

### Input Validation

Always validate inputs explicitly and provide clear error messages:

```lua
function module.operation(primary_input, context, options)
  -- Input validation
  if not primary_input then
    return false, "primary_input is required", {validation_error = true}
  end
  
  if type(primary_input) ~= "string" then
    return false, "primary_input must be a string", {
      validation_error = true,
      received_type = type(primary_input)
    }
  end
  
  -- Set defaults for optional parameters
  context = context or {}
  options = options or {}
  
  -- Operation logic...
end
```

## Function Design Patterns

### Pure Functions When Possible

Prefer pure functions that don't depend on external state:

```lua
-- Good: Pure function
function tag_mapper_core.resolve_tag_specification(tag_spec, base_tag, screen_context)
  -- No external dependencies, deterministic output
  -- Easy to test and reason about
end

-- Acceptable: Function with controlled side effects
function awesome_interface.create_named_tag(name, screen)
  -- Side effect is necessary for functionality
  -- Well-documented and controlled
end
```

### Separation of Concerns

Each function should have a single, well-defined responsibility:

```lua
-- Good: Focused responsibility
function spawn_configuration.build_properties(tag, config)
  -- Only builds spawn properties
end

function spawn_environment.prepare_command(app, env_vars)
  -- Only handles environment setup
end

-- Bad: Multiple responsibilities
function spawn_everything(app, tag, config, env_vars, timeout, debug_mode)
  -- Builds properties AND prepares environment AND spawns AND waits
  -- Too many responsibilities in one function
end
```

## Error Handling Standards

### Consistent Error Objects

All error objects should follow this structure:

```lua
{
  type = "ERROR_TYPE_CONSTANT",
  message = "User-friendly error message",
  context = {
    -- Relevant context data
    input_value = "...",
    attempted_operation = "...",
    -- etc.
  },
  suggestions = {
    "Actionable suggestion 1",
    "Actionable suggestion 2"
  },
  timestamp = os.time(),
  module = "module_name"
}
```

**Example**:

```lua
-- In awe/error/reporter.lua
function reporter.create_tag_resolution_error(tag_spec, context)
  return {
    type = "TAG_RESOLUTION_FAILED",
    message = "Could not resolve tag specification '" .. tag_spec .. "'",
    context = {
      tag_spec = tag_spec,
      base_tag = context.base_tag,
      available_tags = context.available_tags
    },
    suggestions = {
      "Check tag specification format (0, +N, -N, N, or \"name\")",
      "Ensure target tag exists or can be created",
      "Verify screen has available tag slots"
    },
    timestamp = os.time(),
    module = "awe.tag.resolver"
  }
end
```

### Error Classification

Use consistent error type constants across the project:

```lua
-- In awe/error/types.lua
local ERROR_TYPES = {
  -- Input validation errors
  INVALID_INPUT = "INVALID_INPUT",
  MISSING_REQUIRED_PARAMETER = "MISSING_REQUIRED_PARAMETER",
  
  -- Operation failures
  TAG_RESOLUTION_FAILED = "TAG_RESOLUTION_FAILED",
  COMMAND_NOT_FOUND = "COMMAND_NOT_FOUND",
  PERMISSION_DENIED = "PERMISSION_DENIED",
  TIMEOUT = "TIMEOUT",
  
  -- System errors
  DBUS_COMMUNICATION_FAILED = "DBUS_COMMUNICATION_FAILED",
  AWESOME_WM_UNAVAILABLE = "AWESOME_WM_UNAVAILABLE",
  
  -- Unknown/unclassified
  UNKNOWN = "UNKNOWN"
}
```

## Documentation Standards

### Module Headers

Every module should start with a clear header:

```lua
--[[
Module Name

Brief description of what this module does and its primary responsibilities.

Features:
- Feature 1
- Feature 2
- Feature 3

Dependencies:
- module1: Purpose
- module2: Purpose

Usage:
  local module = require("module_name")
  local success, result = module.operation(input)

Author: Generated with Claude Code
License: MIT
--]]

local module_name = {}
```

### Function Documentation

Document all public functions with clear descriptions:

```lua
---Resolve tag specification to actual tag object
---Handles string-based tag specifications from CLI tools and converts them
---to structured tag objects using the tag_mapper module.
---@param tag_spec string Tag specification ("0", "+2", "-1", "3", "editor")
---@param options table|nil Optional configuration {timeout = 5, create_missing = true}
---@return boolean success True if resolution succeeded
---@return table|string result Tag object on success, error message on failure
---@return table metadata Additional context {timing, warnings, etc.}
function tag_resolver.resolve_string_spec(tag_spec, options)
  -- Implementation...
end
```

## Code Organization

### Module Structure

Organize modules with a consistent internal structure:

```lua
--[[ Module header ]]

local module_name = {}

-- Constants (if any)
local DEFAULT_TIMEOUT = 5
local MAX_RETRIES = 3

-- Private helper functions
local function validate_input(input)
  -- Helper function implementation
end

local function internal_operation(data)
  -- Private implementation details
end

-- Public interface functions
function module_name.public_operation(input, context, options)
  -- Public function implementation
end

function module_name.another_operation(input, context, options)
  -- Another public function
end

-- Module initialization (if needed)
function module_name.initialize(config)
  -- Initialization logic
end

return module_name
```

### Import Organization

Organize imports logically and consistently:

```lua
-- Standard library imports
local os = os
local io = io

-- External dependencies
local awesome_interface = require("awe.interfaces.awesome_interface")
local tag_mapper = require("tag_mapper")

-- Internal project modules
local error_reporter = require("awe.error.reporter")
local configuration = require("awe.spawn.configuration")

-- Constants and configuration
local DEFAULT_CONFIG = require("config.defaults")
```

## Testing Guidelines

For comprehensive testing standards, patterns, and best practices, see [Testing Guidelines](testing-guidelines.md). This includes:

- Interface testing and mocking strategies
- Anti-patterns to avoid (runtime patching, incomplete mocks)
- Test structure and organization
- Coverage requirements and quality standards

## Language Server Annotations

### Type Annotations

Use Lua Language Server annotations for better development experience:

```lua
---@class TagSpec
---@field type "relative"|"absolute"|"named"
---@field value number|string
---@field overflow boolean

---@class ScreenContext
---@field screen table AwesomeWM screen object
---@field available_tags table[] List of available tag objects
---@field current_tag_index number Current selected tag index

---Resolve tag specification with full type safety
---@param tag_spec TagSpec The tag specification to resolve
---@param screen_context ScreenContext Screen and tag information
---@param options table|nil Optional configuration
---@return boolean success True if resolution succeeded
---@return table|string result Tag object on success, error message on failure
---@return table metadata Resolution metadata and warnings
function tag_mapper_core.resolve_tag_specification(tag_spec, screen_context, options)
  -- Implementation with full type checking
end
```

### Enum Definitions

Define enums for better type safety:

```lua
---@enum ErrorType
local ErrorType = {
  INVALID_INPUT = "INVALID_INPUT",
  TAG_RESOLUTION_FAILED = "TAG_RESOLUTION_FAILED",
  COMMAND_NOT_FOUND = "COMMAND_NOT_FOUND",
  TIMEOUT = "TIMEOUT"
}

---@enum TagType
local TagType = {
  RELATIVE = "relative",
  ABSOLUTE = "absolute", 
  NAMED = "named"
}
```

### Generic Types

Use generic annotations for flexible APIs:

```lua
---Generic function that works with different input types
---@generic T
---@param input T The input to process
---@param processor fun(input: T): T Processing function
---@return T processed The processed result
function utils.process_with_function(input, processor)
  return processor(input)
end
```

## Module Structure

### Interface Modules

For modules that provide interfaces to external systems:

```lua
--[[
AwesomeWM Interface Module

Provides a clean abstraction layer for AwesomeWM interactions.
Enables testing through mock implementations and provides
consistent error handling across all AwesomeWM operations.
--]]

local awesome_interface = {}

---@class AwesomeInterface
---@field get_screen_context fun(): ScreenContext
---@field create_named_tag fun(name: string): table|nil
---@field find_tag_by_name fun(name: string): table|nil

function awesome_interface.get_screen_context()
  -- Implementation that can be mocked for testing
end

function awesome_interface.create_named_tag(name)
  -- Abstracted tag creation with error handling
end

return awesome_interface
```

### Configuration Modules

For modules that handle configuration:

```lua
local config = {}

---@class SpawnConfig
---@field timeout number Maximum wait time in seconds
---@field floating boolean Whether window should float
---@field placement string Placement strategy
---@field env_vars table<string, string> Environment variables

---Build spawn configuration with validation and defaults
---@param user_config table User-provided configuration
---@return SpawnConfig config Validated configuration object
function config.build_spawn_config(user_config)
  local validated = {
    timeout = user_config.timeout or 5,
    floating = user_config.floating or false,
    placement = user_config.placement or "center",
    env_vars = user_config.env_vars or {}
  }
  
  -- Validation logic
  assert(type(validated.timeout) == "number", "timeout must be a number")
  assert(validated.timeout > 0, "timeout must be positive")
  
  return validated
end

return config
```

## Best Practices Summary

### Code Quality

1. **Consistent APIs**: Follow the established patterns for function signatures and return values
2. **Input Validation**: Always validate inputs and provide clear error messages
3. **Error Handling**: Use consistent error objects with actionable suggestions
4. **Type Safety**: Use Language Server annotations for better development experience
5. **Documentation**: Document all public functions and complex logic
6. **Testing**: Write comprehensive tests with good coverage

### Performance

1. **Avoid Premature Optimization**: Write clear code first, optimize when needed
2. **Cache Expensive Operations**: Cache results of expensive computations when appropriate
3. **Lazy Loading**: Load modules and resources only when needed
4. **Minimize Dependencies**: Keep module dependencies minimal and well-justified

### Maintainability

1. **Single Responsibility**: Each module and function should have one clear purpose
2. **Loose Coupling**: Minimize dependencies between modules
3. **High Cohesion**: Group related functionality together
4. **Clear Interfaces**: Provide clean, well-documented APIs
5. **Consistent Patterns**: Follow established patterns throughout the project

### Security

1. **Input Sanitization**: Validate and sanitize all external inputs
2. **No Secrets in Code**: Never include secrets, keys, or passwords in source code
3. **Principle of Least Privilege**: Request only the minimum permissions needed
4. **Error Information**: Don't expose sensitive information in error messages

---

**Remember**: These guidelines serve the goal of creating maintainable, reliable, and consistent code. When in doubt, favor clarity and simplicity over cleverness.