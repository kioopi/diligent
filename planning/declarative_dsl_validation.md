# Diligent — Declarative DSL Validation Architecture

*Last updated: 01 Aug 2025*

> **This document provides a comprehensive plan for refactoring Diligent's DSL validation from imperative to declarative, schema-driven approach. The goal is to improve maintainability and extensibility while preserving our excellent error messages and helper system integration.**

---

## 1 Executive Summary

### 1.1 Current State Analysis

**Strengths of Current Validation:**
- Excellent, contextual error messages ("resource 'editor': invalid tag specification: negative tag offsets not supported")
- Seamless integration with helper system
- Domain-specific validation (tag specifications, resource types)
- Good performance with no framework overhead
- Comprehensive test coverage

**Areas for Improvement:**
- **Imperative validation logic**: Hard to maintain and extend
- **Scattered validation rules**: Logic spread across multiple modules
- **Duplicate validation patterns**: Similar validation repeated in different helpers
- **Limited reusability**: Difficult to compose validation rules

### 1.2 Schema-Driven Vision

Transform our validation into a **declarative, schema-driven system** that:
- Defines validation rules as data structures, not code
- Maintains excellent error messages and contextual feedback
- Preserves helper system integration
- Enables easy composition and reuse of validation patterns
- Supports gradual migration without breaking changes

---

## 2 Architecture Overview

### 2.1 High-Level Design

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   DSL Schema    │    │  Helper Schema  │    │ Custom Validators│
│   Definition    │    │   Definitions   │    │    Registry     │
└─────┬───────────┘    └─────┬───────────┘    └─────┬───────────┘
      │                      │                      │
      └──────────┬───────────┴──────────────────────┘
                 │
         ┌───────▼────────┐
         │ Schema Validator│
         │     Engine      │
         └───────┬────────┘
                 │
    ┌────────────▼─────────────┐
    │    Validation Results    │
    │  (Success + Data) or     │
    │  (Failure + Errors)      │
    └──────────────────────────┘
```

### 2.2 Core Components

| Component | Responsibility | Dependencies |
|-----------|---------------|--------------|
| **Schema Definition System** | Define validation rules declaratively | None |
| **Schema Validator Engine** | Execute validation against schemas | Schema definitions |
| **Custom Validator Registry** | Handle domain-specific validation | tag_spec, helpers |
| **DSL Schema** | Complete DSL validation rules | All schemas |
| **Helper Schemas** | Resource-specific validation rules | Schema system |

---

## 3 Schema Definition System

### 3.1 Schema Definition API

```lua
-- lua/dsl/schema.lua
local schema = {}

-- Basic field definition
function schema.field(spec)
  return {
    required = spec.required or false,
    type = spec.type,                    -- "string", "number", "table", or {"string", "number"}
    validator = spec.validator,          -- Custom validator function name
    min_length = spec.min_length,        -- For strings
    max_length = spec.max_length,        -- For strings
    min_value = spec.min_value,          -- For numbers
    max_value = spec.max_value,          -- For numbers
    pattern = spec.pattern,              -- Lua pattern for strings
    one_of = spec.one_of,               -- Array of allowed values
    error = spec.error,                  -- Custom error message
    default = spec.default,              -- Default value if nil
    transform = spec.transform           -- Transform function
  }
end

-- Object schema definition
function schema.object(fields)
  return {
    type = "object",
    fields = fields
  }
end

-- Array schema definition
function schema.array(item_schema)
  return {
    type = "array", 
    items = item_schema,
    min_items = spec.min_items,
    max_items = spec.max_items
  }
end

-- Custom validator reference
function schema.validator(name)
  return { type = "validator", name = name }
end

-- Schema composition
function schema.extend(base_schema, additional_fields)
  local extended = {}
  for k, v in pairs(base_schema.fields) do
    extended[k] = v
  end
  for k, v in pairs(additional_fields) do
    extended[k] = v
  end
  return schema.object(extended)
end
```

### 3.2 DSL Schema Definition

```lua
-- lua/dsl/schemas/dsl_schema.lua
local schema = require("dsl.schema")

