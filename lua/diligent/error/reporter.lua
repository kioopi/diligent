--[[
Enhanced Error Reporting Module

This module provides comprehensive error reporting functionality,
including structured error reports, error aggregation, and
actionable suggestions for users. Enhanced with tag resolution support.

Features:
- Structured error report generation
- Error suggestion system with actionable advice
- Tag resolution error handling
- Error aggregation support
--]]

local reporter_factory = {}

-- Get actionable suggestions for error types
local function get_error_suggestions(error_type, context)
  local classifier = require("diligent.error.classifier").create()
  local ERROR_TYPES = classifier.ERROR_TYPES

  context = context or {}

  if error_type == "TAG_OVERFLOW" or error_type == ERROR_TYPES.TAG_OVERFLOW then
    local suggestions = {
      'Consider using absolute tag specification (e.g., "9")',
    }
    if context.resolved_index then
      table.insert(
        suggestions,
        "Check if relative offset +"
          .. (context.resolved_index - (context.base_tag or 1))
          .. " was intended"
      )
    end
    return suggestions
  elseif
    error_type == "TAG_SPEC_INVALID"
    or error_type == ERROR_TYPES.TAG_SPEC_INVALID
  then
    return {
      "Provide tag as number (relative offset) or string (absolute/named)",
      "Check DSL syntax for tag specification",
      'Valid examples: tag = 2 (relative), tag = "3" (absolute), tag = "editor" (named)',
    }
  elseif
    error_type == "TAG_NAME_INVALID"
    or error_type == ERROR_TYPES.TAG_NAME_INVALID
  then
    return {
      "Tag names must start with a letter",
      "Use only letters, numbers, underscore, or dash in tag names",
      'Valid examples: "editor", "workspace-1", "dev_environment"',
    }
  elseif error_type == ERROR_TYPES.COMMAND_NOT_FOUND then
    local app_name = context.app_name or "application"
    return {
      "Check if '" .. app_name .. "' is installed",
      "Verify the command name is spelled correctly",
      "Add the application's directory to your PATH",
    }
  elseif error_type == ERROR_TYPES.PERMISSION_DENIED then
    return {
      "Check file permissions for the executable",
      "Ensure you have execute permissions",
      "Try running with appropriate privileges",
    }
  elseif error_type == ERROR_TYPES.INVALID_COMMAND then
    return {
      "Provide a valid command to execute",
      "Check command syntax",
      "Ensure command is not empty",
    }
  elseif error_type == ERROR_TYPES.TIMEOUT then
    return {
      "Increase timeout value for slow-starting applications",
      "Check if application started but didn't create a window",
      "Try spawning manually to test behavior",
    }
  elseif error_type == ERROR_TYPES.TAG_RESOLUTION_FAILED then
    return {
      'Check tag specification format (0, +N, -N, N, or "name")',
      "Ensure target tag exists or can be created",
      "Verify screen has available tag slots",
    }
  else
    return {
      "Check application logs for more details",
      "Try spawning the application manually",
      "Report this issue if problem persists",
    }
  end
end

-- Create structured tag resolution error object
local function create_tag_resolution_error(
  resource_id,
  tag_spec,
  error_type,
  message,
  context
)
  context = context or {}

  local error_obj = {
    category = "TAG_RESOLUTION_ERROR",
    resource_id = resource_id,
    tag_spec = tag_spec,
    type = error_type,
    message = message,
    context = context,
    suggestions = get_error_suggestions(error_type, context),
    metadata = {
      timestamp = os.time(),
      phase = "planning",
    },
  }

  return error_obj
end

-- Aggregate multiple errors into single error object
local function aggregate_errors(errors)
  if not errors or #errors == 0 then
    return nil
  end

  if #errors == 1 then
    return errors[1]
  end

  -- Count error types for summary
  local error_type_counts = {}
  for _, error in ipairs(errors) do
    local error_type = error.type or "UNKNOWN"
    error_type_counts[error_type] = (error_type_counts[error_type] or 0) + 1
  end

  -- Create summary message
  local summary_parts = { tostring(#errors) .. " errors occurred:" }
  for error_type, count in pairs(error_type_counts) do
    if count == 1 then
      table.insert(summary_parts, error_type)
    else
      table.insert(summary_parts, count .. "x " .. error_type)
    end
  end

  local aggregated = {
    type = "MULTIPLE_TAG_ERRORS",
    category = "TAG_RESOLUTION_ERROR",
    message = table.concat(summary_parts, ", "),
    errors = errors,
    metadata = {
      timestamp = os.time(),
      error_count = #errors,
      error_types = error_type_counts,
    },
  }

  return aggregated
end

-- Aggregate multiple spawn results into comprehensive report (enhanced from original)
local function create_spawn_summary(spawn_results)
  local classifier = require("diligent.error.classifier").create()
  local ERROR_TYPES = classifier.ERROR_TYPES

  local summary = {
    timestamp = os.time(),
    total_attempts = #spawn_results,
    successful = 0,
    failed = 0,
    results = spawn_results,
    error_types = {},
    recommendations = {},
  }

  -- Analyze results
  for _, result in ipairs(spawn_results) do
    if result.success then
      summary.successful = summary.successful + 1
    else
      summary.failed = summary.failed + 1

      -- Count error types
      local error_type = result.error_report and result.error_report.type
        or "UNKNOWN"
      summary.error_types[error_type] = (summary.error_types[error_type] or 0)
        + 1
    end
  end

  -- Generate recommendations based on error patterns
  if summary.error_types[ERROR_TYPES.COMMAND_NOT_FOUND] then
    table.insert(
      summary.recommendations,
      "Some applications may not be installed"
    )
  end
  if summary.error_types[ERROR_TYPES.PERMISSION_DENIED] then
    table.insert(
      summary.recommendations,
      "Permission issues detected - check file permissions"
    )
  end
  if summary.error_types[ERROR_TYPES.TAG_OVERFLOW] then
    table.insert(
      summary.recommendations,
      "Tag overflow detected - consider using absolute tag specifications"
    )
  end
  if summary.error_types[ERROR_TYPES.TAG_SPEC_INVALID] then
    table.insert(
      summary.recommendations,
      "Invalid tag specifications found - check DSL syntax"
    )
  end
  if summary.failed > summary.successful then
    table.insert(
      summary.recommendations,
      "Consider reviewing project configuration"
    )
  end

  summary.success_rate = summary.total_attempts > 0
      and (summary.successful / summary.total_attempts)
    or 0

  return summary
end

-- Create reporter instance with dependency injection
function reporter_factory.create(interface)
  return {
    create_tag_resolution_error = create_tag_resolution_error,
    aggregate_errors = aggregate_errors,
    get_error_suggestions = get_error_suggestions,
    create_spawn_summary = create_spawn_summary,
  }
end

return reporter_factory
