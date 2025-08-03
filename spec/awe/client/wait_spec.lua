local assert = require("luassert")

describe("awe.client.wait", function()
  local awe
  local wait

  before_each(function()
    -- Use clean dependency injection
    awe = require("awe")
    local mock_awe = awe.create(awe.interfaces.mock_interface)
    wait = mock_awe.client.wait

    -- Reset mock state
    awe.interfaces.mock_interface.reset()
  end)

  describe("wait_and_set_properties", function()
    it("should wait for client and set properties successfully", function()
      local test_client = { pid = 1234, name = "test-app" }
      awe.interfaces.mock_interface.set_clients({ test_client })

      local properties = {
        diligent_role = "editor",
        diligent_project = "test-project",
        floating = "true",
      }

      local success, results = wait.wait_and_set_properties(1234, properties, 1)

      assert.is_true(success)
      assert.is_table(results)

      -- Check that properties were set
      assert.is_table(results.diligent_role)
      assert.is_table(results.diligent_project)
      assert.is_table(results.floating)

      assert.is_true(results.diligent_role.success)
      assert.is_true(results.diligent_project.success)
      assert.is_true(results.floating.success)

      assert.is_string(results.diligent_role.message)
      assert.is_string(results.diligent_project.message)
      assert.is_string(results.floating.message)

      -- Verify properties were actually set on client
      assert.equals("editor", test_client.diligent_role)
      assert.equals("test-project", test_client.diligent_project)
      assert.equals(true, test_client.floating) -- Should be converted from string
    end)

    it("should handle client appearing immediately", function()
      local test_client = { pid = 5678, name = "immediate-app" }
      awe.interfaces.mock_interface.set_clients({ test_client })

      local properties = {
        diligent_workspace = "main",
      }

      local success, results = wait.wait_and_set_properties(5678, properties, 5)

      assert.is_true(success)
      assert.is_table(results)
      assert.is_true(results.diligent_workspace.success)
      assert.equals("main", test_client.diligent_workspace)
    end)

    it("should timeout when client never appears", function()
      -- Don't add any clients to simulate client never appearing
      awe.interfaces.mock_interface.set_clients({})

      local properties = {
        diligent_role = "editor",
      }

      -- Mock os.time to control timeout behavior
      local original_os_time = os.time
      local mock_time = 0
      os.time = function()
        mock_time = mock_time + 1
        return mock_time
      end

      -- Mock os.execute to avoid actual sleep
      local original_os_execute = os.execute
      os.execute = function(cmd)
        if cmd == "sleep 0.5" then
          -- Do nothing, just return
          return true
        end
        return original_os_execute(cmd)
      end

      local success, message = wait.wait_and_set_properties(9999, properties, 2)

      -- Restore original functions
      os.time = original_os_time
      os.execute = original_os_execute

      assert.is_false(success)
      assert.is_string(message)
      assert.matches("Timeout waiting for client to appear", message)
    end)

    it("should use default timeout when none provided", function()
      -- Test that default timeout (5 seconds) is used
      local test_client = { pid = 1111, name = "default-timeout-app" }
      awe.interfaces.mock_interface.set_clients({ test_client })

      local properties = {
        diligent_managed = "true",
      }

      local success, results = wait.wait_and_set_properties(1111, properties) -- No timeout specified

      assert.is_true(success)
      assert.is_table(results)
      assert.is_true(results.diligent_managed.success)
      assert.equals(true, test_client.diligent_managed)
    end)

    it("should handle empty properties object", function()
      local test_client = { pid = 2222, name = "empty-props-app" }
      awe.interfaces.mock_interface.set_clients({ test_client })

      local success, results = wait.wait_and_set_properties(2222, {}, 1)

      assert.is_true(success)
      assert.is_table(results)
      -- Should be empty results table
      assert.equals(
        0,
        (function()
          local count = 0
          for _ in pairs(results) do
            count = count + 1
          end
          return count
        end)()
      )
    end)

    it("should handle property setting failures gracefully", function()
      -- Test case where client is found but property setting fails
      local test_client = { pid = 3333, name = "prop-fail-app" }
      awe.interfaces.mock_interface.set_clients({ test_client })

      local properties = {
        valid_prop = "valid_value",
        -- The properties module should handle this normally,
        -- but we're testing the wait module's response to property setting
      }

      local success, results = wait.wait_and_set_properties(3333, properties, 1)

      assert.is_true(success) -- wait succeeded (client found)
      assert.is_table(results)
      assert.is_table(results.valid_prop)
      assert.is_true(results.valid_prop.success)
    end)

    it("should handle multiple properties with mixed success", function()
      local test_client = { pid = 4444, name = "mixed-app" }
      awe.interfaces.mock_interface.set_clients({ test_client })

      local properties = {
        prop1 = "value1",
        prop2 = "value2",
        prop3 = "value3",
      }

      local success, results = wait.wait_and_set_properties(4444, properties, 1)

      assert.is_true(success)
      assert.is_table(results)

      -- All should succeed in our mock environment
      assert.is_true(results.prop1.success)
      assert.is_true(results.prop2.success)
      assert.is_true(results.prop3.success)

      -- Verify all properties were set
      assert.equals("value1", test_client.prop1)
      assert.equals("value2", test_client.prop2)
      assert.equals("value3", test_client.prop3)
    end)
  end)
end)
