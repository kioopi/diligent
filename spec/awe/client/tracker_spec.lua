local assert = require("luassert")

describe("awe.client.tracker", function()
  local awe
  local tracker

  setup(function()
    _G._TEST = true
  end)

  teardown(function()
    _G._TEST = nil
  end)

  before_each(function()
    -- Use clean dependency injection - no package.loaded hacking needed!
    awe = require("awe")
    local mock_awe = awe.create(awe.interfaces.mock_interface)
    tracker = mock_awe.client.tracker

    -- Reset mock state
    awe.interfaces.mock_interface.reset()
  end)

  describe("find_by_pid", function()
    it("should find client by valid PID", function()
      -- Setup mock clients
      local test_client = { pid = 1234, name = "test-app" }
      awe.interfaces.mock_interface.set_clients({ test_client })

      local result, error_msg = tracker.find_by_pid(1234)

      assert.is_not_nil(result)
      assert.equals(1234, result.pid)
      assert.equals("test-app", result.name)
      assert.is_nil(error_msg)
    end)

    it("should return nil and error for invalid PID", function()
      awe.interfaces.mock_interface.set_clients({})

      local result, error_msg = tracker.find_by_pid(9999)

      assert.is_nil(result)
      assert.is_string(error_msg)
      assert.matches("No client found with PID 9999", error_msg)
    end)

    it("should handle non-numeric PID input", function()
      local result, error_msg = tracker.find_by_pid("invalid")

      assert.is_nil(result)
      assert.is_string(error_msg)
      assert.matches("Invalid PID format", error_msg)
    end)

    it("should handle nil PID input", function()
      local result, error_msg = tracker.find_by_pid(nil)

      assert.is_nil(result)
      assert.is_string(error_msg)
      assert.matches("Invalid PID format", error_msg)
    end)
  end)

  describe("find_by_env", function()
    it("should find clients by environment variable", function()
      -- Mock clients with different PIDs and env vars
      local client1 = { pid = 1001, name = "app1" }
      local client2 = { pid = 1002, name = "app2" }
      awe.interfaces.mock_interface.set_clients({ client1, client2 })

      -- Mock environment data
      awe.interfaces.mock_interface.set_process_env(
        1001,
        { DILIGENT_PROJECT = "test-project" }
      )
      awe.interfaces.mock_interface.set_process_env(
        1002,
        { DILIGENT_PROJECT = "other-project" }
      )

      local results = tracker.find_by_env("DILIGENT_PROJECT", "test-project")

      assert.equals(1, #results)
      assert.equals(1001, results[1].pid)
      assert.equals("app1", results[1].name)
    end)

    it("should return empty list when no matches found", function()
      local client1 = { pid = 1001, name = "app1" }
      awe.interfaces.mock_interface.set_clients({ client1 })
      awe.interfaces.mock_interface.set_process_env(
        1001,
        { OTHER_VAR = "value" }
      )

      local results = tracker.find_by_env("DILIGENT_PROJECT", "test-project")

      assert.equals(0, #results)
    end)

    it("should handle clients without PIDs", function()
      local client_no_pid = { name = "no-pid-app" }
      awe.interfaces.mock_interface.set_clients({ client_no_pid })

      local results = tracker.find_by_env("DILIGENT_PROJECT", "test-project")

      assert.equals(0, #results)
    end)
  end)

  describe("find_by_property", function()
    it("should find clients by property value", function()
      local client1 = { pid = 1001, diligent_role = "editor" }
      local client2 = { pid = 1002, diligent_role = "terminal" }
      local client3 = { pid = 1003, diligent_role = "editor" }
      awe.interfaces.mock_interface.set_clients({ client1, client2, client3 })

      local results = tracker.find_by_property("diligent_role", "editor")

      assert.equals(2, #results)
      assert.equals(1001, results[1].pid)
      assert.equals(1003, results[2].pid)
    end)

    it("should return empty list when no properties match", function()
      local client1 = { pid = 1001, diligent_role = "terminal" }
      awe.interfaces.mock_interface.set_clients({ client1 })

      local results = tracker.find_by_property("diligent_role", "editor")

      assert.equals(0, #results)
    end)

    it("should handle nil property values", function()
      local client1 = { pid = 1001 }
      awe.interfaces.mock_interface.set_clients({ client1 })

      local results = tracker.find_by_property("diligent_role", "editor")

      assert.equals(0, #results)
    end)
  end)

  describe("find_by_name_or_class", function()
    it("should find clients by name substring", function()
      local client1 = { name = "firefox-browser", class = "Firefox" }
      local client2 = { name = "terminal", class = "XTerm" }
      awe.interfaces.mock_interface.set_clients({ client1, client2 })

      local results = tracker.find_by_name_or_class("firefox")

      assert.equals(1, #results)
      assert.equals("firefox-browser", results[1].name)
    end)

    it("should find clients by class substring", function()
      local client1 = { name = "app", class = "Firefox-Browser" }
      local client2 = { name = "terminal", class = "XTerm" }
      awe.interfaces.mock_interface.set_clients({ client1, client2 })

      local results = tracker.find_by_name_or_class("firefox")

      assert.equals(1, #results)
      assert.equals("Firefox-Browser", results[1].class)
    end)

    it("should be case insensitive", function()
      local client1 = { name = "Firefox", class = "Firefox" }
      awe.interfaces.mock_interface.set_clients({ client1 })

      local results = tracker.find_by_name_or_class("FIREFOX")

      assert.equals(1, #results)
    end)

    it("should handle clients with nil name or class", function()
      local client1 = { class = "Firefox" }
      local client2 = { name = "terminal" }
      awe.interfaces.mock_interface.set_clients({ client1, client2 })

      local results = tracker.find_by_name_or_class("firefox")

      assert.equals(1, #results)
      assert.equals("Firefox", results[1].class)
    end)
  end)

  describe("get_all_tracked_clients", function()
    it("should return clients with diligent environment variables", function()
      local client1 = { pid = 1001, name = "app1" }
      local client2 = { pid = 1002, name = "app2" }
      local client3 = { pid = 1003, name = "app3" }
      awe.interfaces.mock_interface.set_clients({ client1, client2, client3 })

      -- Only client1 and client3 have diligent env vars
      awe.interfaces.mock_interface.set_process_env(
        1001,
        { DILIGENT_PROJECT = "test" }
      )
      awe.interfaces.mock_interface.set_process_env(
        1002,
        { OTHER_VAR = "value" }
      )
      awe.interfaces.mock_interface.set_process_env(
        1003,
        { DILIGENT_ROLE = "editor" }
      )

      local results = tracker.get_all_tracked_clients()

      assert.equals(2, #results)
      -- Should contain client1 and client3
      local pids = { results[1].pid, results[2].pid }
      assert.is_true(table.contains(pids, 1001))
      assert.is_true(table.contains(pids, 1003))
    end)

    it("should return clients with diligent properties", function()
      local client1 = { pid = 1001, diligent_role = "editor" }
      local client2 = { pid = 1002, name = "app2" }
      awe.interfaces.mock_interface.set_clients({ client1, client2 })

      local results = tracker.get_all_tracked_clients()

      assert.equals(1, #results)
      assert.equals(1001, results[1].pid)
    end)

    it("should return empty list when no tracked clients exist", function()
      local client1 = { pid = 1001, name = "app1" }
      awe.interfaces.mock_interface.set_clients({ client1 })
      awe.interfaces.mock_interface.set_process_env(
        1001,
        { OTHER_VAR = "value" }
      )

      local results = tracker.get_all_tracked_clients()

      assert.equals(0, #results)
    end)

    it("should handle clients without PIDs", function()
      local client_no_pid = { name = "no-pid-app", diligent_role = "editor" }
      awe.interfaces.mock_interface.set_clients({ client_no_pid })

      local results = tracker.get_all_tracked_clients()

      assert.equals(1, #results)
      assert.equals("no-pid-app", results[1].name)
    end)
  end)
end)

-- Helper function for table.contains
function table.contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end
