--[[
Tag Specification Parser

Handles parsing and validation of tag specifications according to DSL spec:
- Numbers: relative offsets from base tag (1, 2, -1)  
- String digits: absolute numeric tags ("3", "9")
- Named strings: named tag references ("editor", "browser")

Returns parsed tag information for use by tag resolver.
--]]

local tag_spec = {}

-- Tag type constants
tag_spec.TYPE_RELATIVE = "relative"
tag_spec.TYPE_ABSOLUTE = "absolute"
tag_spec.TYPE_NAMED = "named"

---Parse tag specification into type and value
---@param tag_value number|string Tag specification from DSL
---@return boolean success True if parsing succeeded
---@return table|string result Tag info table or error message
function tag_spec.parse(tag_value)
  if tag_value == nil then
    return false, "tag specification cannot be nil"
  end

  local tag_type = type(tag_value)

  if tag_type == "number" then
    -- Numeric tags are relative offsets
    if tag_value < 0 then
      return false, "negative tag offsets not supported in v1.0"
    end

    return true,
      {
        type = tag_spec.TYPE_RELATIVE,
        value = tag_value,
      }
  elseif tag_type == "string" then
    if tag_value == "" then
      return false, "tag specification cannot be empty string"
    end

    -- Check if string contains only digits
    local numeric_value = tonumber(tag_value)
    if numeric_value then
      -- String digits are absolute numeric tags
      if numeric_value < 1 or numeric_value > 9 then
        return false,
          "absolute tag must be between 1 and 9, got " .. numeric_value
      end

      return true,
        {
          type = tag_spec.TYPE_ABSOLUTE,
          value = numeric_value,
        }
    else
      -- Non-numeric strings are named tags
      -- Validate tag name format (basic validation)
      if not tag_value:match("^[a-zA-Z][a-zA-Z0-9_-]*$") then
        return false,
          "invalid tag name format: must start with letter and contain only letters, numbers, underscore, or dash"
      end

      return true,
        {
          type = tag_spec.TYPE_NAMED,
          value = tag_value,
        }
    end
  else
    return false, "tag must be a number or string, got " .. tag_type
  end
end

---Validate tag specification (lighter validation without full parsing)
---@param tag_value number|string Tag specification from DSL
---@return boolean success True if validation passed
---@return string|nil error Error message if validation failed
function tag_spec.validate(tag_value)
  local success, result = tag_spec.parse(tag_value)
  if not success then
    return false, result
  end
  return true, nil
end

---Get human-readable description of parsed tag
---@param tag_info table Parsed tag info from parse()
---@return string description Human-readable tag description
function tag_spec.describe(tag_info)
  if not tag_info or not tag_info.type then
    return "invalid tag info"
  end

  if tag_info.type == tag_spec.TYPE_RELATIVE then
    if tag_info.value == 0 then
      return "current tag (relative offset 0)"
    else
      return "relative offset +" .. tag_info.value
    end
  elseif tag_info.type == tag_spec.TYPE_ABSOLUTE then
    return "absolute tag " .. tag_info.value
  elseif tag_info.type == tag_spec.TYPE_NAMED then
    return "named tag '" .. tag_info.value .. "'"
  else
    return "unknown tag type: " .. tostring(tag_info.type)
  end
end

return tag_spec