return schema.object({
  name = schema.field({
    required = true,
    type = "string", 
    min_length = 1,
    pattern = "^[a-zA-Z][a-zA-Z0-9_-]*$",
    error = "project name is required and must be a valid identifier"
  }),
  
  resources = schema.field({
    required = true,
    type = "table",
    validator = "validate_resources",
    error = "resources table is required with at least one resource"
  }),
  
  hooks = schema.field({
    type = "object",
    fields = {
      start = schema.field({
        type = "string",
        min_length = 1,
        error = "hooks.start must be a non-empty string"
      }),
      stop = schema.field({
        type = "string", 
        min_length = 1,
        error = "hooks.stop must be a non-empty string"
      })
    },
    validator = "validate_hooks_allowed_fields"
  }),
  
  layouts = schema.field({
    type = "object",
    validator = "validate_layouts"
  })
})
```

### 3.3 Helper Schema Examples

```lua
-- lua/dsl/schemas/app_schema.lua
local schema = require("dsl.schema")

return schema.object({
  cmd = schema.field({
    required = true,
    type = "string",
    min_length = 1,
    error = "cmd field is required and cannot be empty"
  }),
  
  dir = schema.field({
    type = "string",
    error = "dir must be a string"
  }),
  
  tag = schema.field({
    type = {"number", "string"},
    validator = "validate_tag_spec", 
    default = 0,
    error = "tag must be a number or string"
  }),
  
  reuse = schema.field({
    type = "boolean",
    default = false,
    error = "reuse must be a boolean"
  })
})

-- lua/dsl/schemas/common.lua - Shared schema components
local schema = require("dsl.schema")

return {
  -- Base resource schema that all helpers extend
  resource_base = schema.object({
    type = schema.field({
      required = true,
      type = "string",
      error = "resource type is required"
    })
  }),
  
  -- Common tag field used by all helpers
  tag_field = schema.field({
    type = {"number", "string"},
    validator = "validate_tag_spec",
    default = 0,
    error = "tag must be a number, string digit, or named string"
  }),
  
  -- Common directory field
  dir_field = schema.field({
    type = "string",
    error = "dir must be a string path"
  }),
  
  -- Common reuse field
  reuse_field = schema.field({
    type = "boolean",
    default = false,
    error = "reuse must be a boolean"
  })
}
```

---

## 4 Schema Validator Engine

### 4.1 Core Validation Engine  

```lua
-- lua/dsl/schema_validator.lua
local schema_validator = {}

-- Registry for custom validator functions
local custom_validators = {}

function schema_validator.register_validators(validators)
  for name, func in pairs(validators) do
    custom_validators[name] = func
  end
end

function schema_validator.validate(data, schema, context)
  context = context or { path = "", data = data }
  
  if schema.type == "object" then
    return validate_object(data, schema, context)
  elseif schema.type == "array" then
    return validate_array(data, schema, context) 
  elseif schema.type == "validator" then
    return call_custom_validator(data, schema.name, context)
  else
    return validate_field(data, schema, context)
  end
end

local function validate_object(data, schema, context)
  -- Validate data is table
  if type(data) ~= "table" then
    local error_msg = schema.error or (context.path .. " must be a table")
    return false, error_msg
  end
  
  local errors = {}
  local result = {}
  
  -- Validate each field in schema
  for field_name, field_schema in pairs(schema.fields) do
    local field_path = context.path == "" and field_name or context.path .. "." .. field_name
    local field_context = { 
      path = field_path, 
      data = context.data,
      parent = data
    }
    
    local value = data[field_name]
    local success, error_or_result = schema_validator.validate(value, field_schema, field_context)
    
    if success then
      if error_or_result ~= nil then  -- Preserve nil values
        result[field_name] = error_or_result
      end
    else
      table.insert(errors, error_or_result)
    end
  end
  
  -- Validate no unknown fields (optional strict mode)
  if schema.strict then
    for field_name, _ in pairs(data) do
      if not schema.fields[field_name] then
        table.insert(errors, "unknown field: " .. context.path .. "." .. field_name)
      end
    end
  end
  
  if #errors > 0 then
    return false, table.concat(errors, "; ")
  end
  
  return true, result
end

