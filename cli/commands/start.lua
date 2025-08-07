--[[
Start Command Script for Diligent CLI

Implements the start command that launches project workspaces.
Uses the same architectural pattern as validate.lua for consistency.
--]]

-- Setup package path (identical to validate.lua)
local script_dir = arg and arg[0] and arg[0]:match("(.+)/[^/]+$") or "."

local base_paths = {
  script_dir .. "/../?.lua",
  script_dir .. "/../../lua/?.lua",
  script_dir .. "/../../lua/?/init.lua",
  "./lua/?.lua",
  "./lua/?/init.lua",
}

package.path = table.concat(base_paths, ";") .. ";" .. package.path

-- Import required modules (matching validate.lua pattern)
local cli = require("cliargs")
local cli_printer = require("cli_printer")
local validate_args = require("cli.validate_args") -- Reusing validate_args since logic is identical
local project_loader = require("cli.project_loader")
local error_reporter = require("cli.error_reporter")
local response_formatter = require("cli.response_formatter")

-- Setup CLI arguments (following cliargs pattern)
cli:set_name("workon start")
cli:set_description("Start project workspaces")

-- Arguments (matching validate.lua exactly)
cli:splat("PROJECT_NAME", "Project name to start (or use --file option)")

-- Options
cli:option("-f, --file=FILE", "Path to DSL file to start")
cli:flag("--dry-run", "Preview operations without execution")

-- Parse arguments (identical pattern to validate.lua)
local args, err = cli:parse()

if not args and err then
  error_reporter.report_and_exit(err, error_reporter.ERROR_INVALID_ARGS)
end

-- Validate parsed arguments (identical pattern)
local args_success, validated_args = validate_args.validate_parsed_args(args)
if not args_success then
  error_reporter.report_and_exit(
    validated_args,
    error_reporter.ERROR_INVALID_ARGS
  )
end

-- Phase 1: Only handle project loading, no actual starting yet
-- Load DSL (identical pattern to validate.lua)
local load_success, dsl_or_error

if validated_args.input_type == validate_args.INPUT_TYPE_FILE then
  load_success, dsl_or_error =
    project_loader.load_by_file_path(validated_args.file_path)
else
  load_success, dsl_or_error =
    project_loader.load_by_project_name(validated_args.project_name)
end

-- Handle loading errors (identical pattern)
if not load_success then
  local error_type = project_loader.get_error_type(dsl_or_error)
  if error_type == project_loader.ERROR_FILE_NOT_FOUND then
    error_reporter.report_and_exit(
      dsl_or_error,
      error_reporter.ERROR_FILE_NOT_FOUND
    )
  elseif error_type == project_loader.ERROR_PROJECT_NOT_FOUND then
    error_reporter.report_and_exit(
      dsl_or_error,
      error_reporter.ERROR_PROJECT_NOT_FOUND
    )
  else
    error_reporter.report_and_exit(
      dsl_or_error,
      error_reporter.ERROR_VALIDATION
    )
  end
end

-- Convert DSL to start request
local start_processor = require("dsl.start_processor")
local start_request =
  start_processor.convert_project_to_start_request(dsl_or_error)

-- Check if dry-run mode
if args["dry-run"] then
  cli_printer.info("DRY RUN MODE - No actual spawning will occur")
  cli_printer.success(
    "Project loaded successfully: " .. start_request.project_name
  )
  cli_printer.info("Resources to start: " .. tostring(#start_request.resources))

  for _, resource in ipairs(start_request.resources) do
    cli_printer.info(
      "  • "
        .. resource.name
        .. ": "
        .. resource.command
        .. " (tag: "
        .. tostring(resource.tag_spec)
        .. ")"
    )
  end

  os.exit(error_reporter.EXIT_SUCCESS)
end

-- Send to AwesomeWM via D-Bus
local dbus_communication = require("dbus_communication")
local comm_success, response =
  dbus_communication.dispatch_command("start", start_request)

if not comm_success then
  error_reporter.report_and_exit(
    "Failed to communicate with AwesomeWM: " .. tostring(response),
    error_reporter.ERROR_VALIDATION
  )
end

-- Parse and display results using enhanced response formatter
if response then
  local format_type = response_formatter.detect_response_format(response)
  
  if format_type == "success" or (response.status == "success") then
    -- Handle success responses
    local formatted_output = response_formatter.format_success_response(response)
    print(formatted_output)
    os.exit(error_reporter.EXIT_SUCCESS)
  else
    -- Handle error responses (both simple and enhanced)
    local formatted_output = response_formatter.format_response(response)
    print(formatted_output)
    
    -- Exit with appropriate error code
    os.exit(error_reporter.EXIT_VALIDATION_ERROR)
  end
else
  error_reporter.report_and_exit(
    "No response received from AwesomeWM",
    error_reporter.ERROR_VALIDATION
  )
end
