--[[
Validate Command Script for Diligent CLI

Refactored version that uses modular architecture for better maintainability.
Uses dedicated modules for argument validation, project loading, formatting, and error handling.
--]]

-- Setup package path to find lua modules
local script_dir = arg and arg[0] and arg[0]:match("(.+)/[^/]+$") or "."

-- Handle both direct execution and execution via main CLI
local base_paths = {
  script_dir .. "/../?.lua",
  script_dir .. "/../../lua/?.lua",
  script_dir .. "/../../lua/?/init.lua",
  "./lua/?.lua",
  "./lua/?/init.lua",
}

package.path = table.concat(base_paths, ";") .. ";" .. package.path

-- Import required modules
local cli = require("cliargs")
local cli_printer = require("cli_printer")
local validate_args = require("cli.validate_args")
local project_loader = require("cli.project_loader")
local validation_formatter = require("cli.validation_formatter")
local error_reporter = require("cli.error_reporter")

-- Setup CLI arguments
cli:set_name("workon validate")
cli:set_description("Validate project DSL files")

-- Arguments (optional - either this or --file)
cli:splat("PROJECT_NAME", "Project name to validate (or use --file option)")

-- Options
cli:option("-f, --file=FILE", "Path to DSL file to validate")

-- Parse arguments
local args, err = cli:parse()

if not args and err then
  error_reporter.report_and_exit(err, error_reporter.ERROR_INVALID_ARGS)
end

-- Validate parsed arguments
local args_success, validated_args = validate_args.validate_parsed_args(args)
if not args_success then
  error_reporter.report_and_exit(
    validated_args,
    error_reporter.ERROR_INVALID_ARGS
  )
end

-- Load DSL based on input type
local load_success, dsl_or_error

if validated_args.input_type == validate_args.INPUT_TYPE_FILE then
  load_success, dsl_or_error =
    project_loader.load_by_file_path(validated_args.file_path)
else
  load_success, dsl_or_error =
    project_loader.load_by_project_name(validated_args.project_name)
end

-- Handle loading errors with appropriate exit codes
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

-- Format and display validation results
local formatted_lines =
  validation_formatter.format_validation_results(dsl_or_error)

for _, line in ipairs(formatted_lines) do
  if line == "" then
    print("") -- Empty lines
  else
    cli_printer.success(line)
  end
end

-- Exit with success
os.exit(error_reporter.EXIT_SUCCESS)