local function validate_field(data, field_schema, context)
  -- Required validation
  if field_schema.required and (data == nil or data == "") then
    local error_msg = field_schema.error or (context.path .. " is required")
    return false, error_msg
  end
  
  -- Apply default if needed
  if data == nil and field_schema.default ~= nil then
    data = field_schema.default
  end
  
  -- Skip further validation for nil optional fields
  if data == nil then
    return true, data
  end
  
  -- Type validation
  if field_schema.type then
    local success, error_msg = validate_type(data, field_schema.type, field_schema, context)
    if not success then
      return false, error_msg
    end
  end
  
  -- String-specific validations
  if type(data) == "string" then
    local success, error_msg = validate_string_constraints(data, field_schema, context)
    if not success then
      return false, error_msg
    end
  end
  
  -- Number-specific validations
  if type(data) == "number" then
    local success, error_msg = validate_number_constraints(data, field_schema, context)
    if not success then
      return false, error_msg
    end
  end
  
  -- Value constraints (one_of)
  if field_schema.one_of then
    local valid = false
    for _, allowed_value in ipairs(field_schema.one_of) do
      if data == allowed_value then
        valid = true
        break
      end
    end
    if not valid then
      local error_msg = field_schema.error or (context.path .. " must be one of: " .. table.concat(field_schema.one_of, ", "))
      return false, error_msg
    end
  end
  
  -- Custom validation
  if field_schema.validator then
    local success, error_or_result = call_custom_validator(data, field_schema.validator, context)
    if not success then
      return false, error_or_result
    end
    data = error_or_result  -- Custom validator may transform data
  end
  
  -- Transform data if needed
  if field_schema.transform then  
    data = field_schema.transform(data)
  end
  
  return true, data
end

local function validate_type(data, expected_types, field_schema, context)
  local types = type(expected_types) == "table" and expected_types or {expected_types}
  
  for _, expected_type in ipairs(types) do
    if type(data) == expected_type then
      return true
    end
  end
  
  local type_str = table.concat(types, " or ")
  local error_msg = field_schema.error or (context.path .. " must be " .. type_str .. ", got " .. type(data))
  return false, error_msg
end

local function validate_string_constraints(data, field_schema, context)
  if field_schema.min_length and #data < field_schema.min_length then
    local error_msg = field_schema.error or (context.path .. " must be at least " .. field_schema.min_length .. " characters")
    return false, error_msg
  end
  
  if field_schema.max_length and #data > field_schema.max_length then
    local error_msg = field_schema.error or (context.path .. " must be at most " .. field_schema.max_length .. " characters")
    return false, error_msg
  end
  
  if field_schema.pattern and not data:match(field_schema.pattern) then
    local error_msg = field_schema.error or (context.path .. " has invalid format")
    return false, error_msg
  end
  
  return true
end

local function validate_number_constraints(data, field_schema, context)
  if field_schema.min_value and data < field_schema.min_value then
    local error_msg = field_schema.error or (context.path .. " must be at least " .. field_schema.min_value)
    return false, error_msg
  end
  
  if field_schema.max_value and data > field_schema.max_value then
    local error_msg = field_schema.error or (context.path .. " must be at most " .. field_schema.max_value)
    return false, error_msg
  end
  
  return true
end

local function call_custom_validator(data, validator_name, context)
  local validator_func = custom_validators[validator_name]
  if not validator_func then
    error("Unknown validator: " .. validator_name)
  end
  
  return validator_func(data, context)
end

return schema_validator
```

### 4.2 Custom Validator Registry

```lua
-- lua/dsl/custom_validators.lua
local tag_spec = require("dsl.tag_spec")
local helpers = require("dsl.helpers.init")

local custom_validators = {}

function custom_validators.validate_tag_spec(value, context)
  local success, error_msg = tag_spec.validate(value)
  if not success then
    return false, "invalid tag specification: " .. error_msg
  end
  return true, value
end

