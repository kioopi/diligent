local function create_mock_tag(name, index)
  return {
    name = name,
    index = index,
  }
end

local create_mock_awful = function()
  local mock_awful = {
    screen = {
      focused = function()
        return {
          selected_tag = {
            index = 3, -- default to tag 3 for testing
          },
          tags = {
            create_mock_tag("1", 1),
            create_mock_tag("2", 2),
            create_mock_tag("3", 3),
            create_mock_tag("4", 4),
            create_mock_tag("editor", nil), -- named tag
          },
        }
      end,
    },
    tag = {},
  }

  mock_awful.tag.find_by_name = function(name, screen)
    screen = screen or mock_awful.screen.focused()
    if screen and screen.tags then
      for _, tag in ipairs(screen.tags) do
        if tag and tag.name == name then
          return tag
        end
      end
    end
    return nil
  end

  mock_awful.tag.add = function(name, props)
    if name == "fail-tag-creation" then
      return nil -- Simulate failure for this specific tag
    end

    local screen = props.screen or mock_awful.screen.focused()
    local new_tag = create_mock_tag(name, #screen.tags + 1)
    table.insert(screen.tags, new_tag)
    return new_tag
  end

  return mock_awful
end

function init()
  local original_awesome

  return {
    setup = function()
      if not _G._TEST then
        error(
          "_G._TEST is not set. It should be set to true when using mocked awful."
        )
      end

      local mock_awful = create_mock_awful()
      original_awful = package.loaded["awful"]
      package.loaded["awful"] = mock_awful

      return mock_awful
    end,
    cleanup = function()
      package.loaded["awful"] = original_awful
    end,
    create_mock_tag = create_mock_tag,
  }
end

return init()
