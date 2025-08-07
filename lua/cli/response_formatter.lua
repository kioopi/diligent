--[[
CLI Response Formatter Module

Handles formatting of both enhanced and simple response formats from handlers.
Provides detection of response format types and appropriate formatting functions.
--]]

local response_formatter = {}

-- Import required modules
local formatter_factory = require("diligent.error.formatter")

---Detect whether a response is enhanced format or simple format
---@param response table Response object from handler
---@return string format_type "enhanced" or "simple" or "success"
function response_formatter.detect_response_format(response)
  if not response then
    return "simple"
  end

  -- Enhanced error format detection
  if response.error_type and response.errors and response.metadata then
    return "enhanced"
  end

  -- Simple error format detection
  if response.error and response.failed_resource then
    return "simple"
  end

  -- Success format detection
  if
    response.status == "success"
    or (response.spawned_resources and not response.error)
  then
    return "success"
  end

  -- Default to simple for unknown formats
  return "simple"
end

-- Create formatter instance once and reuse
local _formatter_instance = nil
local function get_formatter()
  if not _formatter_instance then
    _formatter_instance = formatter_factory.create(nil) -- Interface not needed for CLI formatting
  end
  return _formatter_instance
end

-- Helper function to build lines array and manage empty lines
local function build_output(sections)
  local lines = {}

  for i, section in ipairs(sections) do
    if section and section ~= "" then
      table.insert(lines, section)

      -- Add empty line after section (except for last section)
      if i < #sections then
        table.insert(lines, "")
      end
    end
  end

  -- Remove trailing empty line
  if lines[#lines] == "" then
    table.remove(lines)
  end

  return table.concat(lines, "\n")
end

-- Helper function to build error summary header
local function build_error_header(project_name, metadata)
  local header = "✗ Failed to start project: " .. (project_name or "unknown")

  if metadata then
    header = header .. " (" .. metadata.error_count .. " errors"
    if metadata.success_count > 0 then
      header = header .. ", " .. metadata.success_count .. " success"
    end
    header = header .. ")"
  end

  return header
end

---Format enhanced error response using rich error formatter
---@param response table Enhanced error response from handler
---@return string formatted_output Rich CLI formatted error display
function response_formatter.format_enhanced_error_response(response)
  local formatter = get_formatter()
  local sections = {}

  -- Header with project and error summary
  table.insert(
    sections,
    build_error_header(response.project_name, response.metadata)
  )

  -- Format errors using rich formatter
  if response.errors and #response.errors > 0 then
    local formatted_errors =
      formatter.format_multiple_errors_for_cli(response.errors)
    table.insert(sections, formatted_errors)
  end

  -- Format partial success if present
  if response.partial_success then
    local formatted_success =
      formatter.format_partial_success_for_cli(response.partial_success)
    if formatted_success then
      table.insert(sections, formatted_success)
    end
  end

  return build_output(sections)
end

---Format simple error response with basic formatting
---@param response table Simple error response from handler
---@return string formatted_output Basic CLI formatted error display
function response_formatter.format_simple_error_response(response)
  local lines = {}

  local project_name = response.project_name or "unknown project"
  table.insert(lines, "✗ Failed to start project: " .. project_name)

  if response.error then
    table.insert(lines, "  Error: " .. response.error)
  end

  if response.failed_resource then
    table.insert(lines, "  Failed resource: " .. response.failed_resource)
  end

  return table.concat(lines, "\n")
end

---Format success response with resource details
---@param response table Success response from handler
---@return string formatted_output CLI formatted success display
function response_formatter.format_success_response(response)
  local lines = {}

  local project_name = response.project_name or "unknown project"
  table.insert(lines, "✓ Started " .. project_name .. " successfully")

  local total_spawned = response.total_spawned
    or (response.spawned_resources and #response.spawned_resources)
    or 0
  table.insert(lines, "  Spawned " .. total_spawned .. " resources")

  if response.spawned_resources and #response.spawned_resources > 0 then
    for _, resource in ipairs(response.spawned_resources) do
      table.insert(
        lines,
        "  ✓ " .. resource.name .. " (PID: " .. resource.pid .. ")"
      )
    end
  end

  return table.concat(lines, "\n")
end

---Format any response by detecting type and using appropriate formatter
---@param response table Any response from handler
---@return string formatted_output Appropriately formatted CLI output
function response_formatter.format_response(response)
  local format_type = response_formatter.detect_response_format(response)

  if format_type == "enhanced" then
    return response_formatter.format_enhanced_error_response(response)
  elseif format_type == "simple" then
    return response_formatter.format_simple_error_response(response)
  elseif format_type == "success" then
    return response_formatter.format_success_response(response)
  else
    return "Unknown response format"
  end
end

return response_formatter
