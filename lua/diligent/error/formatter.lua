--[[
Enhanced Error Formatting Module

This module provides user-friendly error formatting functionality,
converting structured error reports into readable output for
different contexts (CLI, logs, etc.). Enhanced with tag resolution support.

Features:
- User-friendly error message formatting
- Multi-format output support (CLI, JSON, etc.)
- Tag resolution specific formatting
- Error grouping and categorization
--]]

local formatter_factory = {}

-- Format tag resolution error for CLI display
local function format_tag_error_for_cli(error_obj)
  if not error_obj then
    return "Unknown error occurred"
  end

  local lines = {}

  -- Main error line with resource and type
  local main_line = "  ✗ " .. (error_obj.resource_id or "unknown")

  if error_obj.type == "TAG_OVERFLOW" and error_obj.context then
    local ctx = error_obj.context
    if ctx.resolved_index and ctx.final_index then
      main_line = main_line
        .. ": Tag overflow ("
        .. ctx.resolved_index
        .. " → "
        .. ctx.final_index
        .. ")"
    else
      main_line = main_line .. ": " .. (error_obj.message or "Tag overflow")
    end
  else
    main_line = main_line .. ": " .. (error_obj.message or "Error occurred")
  end

  table.insert(lines, main_line)

  -- Add suggestions if available
  if error_obj.suggestions and #error_obj.suggestions > 0 then
    for _, suggestion in ipairs(error_obj.suggestions) do
      table.insert(lines, "    • " .. suggestion)
    end
  end

  return table.concat(lines, "\n")
end

-- Format multiple errors with grouping by phase
local function format_multiple_errors_for_cli(errors)
  if not errors or #errors == 0 then
    return "No errors to display"
  end

  local lines = {}

  -- Group errors by phase
  local phases = {}
  for _, error_entry in ipairs(errors) do
    local phase = error_entry.phase or "unknown"
    if not phases[phase] then
      phases[phase] = {}
    end
    table.insert(phases[phase], error_entry)
  end

  -- Format each phase group
  for phase, phase_errors in pairs(phases) do
    -- Phase header
    if phase == "tag_resolution" then
      table.insert(lines, "TAG RESOLUTION ERRORS:")
    elseif phase == "spawning" then
      table.insert(lines, "SPAWNING ERRORS:")
    else
      table.insert(lines, string.upper(phase) .. " ERRORS:")
    end

    -- Format each error in the phase
    for _, error_entry in ipairs(phase_errors) do
      -- Ensure the error object has the resource_id from the entry
      local error_obj = error_entry.error
      if error_entry.resource_id and not error_obj.resource_id then
        error_obj.resource_id = error_entry.resource_id
      end
      local formatted = format_tag_error_for_cli(error_obj)
      table.insert(lines, formatted)
    end

    table.insert(lines, "") -- Empty line between phases
  end

  -- Remove trailing empty line
  if lines[#lines] == "" then
    table.remove(lines)
  end

  return table.concat(lines, "\n")
end

-- Format partial success information for CLI
local function format_partial_success_for_cli(partial_success)
  if
    not partial_success
    or not partial_success.spawned_resources
    or #partial_success.spawned_resources == 0
  then
    return nil
  end

  local lines = { "PARTIAL SUCCESS:" }

  for _, resource in ipairs(partial_success.spawned_resources) do
    table.insert(
      lines,
      "  ✓ " .. resource.name .. " (PID: " .. resource.pid .. ")"
    )
  end

  return table.concat(lines, "\n")
end

-- Format dry-run warnings with context
local function format_dry_run_warnings(warnings)
  if not warnings or #warnings == 0 then
    return nil
  end

  local lines = { "WARNINGS:" }

  for _, warning in ipairs(warnings) do
    local warning_line = "  ⚠ " .. (warning.resource_id or "unknown")

    if warning.type == "overflow" then
      warning_line = warning_line .. ": Tag overflow detected"
      if warning.original_index and warning.final_index then
        warning_line = warning_line
          .. " ("
          .. warning.original_index
          .. " → "
          .. warning.final_index
          .. ")"
      end
    elseif warning.type == "tag_creation" then
      warning_line = warning_line
        .. ': Tag "'
        .. (warning.tag_name or "unknown")
        .. '" will be created'
    else
      warning_line = warning_line .. ": " .. (warning.message or "Warning")
    end

    table.insert(lines, warning_line)

    -- Add suggestion if available
    if warning.suggestion then
      table.insert(lines, "    Suggestion: " .. warning.suggestion)
    end
  end

  return table.concat(lines, "\n")
end

-- Format error report for user display (enhanced from original)
local function format_error_for_user(error_report)
  if not error_report then
    return "Unknown error occurred"
  end

  local lines = {}
  table.insert(
    lines,
    "✗ Failed to process "
      .. (error_report.resource_id or error_report.app_name or "resource")
  )

  if error_report.user_message then
    table.insert(lines, "  Error: " .. error_report.user_message)
  elseif error_report.message then
    table.insert(lines, "  Error: " .. error_report.message)
  end

  if error_report.suggestions and #error_report.suggestions > 0 then
    table.insert(lines, "  Suggestions:")
    for _, suggestion in ipairs(error_report.suggestions) do
      table.insert(lines, "    • " .. suggestion)
    end
  end

  return table.concat(lines, "\n")
end

-- Create formatter instance with dependency injection
function formatter_factory.create(interface)
  return {
    format_tag_error_for_cli = format_tag_error_for_cli,
    format_multiple_errors_for_cli = format_multiple_errors_for_cli,
    format_partial_success_for_cli = format_partial_success_for_cli,
    format_dry_run_warnings = format_dry_run_warnings,
    format_error_for_user = format_error_for_user,
  }
end

return formatter_factory
