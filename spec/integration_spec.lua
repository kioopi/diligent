local assert = require("luassert")
local dbus = require("dbus_communication")

pr = require('pl.pretty')

function print_response(response)
  if type(response) == "table" then
    return pr.write(response)
  else
    return tostring(response or "unknown")
  end
end


describe("Integration: CLI to AwesomeWM Communication", function()
  describe("AwesomeWM Environment", function()
    it("should have AwesomeWM available via D-Bus", function()
      -- Test the underlying execute_in_awesome function directly
      local success, result = dbus.execute_in_awesome('return "available"')
      assert.is_true(success, "Should be able to execute in AwesomeWM")
      assert.are.equal("available", result, "Should get 'available' response")

      -- Now test the wrapper function
      local available = dbus.check_awesome_available()
      assert.is_true(available, "AwesomeWM should be available via D-Bus")
    end)

    it("should be able to execute basic Lua in AwesomeWM", function()
      -- Test with string return (most reliable)
      local success, output = dbus.execute_in_awesome('return "test_value"')
      assert.is_true(success, "Should be able to execute Lua in AwesomeWM")
      assert.are.equal("test_value", output, "Should get correct return value")
    end)

    it("should have correct Lua path for diligent dependencies", function()
      -- Test that AwesomeWM can access the LuaRocks Lua 5.4 path
      local test_file = "/tmp/awesome_lua_path_test_" .. os.time()
      local lua_code = string.format(
        [[
        local paths = {}
        for path in string.gmatch(package.path, '[^;]+') do
          table.insert(paths, path)
        end
        local f = io.open('%s', 'w')
        f:write(table.concat(paths, '\n'))
        f:close()
        return "paths written"
      ]],
        test_file
      )

      local success, output = dbus.execute_in_awesome(lua_code)
      assert.is_true(success, "Should be able to check Lua paths in AwesomeWM")

      -- Read the paths file
      local file = io.open(test_file, "r")
      assert.is_not_nil(file, "Should create lua paths test file")
      local paths_content = file:read("*a")
      file:close()
      os.remove(test_file)

      -- Check that the LuaRocks Lua 5.4 path is included
      assert.matches(
        "/home/vt/%.luarocks/share/lua/5%.4/%?%.lua",
        paths_content,
        "AwesomeWM should have LuaRocks Lua 5.4 path in package.path"
      )
    end)

    it("should be able to require dkjson dependency", function()
      local test_file = "/tmp/awesome_dkjson_test_" .. os.time()
      local lua_code = string.format(
        [[
        local success, result = pcall(function()
          local dkjson = require('dkjson')
          return dkjson ~= nil
        end)
        local f = io.open('%s', 'w')
        f:write('Success: ' .. tostring(success) .. ', Result: ' .. tostring(result))
        f:close()
        return "dkjson test complete"
      ]],
        test_file
      )

      local success, output = dbus.execute_in_awesome(lua_code)
      assert.is_true(success, "Should be able to test dkjson in AwesomeWM")

      local file = io.open(test_file, "r")
      assert.is_not_nil(file, "Should create dkjson test file")
      local test_result = file:read("*a")
      file:close()
      os.remove(test_file)

      assert.matches(
        "Success: true",
        test_result,
        "AwesomeWM should be able to require dkjson: " .. test_result
      )
    end)
  end)

  describe("Diligent Module", function()
    it("should be able to require diligent module", function()
      local test_file = "/tmp/awesome_diligent_require_test_" .. os.time()
      local lua_code = string.format(
        [[
        local success, result = pcall(function()
          local diligent = require('diligent')
          return type(diligent) == 'table' and type(diligent.setup) == 'function'
        end)
        local f = io.open('%s', 'w')
        f:write('Success: ' .. tostring(success) .. ', Result: ' .. tostring(result))
        f:close()
        return "diligent require test complete"
      ]],
        test_file
      )

      local success, output = dbus.execute_in_awesome(lua_code)
      assert.is_true(
        success,
        "Should be able to test diligent require in AwesomeWM"
      )

      local file = io.open(test_file, "r")
      assert.is_not_nil(file, "Should create diligent require test file")
      local test_result = file:read("*a")
      file:close()
      os.remove(test_file)

      assert.matches(
        "Success: true, Result: true",
        test_result,
        "AwesomeWM should be able to require diligent module: " .. test_result
      )
    end)

    it(
      "should have diligent properly setup and signal handlers registered",
      function()
        local test_file = "/tmp/awesome_diligent_setup_test_" .. os.time()
        local lua_code = string.format(
          [[
        local success, result = pcall(function()
          local diligent = require('diligent')
          -- Test that setup returns true (indicating success)
          local setup_result = diligent.setup()
          return setup_result == true
        end)
        local f = io.open('%s', 'w')
        f:write('Success: ' .. tostring(success) .. ', Setup result: ' .. tostring(result))
        f:close()
        return "diligent setup test complete"
      ]],
          test_file
        )

        local success, output = dbus.execute_in_awesome(lua_code)
        assert.is_true(
          success,
          "Should be able to test diligent setup in AwesomeWM"
        )

        local file = io.open(test_file, "r")
        assert.is_not_nil(file, "Should create diligent setup test file")
        local test_result = file:read("*a")
        file:close()
        os.remove(test_file)

        assert.matches(
          "Success: true, Setup result: true",
          test_result,
          "Diligent should setup successfully: " .. test_result
        )
      end
    )
  end)

  describe("Basic Signal Communication", function()
    it("should be able to emit signals to AwesomeWM", function()
      local test_file = "/tmp/awesome_signal_test_" .. os.time()
      local lua_code = string.format(
        [[
        local received_signal = false
        local received_data = nil

        -- Set up a test signal handler
        awesome.connect_signal('diligent::test_signal', function(data)
          received_signal = true
          received_data = data
        end)

        -- Emit the test signal
        awesome.emit_signal('diligent::test_signal', 'test_payload')

        -- Write results to file
        local f = io.open('%s', 'w')
        f:write('Signal received: ' .. tostring(received_signal) .. ', Data: ' .. tostring(received_data))
        f:close()
        return "signal test complete"
      ]],
        test_file
      )

      local success, output = dbus.execute_in_awesome(lua_code)
      assert.is_true(
        success,
        "Should be able to test signal emission in AwesomeWM"
      )

      local file = io.open(test_file, "r")
      assert.is_not_nil(file, "Should create signal test file")
      local test_result = file:read("*a")
      file:close()
      os.remove(test_file)

      assert.matches(
        "Signal received: true, Data: test_payload",
        test_result,
        "AwesomeWM signal system should work: " .. test_result
      )
    end)

    it("should be able to send signals from CLI to AwesomeWM", function()
      local test_file = "/tmp/cli_to_awesome_signal_test_" .. os.time()

      -- First, set up a signal handler in AwesomeWM
      local setup_lua_code = string.format(
        [[
        awesome.connect_signal('diligent::cli_test', function(data)
          local f = io.open('%s', 'w')
          f:write('CLI signal received: ' .. tostring(data))
          f:close()
        end)
        return "signal handler setup"
      ]],
        test_file
      )

      local setup_success, _ = dbus.execute_in_awesome(setup_lua_code)
      assert.is_true(setup_success, "Should be able to setup signal handler")

      -- Now send a signal from CLI
      local signal_success, _ =
        dbus.emit_command("cli_test", { test_data = "hello_from_cli" })
      assert.is_true(signal_success, "Should be able to send signal from CLI")

      -- Wait a moment for signal processing
      os.execute("sleep 0.5")

      -- Check if the signal was received
      local file = io.open(test_file, "r")
      assert.is_not_nil(file, "Signal handler should create test file")
      local test_result = file and file:read("*a")
      assert.is_not_nil(test_result, "Test file should contain data")
      assert.is_not_nil(
        file and file:close(),
        "Should close test file properly"
      )
      os.remove(test_file)

      assert.matches(
        "CLI signal received:",
        test_result,
        "AwesomeWM should receive signals from CLI: " .. test_result
      )
      assert.matches(
        "hello_from_cli",
        test_result,
        "Signal should contain expected data: " .. test_result
      )
    end)
  end)

  describe("ping command", function()
    it("should receive pong response from AwesomeWM", function()
      local payload = {
        timestamp = "2025-07-29T10:00:00Z",
        source = "diligent-cli",
      }

      local success, response = dbus.dispatch_command("ping", payload)


      if not success then
        error(
          "Diligent module may not be loaded in AwesomeWM. "
            .. "Add 'local diligent = require(\"diligent\"); diligent.setup()' to your rc.lua. "
            .. "Error: "
            .. print_response(response)
        )
      end

      assert.is_true(success, "Expected ping to succeed")
      assert.is_not_nil(response, "Expected response from AwesomeWM")

      if response then
        assert.are.equal("success", response.status)
        assert.are.equal("pong", response.message)
        assert.is_string(response.timestamp)
        assert.are.equal("2025-07-29T10:00:00Z", response.received_timestamp)
      end
    end)
  end)
end)