function custom_validators.validate_resources(resources, context)
  if type(resources) ~= "table" then
    return false, "resources must be a table"
  end
  
  -- Check for empty resources
  local count = 0
  for _ in pairs(resources) do count = count + 1 end
  if count == 0 then
    return false, "at least one resource is required"
  end
  
  -- Validate each resource
  local validated_resources = {}
  for resource_name, resource_spec in pairs(resources) do
    if type(resource_spec) ~= "table" then
      return false, "resource '" .. resource_name .. "' must be a table"
    end
    
    if not resource_spec.type then
      return false, "resource '" .. resource_name .. "' must have a type field"
    end
    
    -- Use helper-specific validation
    local success, error_msg = helpers.validate_resource(resource_spec, resource_spec.type)
    if not success then
      return false, "resource '" .. resource_name .. "': " .. error_msg
    end
    
    validated_resources[resource_name] = resource_spec
  end
  
  return true, validated_resources
end

function custom_validators.validate_hooks_allowed_fields(hooks, context)
  -- Validate only known hook types are used
  local valid_hooks = { start = true, stop = true }
  for hook_name, _ in pairs(hooks) do
    if not valid_hooks[hook_name] then
      return false, "unknown hook type: " .. hook_name .. " (valid: start, stop)"
    end
  end
  
  return true, hooks
end

function custom_validators.validate_layouts(layouts, context)
  -- Future implementation for layouts validation
  if type(layouts) ~= "table" then
    return false, "layouts must be a table"
  end
  
  local count = 0
  for layout_name, layout_spec in pairs(layouts) do
    count = count + 1
    
    if type(layout_name) ~= "string" or layout_name == "" then
      return false, "layout name must be a non-empty string"
    end
    
    if type(layout_spec) ~= "table" then
      return false, "layout '" .. layout_name .. "' must be a table"
    end
  end
  
  if count == 0 then
    return false, "at least one layout is required if layouts table is present"
  end
  
  return true, layouts
end

return custom_validators
```

---

## 5 Integration & Migration Strategy

### 5.1 Updated DSL Validator

```lua
-- lua/dsl/validator.lua (updated)
local schema_validator = require("dsl.schema_validator")
local dsl_schema = require("dsl.schemas.dsl_schema")
local custom_validators = require("dsl.custom_validators")

local validator = {}

-- Register custom validators
schema_validator.register_validators(custom_validators)

---Validate DSL structure using schema-driven approach
---@param dsl table DSL table to validate
---@return boolean success True if validation passed
---@return string|nil error Error message if validation failed
function validator.validate_dsl(dsl)
  return schema_validator.validate(dsl, dsl_schema)
end

-- Backwards compatibility functions for gradual migration
function validator.validate_resources(resources)
  return custom_validators.validate_resources(resources, { path = "resources" })
end

function validator.validate_hooks(hooks)
  local hooks_schema = require("dsl.schemas.dsl_schema").fields.hooks
  return schema_validator.validate(hooks, hooks_schema, { path = "hooks" })
end

function validator.validate_layouts(layouts)
  return custom_validators.validate_layouts(layouts, { path = "layouts" })
end

-- Keep existing get_validation_summary for CLI integration
function validator.get_validation_summary(dsl)
  local summary = {
    project_name = dsl and dsl.name or "unknown",
    resource_count = 0,
    resources = {},
    has_hooks = false,
    has_layouts = false,
    valid = false,
    errors = {}
  }

  if not dsl then
    table.insert(summary.errors, "DSL is nil")
    return summary
  end

  -- Use new schema validation for overall validation
  local success, error_msg = validator.validate_dsl(dsl)
  summary.valid = success
  if not success then
    table.insert(summary.errors, error_msg)
  end

  -- Count resources and validate each (for detailed summary)
  if dsl.resources and type(dsl.resources) == "table" then
    for resource_name, resource_spec in pairs(dsl.resources) do
      summary.resource_count = summary.resource_count + 1
      
      local resource_info = {
        name = resource_name,
        type = resource_spec and resource_spec.type or "unknown",
        valid = false,
        error = nil
      }
      
      if resource_spec and resource_spec.type then
        local helpers = require("dsl.helpers.init")
        local res_success, res_error = helpers.validate_resource(resource_spec, resource_spec.type)
        resource_info.valid = res_success
        resource_info.error = res_error
      end
      
      table.insert(summary.resources, resource_info)
    end
  end

  summary.has_hooks = (dsl.hooks ~= nil)
  summary.has_layouts = (dsl.layouts ~= nil)

  return summary
end

