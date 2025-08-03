local assert = require("luassert")

describe("awe.client.properties", function()
  local awe
  local properties

  before_each(function()
    -- Use clean dependency injection - no package.loaded hacking needed!
    awe = require("awe")
    local mock_awe = awe.create(awe.interfaces.mock_interface)
    properties = mock_awe.client.properties

    -- Reset mock state
    awe.interfaces.mock_interface.reset()
  end)

  describe("get_client_properties", function()
    it("should return diligent properties from client object", function()
      local test_client = {
        pid = 1234,
        diligent_project = "test-project",
        diligent_role = "editor",
        diligent_workspace = "main",
        other_property = "not-diligent",
      }

      local result = properties.get_client_properties(test_client)

      assert.is_table(result)
      assert.is_table(result.all_properties)
      assert.is_table(result.diligent_properties)

      -- Should contain diligent properties
      assert.equals("test-project", result.diligent_properties.diligent_project)
      assert.equals("editor", result.diligent_properties.diligent_role)
      assert.equals("main", result.diligent_properties.diligent_workspace)

      -- Should not contain non-diligent properties in diligent_properties
      assert.is_nil(result.diligent_properties.other_property)

      -- All diligent properties should also be in all_properties
      assert.equals("test-project", result.all_properties.diligent_project)
      assert.equals("editor", result.all_properties.diligent_role)
      assert.equals("main", result.all_properties.diligent_workspace)
    end)

    it("should handle client with no diligent properties", function()
      local test_client = {
        pid = 1234,
        name = "test-app",
        other_property = "value",
      }

      local result = properties.get_client_properties(test_client)

      assert.is_table(result)
      assert.is_table(result.all_properties)
      assert.is_table(result.diligent_properties)

      -- Should be empty tables
      assert.equals(
        0,
        (function()
          local count = 0
          for _ in pairs(result.all_properties) do
            count = count + 1
          end
          return count
        end)()
      )
      assert.equals(
        0,
        (function()
          local count = 0
          for _ in pairs(result.diligent_properties) do
            count = count + 1
          end
          return count
        end)()
      )
    end)

    it("should handle all known diligent property types", function()
      local test_client = {
        diligent_project = "test",
        diligent_role = "editor",
        diligent_resource_id = "res123",
        diligent_workspace = "main",
        diligent_start_time = "2024-01-01T10:00:00Z",
        diligent_managed = true,
      }

      local result = properties.get_client_properties(test_client)

      assert.equals(
        6,
        (function()
          local count = 0
          for _ in pairs(result.diligent_properties) do
            count = count + 1
          end
          return count
        end)()
      )
      assert.equals("test", result.diligent_properties.diligent_project)
      assert.equals("editor", result.diligent_properties.diligent_role)
      assert.equals("res123", result.diligent_properties.diligent_resource_id)
      assert.equals("main", result.diligent_properties.diligent_workspace)
      assert.equals(
        "2024-01-01T10:00:00Z",
        result.diligent_properties.diligent_start_time
      )
      assert.equals(true, result.diligent_properties.diligent_managed)
    end)
  end)

  describe("set_client_property", function()
    it("should set property on client found by PID", function()
      local test_client = { pid = 1234, name = "test-app" }
      awe.interfaces.mock_interface.set_clients({ test_client })

      local success, message =
        properties.set_client_property(1234, "diligent_role", "editor")

      assert.is_true(success)
      assert.is_string(message)
      assert.matches("Property diligent_role set to editor", message)
      assert.equals("editor", test_client.diligent_role)
    end)

    it("should convert string 'true' to boolean true", function()
      local test_client = { pid = 1234, name = "test-app" }
      awe.interfaces.mock_interface.set_clients({ test_client })

      local success, message =
        properties.set_client_property(1234, "diligent_managed", "true")

      assert.is_true(success)
      assert.equals(true, test_client.diligent_managed)
      assert.matches("Property diligent_managed set to true", message)
    end)

    it("should convert string 'false' to boolean false", function()
      local test_client = { pid = 1234, name = "test-app" }
      awe.interfaces.mock_interface.set_clients({ test_client })

      local success, message =
        properties.set_client_property(1234, "floating", "false")

      assert.is_true(success)
      assert.equals(false, test_client.floating)
      assert.matches("Property floating set to false", message)
    end)

    it("should convert numeric strings to numbers", function()
      local test_client = { pid = 1234, name = "test-app" }
      awe.interfaces.mock_interface.set_clients({ test_client })

      local success, message =
        properties.set_client_property(1234, "width", "800")

      assert.is_true(success)
      assert.equals(800, test_client.width)
      assert.matches("Property width set to 800", message)
    end)

    it("should leave non-convertible strings as strings", function()
      local test_client = { pid = 1234, name = "test-app" }
      awe.interfaces.mock_interface.set_clients({ test_client })

      local success, message =
        properties.set_client_property(1234, "diligent_project", "my-project")

      assert.is_true(success)
      assert.equals("my-project", test_client.diligent_project)
      assert.matches("Property diligent_project set to my%-project", message)
    end)

    it("should return false when client not found", function()
      awe.interfaces.mock_interface.set_clients({})

      local success, message =
        properties.set_client_property(9999, "diligent_role", "editor")

      assert.is_false(success)
      assert.is_string(message)
      assert.matches("No client found with PID 9999", message)
    end)

    it("should handle invalid PID format", function()
      local success, message =
        properties.set_client_property("invalid", "diligent_role", "editor")

      assert.is_false(success)
      assert.is_string(message)
      assert.matches("Invalid PID format", message)
    end)
  end)
end)
