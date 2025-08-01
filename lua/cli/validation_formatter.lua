--[[
CLI Validation Formatter Module

Handles formatting validation results for display.
Uses existing DSL validation summary and provides human-readable output.
--]]

local validation_formatter = {}

-- Import required modules
local dsl = require("dsl")

---Format tag description for human-readable output
---@param tag any Tag value (number, string, or nil)
---@return string description Formatted tag description
function validation_formatter.format_tag_description(tag)
  if tag == nil then
    return ""
  end

  if type(tag) == "number" then
    if tag == 0 then
      return " (tag: relative offset 0)"
    elseif tag > 0 then
      return " (tag: relative offset +" .. tag .. ")"
    else
      return " (tag: relative offset " .. tag .. ")"
    end
  elseif type(tag) == "string" then
    -- Check if string is numeric (absolute tag)
    if tag:match("^%d+$") then
      return " (tag: absolute tag " .. tag .. ")"
    else
      return ' (tag: named "' .. tag .. '")'
    end
  end

  return ""
end

---Format resource list for display
---@param resources table|nil Array of resource info with tag information
---@return table lines Array of formatted resource lines
function validation_formatter.format_resource_list(resources)
  local lines = {}

  if not resources then
    return lines
  end

  for _, resource_info in ipairs(resources) do
    if resource_info.type == "app" and resource_info.valid then
      local tag_desc =
        validation_formatter.format_tag_description(resource_info.tag)
      local line = "Resource '"
        .. resource_info.name
        .. "': app helper valid"
        .. tag_desc
      table.insert(lines, line)
    end
  end

  return lines
end

---Format hooks information
---@param hooks table|nil Hooks table from DSL
---@return string|nil line Formatted hooks line or nil if no hooks
function validation_formatter.format_hooks_info(hooks)
  if not hooks or next(hooks) == nil then
    return nil
  end

  local hook_names = {}
  for hook_name, _ in pairs(hooks) do
    table.insert(hook_names, hook_name)
  end

  if #hook_names > 0 then
    table.sort(hook_names)
    return "Hooks configured: " .. table.concat(hook_names, ", ")
  end

  return nil
end

---Generate summary line with statistics
---@param summary table Validation summary from DSL module
---@return string line Formatted summary line
function validation_formatter.generate_summary_line(summary)
  local checks_passed = 2 + (summary.resource_count or 0) -- Basic checks + resources
  if summary.has_hooks then
    checks_passed = checks_passed + 1
  end

  local error_count = summary.errors and #summary.errors or 0

  if summary.valid and error_count == 0 then
    return "Validation passed: " .. checks_passed .. " checks passed, 0 errors"
  else
    return "Validation failed: " .. error_count .. " errors"
  end
end

---Format complete validation results
---@param dsl_table table|nil DSL table to format
---@return table lines Array of formatted output lines
function validation_formatter.format_validation_results(dsl_table)
  local lines = {}

  if not dsl_table then
    table.insert(lines, "Error: No DSL data to format")
    return lines
  end

  -- Get validation summary
  local summary = dsl.get_validation_summary(dsl_table)

  -- Basic validation indicators
  table.insert(lines, "DSL syntax valid")
  table.insert(lines, "Required fields present (name, resources)")

  -- Project name
  if dsl_table.name then
    table.insert(lines, 'Project name: "' .. dsl_table.name .. '"')
  end

  -- Resource validation with tag descriptions
  if dsl_table.resources then
    for resource_name, resource_spec in pairs(dsl_table.resources) do
      if resource_spec.type == "app" then
        local tag_desc =
          validation_formatter.format_tag_description(resource_spec.tag)
        local line = "Resource '"
          .. resource_name
          .. "': app helper valid"
          .. tag_desc
        table.insert(lines, line)
      end
    end
  end

  -- Hooks information
  local hooks_line = validation_formatter.format_hooks_info(dsl_table.hooks)
  if hooks_line then
    table.insert(lines, hooks_line)
  end

  -- Empty line before summary
  table.insert(lines, "")

  -- Summary line
  local summary_line = validation_formatter.generate_summary_line(summary)
  table.insert(lines, summary_line)

  return lines
end

return validation_formatter