return validator
```

### 5.2 Updated Helper System

```lua
-- lua/dsl/helpers/app.lua (updated)
local schema_validator = require("dsl.schema_validator")
local app_schema = require("dsl.schemas.app_schema")

local app_helper = {}

-- Keep existing schema table for backwards compatibility
app_helper.schema = {
  required = {"cmd"},
  optional = {"dir", "tag", "reuse"},
  types = {
    cmd = "string",
    dir = "string",
    tag = {"number", "string"},
    reuse = "boolean"
  },
  defaults = {
    tag = 0,
    reuse = false
  }
}

function app_helper.validate(spec)
  return schema_validator.validate(spec, app_schema)
end

function app_helper.create(spec)
  -- Validation is now handled by schema system
  -- This function assumes spec is already validated
  return {
    type = "app",
    cmd = spec.cmd,
    dir = spec.dir,
    tag = spec.tag or app_helper.schema.defaults.tag,
    reuse = spec.reuse or app_helper.schema.defaults.reuse
  }
end

function app_helper.describe(spec)
  if not spec or not spec.cmd then
    return "invalid app spec"
  end

  local parts = {"app: " .. spec.cmd}

  if spec.dir then
    table.insert(parts, "dir: " .. spec.dir)
  end

  if spec.tag then
    local tag_spec = require("dsl.tag_spec")
    local tag_success, tag_info = tag_spec.parse(spec.tag)
    if tag_success then
      table.insert(parts, "tag: " .. tag_spec.describe(tag_info))
    else
      table.insert(parts, "tag: invalid")
    end
  end

  if spec.reuse then
    table.insert(parts, "reuse: true")
  end

  return table.concat(parts, ", ")
end

return app_helper
```

### 5.3 Helper Registry Integration

```lua
-- lua/dsl/helpers/init.lua (updated)  
local schema_validator = require("dsl.schema_validator")

local helpers = {}

-- Existing registry and functions remain the same...
local registry = {}
local app_helper = require("dsl.helpers.app")

registry.app = function(spec)
  return app_helper.create(spec)
end

-- Updated validation function using schemas
function helpers.validate_resource(resource_spec, resource_type)
  if resource_type == "app" then
    return app_helper.validate(resource_spec)
  end
  
  -- Future helpers will be added here with their own schemas
  -- if resource_type == "term" then
  --   local term_helper = require("dsl.helpers.term")
  --   return term_helper.validate(resource_spec)
  -- end
  
  return false, "unknown resource type: " .. tostring(resource_type)
end

-- Enhanced schema retrieval
function helpers.get_schema(name)
  if name == "app" then
    return require("dsl.schemas.app_schema")
  end
  
  -- Future helper schemas
  -- if name == "term" then
  --   return require("dsl.schemas.term_schema")
  -- end
  
  return nil
end

-- All other existing functions remain unchanged...

return helpers
```

---

## 6 Enhanced Features

### 6.1 Schema Composition & Reuse

```lua
-- lua/dsl/schemas/browser_schema.lua - Example of schema composition
local schema = require("dsl.schema")
local common = require("dsl.schemas.common")

-- Extend common resource base with browser-specific fields
return schema.extend(common.resource_base, {
  urls = schema.field({
    type = "table",
    required = true,
    validator = "validate_url_list",
    error = "urls must be a non-empty array of valid URLs"
  }),
  
  window = schema.field({
    type = "string",
    one_of = {"new", "reuse"},
    default = "new",
    error = "window must be 'new' or 'reuse'"
  }),
  
  tag = common.tag_field,  -- Reuse common tag field definition
  reuse = common.reuse_field  -- Reuse common reuse field definition
})

-- lua/dsl/schemas/term_schema.lua - Another composition example
local schema = require("dsl.schema")
local common = require("dsl.schemas.common")

