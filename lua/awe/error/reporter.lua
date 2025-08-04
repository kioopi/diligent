--[[
Error Reporting Module

This module provides comprehensive error reporting functionality,
including structured error reports, error aggregation, and
actionable suggestions for users.

Features:
- Structured error report generation
- Error suggestion system with actionable advice
- Spawn summary creation and analysis
- Dependency injection support
--]]

local reporter_factory = {}

-- Create structured error report
local function create_error_report(app_name, tag_spec, error_message, context)
  context = context or {}

  local classifier = require("awe.error.classifier").create()
  local error_type, user_message = classifier.classify_error(error_message)

  return {
    timestamp = os.time(),
    app_name = app_name,
    tag_spec = tag_spec,
    error_type = error_type,
    original_message = error_message,
    user_message = user_message,
    context = context,
    suggestions = get_error_suggestions(error_type, app_name),
  }
end

-- Get actionable suggestions for error types
function get_error_suggestions(error_type, app_name)
  local classifier = require("awe.error.classifier").create()
  local ERROR_TYPES = classifier.ERROR_TYPES

  if error_type == ERROR_TYPES.COMMAND_NOT_FOUND then
    return {
      "Check if '" .. (app_name or "application") .. "' is installed",
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

-- Aggregate multiple spawn results into comprehensive report
local function create_spawn_summary(spawn_results)
  local classifier = require("awe.error.classifier").create()
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
      local error_type = result.error_report and result.error_report.error_type
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
  interface = interface or require("awe").interfaces.awesome_interface

  return {
    create_error_report = create_error_report,
    get_error_suggestions = get_error_suggestions,
    create_spawn_summary = create_spawn_summary,
  }
end

return reporter_factory
