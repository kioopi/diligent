local validators = {}

local livr = require("LIVR")

-- Custom LIVR rules
local function positive_integer()
  return function(value)
    if type(value) ~= "number" then
      return value, "NOT_INTEGER"
    end
    if value <= 0 then
      return value, "NOT_POSITIVE_INTEGER"
    end
    return value
  end
end

local function non_empty_string()
  return function(value)
    if type(value) ~= "string" then
      return value, "NOT_STRING"
    end
    local trimmed = value:match("^%s*(.-)%s*$")
    if trimmed == "" then
      return value, "EMPTY_STRING"
    end
    return value
  end
end

local function iso_date()
  return function(value)
    if type(value) ~= "string" then
      return value, "NOT_STRING"
    end
    -- Basic ISO 8601 format check (simplified)
    if not value:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ?$") then
      return value, "INVALID_ISO_DATE"
    end
    return value
  end
end

-- Register custom rules
livr.register_default_rules({
  positive_integer = positive_integer,
  non_empty_string = non_empty_string,
  iso_date = iso_date,
})

-- Create specific validators
function validators.create_timestamp_validator()
  return livr.new({
    timestamp = { "required", "iso_date" },
  })
end

function validators.create_command_validator()
  return livr.new({
    command = { "required", "non_empty_string" },
  })
end

function validators.create_pid_validator()
  return livr.new({
    pid = { "required", "positive_integer" },
  })
end

return validators