return schema.extend(common.resource_base, {
  cmd = schema.field({
    type = "string",
    default = "",  -- Empty string for plain terminal
    error = "cmd must be a string"
  }),
  
  interactive = schema.field({
    type = "boolean", 
    default = true,
    error = "interactive must be a boolean"
  }),
  
  dir = common.dir_field,
  tag = common.tag_field,
  reuse = common.reuse_field
})
```

### 6.2 Conditional & Contextual Validation

```lua
-- Example: Browser helper with conditional validation
local browser_validators = {
  validate_url_list = function(urls, context)
    if type(urls) ~= "table" then
      return false, "urls must be a table"
    end
    
    if #urls == 0 then
      return false, "at least one URL is required"
    end
    
    -- Validate each URL
    for i, url in ipairs(urls) do
      if type(url) ~= "string" or url == "" then
        return false, "URL " .. i .. " must be a non-empty string"
      end
      
      -- Basic URL validation
      if not url:match("^https?://") then
        return false, "URL " .. i .. " must start with http:// or https://"
      end
    end
    
    return true, urls
  end,
  
  validate_browser_window_urls = function(data, context)
    -- Conditional validation: if window="new", URLs are required
    if context.parent.window == "new" and #data == 0 then
      return false, "URLs required when opening new browser window"
    end
    
    return true, data
  end
}
```

### 6.3 Schema Validation Utilities

```lua
-- lua/dsl/schema_utils.lua - Utilities for working with schemas
local schema_utils = {}

function schema_utils.merge_schemas(schema1, schema2)
  -- Deep merge two schemas
  local merged = { fields = {} }
  
  for field, spec in pairs(schema1.fields or {}) do
    merged.fields[field] = spec
  end
  
  for field, spec in pairs(schema2.fields or {}) do
    merged.fields[field] = spec
  end
  
  return merged
end

function schema_utils.extract_required_fields(schema)
  local required = {}
  for field_name, field_spec in pairs(schema.fields or {}) do
    if field_spec.required then
      table.insert(required, field_name)
    end
  end
  return required
end

function schema_utils.extract_optional_fields(schema)
  local optional = {}
  for field_name, field_spec in pairs(schema.fields or {}) do
    if not field_spec.required then
      table.insert(optional, field_name)
    end
  end
  return optional
end

function schema_utils.validate_schema_definition(schema)
  -- Validate that a schema definition itself is correct
  if type(schema) ~= "table" then
    return false, "schema must be a table"
  end
  
  if schema.type == "object" and not schema.fields then
    return false, "object schemas must have fields"
  end
  
  -- More validation rules for schema definitions...
  
  return true
end

return schema_utils
```

---

## 7 Testing Framework

### 7.1 Schema Testing Utilities

```lua
-- spec/dsl/schema_test_utils.lua
local schema_validator = require("dsl.schema_validator")

local schema_test_utils = {}

function schema_test_utils.test_schema_validation(schema, test_cases)
  for _, case in ipairs(test_cases.valid or {}) do
    local success, result = schema_validator.validate(case.input, schema)
    if not success then
      error("Expected valid case '" .. case.description .. "' to pass, but got error: " .. tostring(result))
    end
    
    -- Optionally check expected output
    if case.expected_output then
      assert.are.same(case.expected_output, result, "Output mismatch for: " .. case.description)
    end
  end
  
  for _, case in ipairs(test_cases.invalid or {}) do
    local success, error_msg = schema_validator.validate(case.input, schema)
    if success then
      error("Expected invalid case '" .. case.description .. "' to fail, but it passed")
    end
    
    -- Optionally check expected error message
    if case.expected_error then
      if not error_msg:match(case.expected_error) then
        error("Expected error matching '" .. case.expected_error .. "' but got: " .. tostring(error_msg))
      end
    end
  end
end

function schema_test_utils.create_test_cases(valid_cases, invalid_cases)
  return {
    valid = valid_cases or {},
    invalid = invalid_cases or {}
  }
end

return schema_test_utils
```

### 7.2 Schema Test Examples

```lua
-- spec/dsl/schemas/app_schema_spec.lua
local assert = require("luassert")
local app_schema = require("dsl.schemas.app_schema") 
local schema_test_utils = require("spec.dsl.schema_test_utils")

