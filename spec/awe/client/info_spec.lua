local assert = require("luassert")

describe("awe.client.info", function()
  local awe
  local info

  setup(function()
    _G._TEST = true
  end)

  teardown(function()
    _G._TEST = nil
  end)

  before_each(function()
    -- Use clean dependency injection
    awe = require("awe")
    local mock_awe = awe.create(awe.interfaces.mock_interface)
    info = mock_awe.client.info

    -- Reset mock state
    awe.interfaces.mock_interface.reset()
  end)

  describe("get_client_info", function()
    it("should return comprehensive client information", function()
      local test_client = {
        pid = 1234,
        name = "firefox",
        class = "Firefox",
        instance = "Navigator",
        first_tag = { index = 2, name = "web" },
        screen = { index = 1 },
        floating = true,
        minimized = false,
        maximized = true,
        x = 100,
        y = 200,
        width = 800,
        height = 600,
      }

      local result = info.get_client_info(test_client)

      assert.is_table(result)
      assert.equals(1234, result.pid)
      assert.equals("firefox", result.name)
      assert.equals("Firefox", result.class)
      assert.equals("Navigator", result.instance)
      assert.equals("firefox", result.window_title)
      assert.equals(2, result.tag_index)
      assert.equals("web", result.tag_name)
      assert.equals(1, result.screen_index)
      assert.equals(true, result.floating)
      assert.equals(false, result.minimized)
      assert.equals(true, result.maximized)

      assert.is_table(result.geometry)
      assert.equals(100, result.geometry.x)
      assert.equals(200, result.geometry.y)
      assert.equals(800, result.geometry.width)
      assert.equals(600, result.geometry.height)
    end)

    it("should handle client with missing properties", function()
      local test_client = {
        pid = 5678,
        -- All other properties missing
      }

      local result = info.get_client_info(test_client)

      assert.is_table(result)
      assert.equals(5678, result.pid)
      assert.equals("unnamed", result.name)
      assert.equals("unknown", result.class)
      assert.equals("unknown", result.instance)
      assert.equals("untitled", result.window_title)
      assert.equals(0, result.tag_index)
      assert.equals("no tag", result.tag_name)
      assert.equals(0, result.screen_index)
      assert.equals(false, result.floating)
      assert.equals(false, result.minimized)
      assert.equals(false, result.maximized)

      assert.is_table(result.geometry)
      assert.equals(0, result.geometry.x)
      assert.equals(0, result.geometry.y)
      assert.equals(0, result.geometry.width)
      assert.equals(0, result.geometry.height)
    end)

    it("should handle client with partial tag information", function()
      local test_client = {
        pid = 9999,
        name = "terminal",
        first_tag = { index = 3 }, -- Missing name
      }

      local result = info.get_client_info(test_client)

      assert.equals(3, result.tag_index)
      assert.equals("no tag", result.tag_name)
    end)
  end)

  describe("read_process_env", function()
    it("should parse process environment variables", function()
      -- Mock the file system read
      local mock_env_content =
        "PATH=/usr/bin\0DILIGENT_PROJECT=test\0USER=testuser\0DILIGENT_ROLE=editor\0"

      -- We'll need to mock the file operations
      local original_io_open = io.open
      io.open = function(filename, mode)
        if filename:match("/proc/1234/environ") then
          return {
            read = function(self, format)
              if format == "*all" then
                return mock_env_content
              end
            end,
            close = function() end,
          }
        end
        return nil
      end

      local result, error_msg = info.read_process_env(1234)

      -- Restore original io.open
      io.open = original_io_open

      assert.is_table(result)
      assert.is_nil(error_msg)

      assert.is_table(result.all_vars)
      assert.is_table(result.diligent_vars)
      assert.is_number(result.total_count)

      -- Check parsed environment variables
      assert.equals("/usr/bin", result.all_vars.PATH)
      assert.equals("test", result.all_vars.DILIGENT_PROJECT)
      assert.equals("testuser", result.all_vars.USER)
      assert.equals("editor", result.all_vars.DILIGENT_ROLE)

      -- Check diligent-specific variables
      assert.equals("test", result.diligent_vars.DILIGENT_PROJECT)
      assert.equals("editor", result.diligent_vars.DILIGENT_ROLE)
      assert.is_nil(result.diligent_vars.PATH)
      assert.is_nil(result.diligent_vars.USER)

      -- Check total count
      assert.equals(4, result.total_count)
    end)

    it("should handle file read errors", function()
      local original_io_open = io.open
      io.open = function(filename, mode)
        return nil -- Simulate file not found
      end

      local result, error_msg = info.read_process_env(9999)

      -- Restore original io.open
      io.open = original_io_open

      assert.is_nil(result)
      assert.is_string(error_msg)
      assert.matches("Cannot open /proc/9999/environ", error_msg)
    end)

    it("should handle empty environment file", function()
      local original_io_open = io.open
      io.open = function(filename, mode)
        return {
          read = function(self, format)
            return nil -- Simulate empty read
          end,
          close = function() end,
        }
      end

      local result, error_msg = info.read_process_env(1234)

      -- Restore original io.open
      io.open = original_io_open

      assert.is_nil(result)
      assert.is_string(error_msg)
      assert.matches("Cannot read environ file", error_msg)
    end)

    it("should handle environment with no diligent variables", function()
      local mock_env_content = "PATH=/usr/bin\0USER=testuser\0HOME=/home/user\0"

      local original_io_open = io.open
      io.open = function(filename, mode)
        return {
          read = function(self, format)
            return mock_env_content
          end,
          close = function() end,
        }
      end

      local result, error_msg = info.read_process_env(1234)

      -- Restore original io.open
      io.open = original_io_open

      assert.is_table(result)
      assert.is_nil(error_msg)

      -- Should have regular vars but no diligent vars
      assert.equals("/usr/bin", result.all_vars.PATH)
      assert.equals("testuser", result.all_vars.USER)
      assert.equals(3, result.total_count)

      -- Diligent vars should be empty
      assert.equals(
        0,
        (function()
          local count = 0
          for _ in pairs(result.diligent_vars) do
            count = count + 1
          end
          return count
        end)()
      )
    end)
  end)
end)