describe("dsl.schemas.app_schema", function()
  it("should validate according to schema", function()
    local test_cases = schema_test_utils.create_test_cases(
      -- Valid cases
      {
        {
          description = "minimal valid app",
          input = { cmd = "gedit" },
          expected_output = { cmd = "gedit", tag = 0, reuse = false }
        },
        {
          description = "complete app spec",
          input = { 
            cmd = "zed /path/to/project", 
            dir = "/path/to/project",
            tag = 1,
            reuse = true
          }
        },
        {
          description = "app with string tag",
          input = { cmd = "firefox", tag = "browser" }
        }
      },
      -- Invalid cases  
      {
        {
          description = "missing cmd field",
          input = { dir = "/tmp", tag = 0 },
          expected_error = "cmd field is required"
        },
        {
          description = "invalid cmd type",
          input = { cmd = 123 },
          expected_error = "cmd field is required"
        },
        {
          description = "invalid tag type", 
          input = { cmd = "test", tag = true },
          expected_error = "tag must be a number or string"
        }
      }
    )
    
    schema_test_utils.test_schema_validation(app_schema, test_cases)
  end)
end)
```

---

## 8 Performance & Error Message Quality

### 8.1 Performance Considerations

**Schema Validation Performance:**
- **Compilation**: Schemas are data structures, no compilation needed
- **Validation Speed**: Single pass through data with early exit on errors
- **Memory Usage**: Minimal overhead compared to current approach
- **Caching**: Schema objects can be cached and reused

**Benchmarking Plan:**
```lua
-- Performance comparison between old and new validation
local function benchmark_validation()
  local dsl_data = load_sample_dsl()
  
  -- Current approach
  local start = os.clock()
  for i = 1, 1000 do
    old_validator.validate_dsl(dsl_data)
  end
  local old_time = os.clock() - start
  
  -- Schema approach  
  local start = os.clock()
  for i = 1, 1000 do
    schema_validator.validate(dsl_data, dsl_schema)
  end
  local new_time = os.clock() - start
  
  print("Old approach: " .. old_time .. "s")
  print("New approach: " .. new_time .. "s")
end
```

### 8.2 Error Message Quality

**Maintaining Excellent Error Messages:**

```lua
-- Current error message quality (preserved):
"resource 'editor': invalid tag specification: negative tag offsets not supported in v1.0"

-- Schema-driven error messages (equally good):
"resource 'editor': invalid tag specification: negative tag offsets not supported in v1.0"

-- Error message composition:
context.path = "resources.editor"
field_error = "invalid tag specification: negative tag offsets not supported in v1.0" 
final_error = "resource 'editor': " .. field_error
```

**Error Context Enhancement:**
```lua
local function format_field_error(context, error_msg)
  if context.path:match("^resources%.") then
    local resource_name = context.path:match("^resources%.([^%.]+)")
    return "resource '" .. resource_name .. "': " .. error_msg
  end
  
  return context.path .. ": " .. error_msg
end
```

---

## 9 Benefits Analysis

### 9.1 Advantages of Schema-Driven Approach

| Aspect | Current Imperative | New Schema-Driven | Improvement |
|--------|-------------------|-------------------|-------------|
| **Maintainability** | Scattered validation logic | Centralized schema definitions | ✅ Much easier to modify rules |
| **Extensibility** | Manual code for each rule | Declarative rule composition | ✅ Add rules without coding |
| **Consistency** | Rules vary by implementation | Uniform validation patterns | ✅ Consistent behavior |
| **Testing** | Test validation code | Test schema definitions | ✅ Easier to test declaratively |
| **Documentation** | Code comments | Self-documenting schemas | ✅ Schemas are documentation |
| **Reusability** | Copy-paste validation code | Compose and extend schemas | ✅ DRY principle |
| **Error Quality** | Custom error messages | Custom error messages preserved | ✅ No degradation |
| **Performance** | Direct function calls | Schema interpretation | 〰️ Similar performance |

### 9.2 Preserved Strengths

**What We're NOT Losing:**
- ✅ **Excellent Error Messages**: Custom error messages fully preserved
- ✅ **Helper Integration**: Seamless integration with helper system maintained  
- ✅ **Domain Validation**: Custom validators for tag specs, resource types
- ✅ **Performance**: No significant performance impact
- ✅ **Test Coverage**: All existing functionality covered by tests
- ✅ **Backwards Compatibility**: Gradual migration without breaking changes

### 9.3 New Capabilities Gained

**Additional Benefits:**
- 🆕 **Schema Composition**: Reuse validation patterns across helpers
- 🆕 **Conditional Validation**: Validation rules that depend on other fields
- 🆕 **Data Transformation**: Apply transformations during validation
- 🆕 **Extensible Rules**: Easy to add new validation patterns
- 🆕 **Better Testing**: Declarative test cases for validation rules
- 🆕 **Self-Documentation**: Schemas serve as API documentation

---

## 10 Implementation Timeline

### 10.1 Development Phases

| Phase | Duration | Key Deliverables | Dependencies |
|-------|----------|-----------------|--------------|
| **Phase 1: Foundation** | 1 week | Schema system, DSL schema, app schema | Current validation system |
| **Phase 2: Engine** | 1 week | Schema validator engine, custom validators | Phase 1 |
| **Phase 3: Integration** | 1 week | Updated DSL validator, helper integration | Phase 2 |
| **Phase 4: Enhancement** | 1 week | Schema composition, conditional validation | Phase 3 |
| **Phase 5: Testing** | 1 week | Test framework, comprehensive test suite | Phase 4 |

### 10.2 Detailed Milestones

#### **Week 1 - Foundation**
- Day 1-2: Implement schema definition system (`lua/dsl/schema.lua`)
- Day 3-4: Create DSL schema definition (`lua/dsl/schemas/dsl_schema.lua`)
- Day 5: Create app schema and common schemas (`lua/dsl/schemas/`)

#### **Week 2 - Engine**
- Day 1-3: Implement schema validator engine (`lua/dsl/schema_validator.lua`)
- Day 4-5: Create custom validator registry (`lua/dsl/custom_validators.lua`)

#### **Week 3 - Integration**
- Day 1-2: Update DSL validator to use schemas (`lua/dsl/validator.lua`)
- Day 3-4: Update helper system integration (`lua/dsl/helpers/`)
- Day 5: Migration testing and backwards compatibility

#### **Week 4 - Enhancement**  
- Day 1-2: Implement schema composition utilities
- Day 3-4: Add conditional validation support
- Day 5: Performance optimization and testing

#### **Week 5 - Testing**
- Day 1-3: Create schema testing framework
- Day 4-5: Comprehensive test suite for all schemas

### 10.3 Risk Mitigation

**Potential Risks & Mitigation:**

| Risk | Probability | Impact | Mitigation Strategy |
|------|-------------|--------|-------------------|
| **Performance Regression** | Low | Medium | Early benchmarking, optimize hot paths |
| **Error Message Quality Loss** | Low | High | Preserve custom error messages, test error output |
| **Integration Complexity** | Medium | Medium | Gradual migration, maintain compatibility layer |
| **Test Migration Effort** | Medium | Low | Keep existing tests, add schema tests incrementally |

---

## 11 Success Criteria

### 11.1 Technical Success Metrics

- [ ] **All existing tests pass** without modification
- [ ] **Performance equivalent** to current implementation (±10%)
- [ ] **Error message quality maintained** - same level of helpfulness
- [ ] **100% feature parity** - all current validation rules work
- [ ] **Backwards compatibility** - existing code works unchanged
- [ ] **Schema test coverage** ≥90% for all schema definitions

### 11.2 Quality Metrics

- [ ] **Reduced code duplication** - validation logic centralized in schemas
- [ ] **Improved maintainability** - schema changes don't require code changes
- [ ] **Enhanced extensibility** - new helper types use schema composition
- [ ] **Better documentation** - schemas serve as validation API docs
- [ ] **Consistent validation** - uniform behavior across all components

### 11.3 User Experience Metrics  

- [ ] **Error messages remain excellent** - no degradation in helpfulness
- [ ] **Validation performance** - no noticeable slowdown
- [ ] **Helper integration seamless** - no changes to helper usage patterns
- [ ] **DSL syntax unchanged** - existing DSL files continue to work

---

## 12 Conclusion

This declarative validation architecture represents a significant improvement in maintainability and extensibility while preserving all the strengths of our current system. The schema-driven approach will make Diligent's validation system more robust, consistent, and easier to extend as we add new helper types and DSL features.

The implementation plan provides a clear path forward with manageable milestones and comprehensive risk mitigation. Upon completion, we'll have a modern, flexible validation system that serves as a solid foundation for future DSL enhancements.

---

### End of Document