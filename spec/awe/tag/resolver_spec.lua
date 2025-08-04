describe("awe.tag.resolver", function()
  local create_resolver

  before_each(function()
    create_resolver = require("awe.tag.resolver")
  end)

  describe("factory pattern", function()
    it("should create resolver with interface injection", function()
      local mock_interface = {
        get_current_tag = function()
          return 1
        end,
      }

      local resolver = create_resolver(mock_interface)

      assert.is_table(resolver)
      assert.is_function(resolver.resolve_tag_spec)
    end)
  end)

  describe("resolve_tag_spec", function()
    local resolver, mock_interface

    before_each(function()
      -- Mock the tag_mapper module
      package.loaded["tag_mapper"] = {
        resolve_tag = function(spec, base)
          if spec == 0 then
            return true, { name = "current", index = base }
          elseif spec == 2 then
            return true, { name = "tag_" .. (base + spec), index = base + spec }
          elseif spec == "2" then
            return true, { name = "tag_2", index = 2 }
          elseif spec == "project" then
            return true, { name = "project", index = nil }
          else
            return false, "Tag not found"
          end
        end,
      }

      mock_interface = {
        get_current_tag = function()
          return 1
        end,
      }

      resolver = create_resolver(mock_interface)
    end)

    describe("relative current tag (0)", function()
      it("should resolve '0' to current tag", function()
        local success, result = resolver.resolve_tag_spec("0")

        assert.is_true(success)
        assert.are.equal("current", result.name)
        assert.are.equal(1, result.index)
      end)
    end)

    describe("relative offset tags", function()
      it("should resolve '+2' to relative offset", function()
        local success, result = resolver.resolve_tag_spec("+2")

        assert.is_true(success)
        assert.are.equal("tag_3", result.name)
        assert.are.equal(3, result.index)
      end)

      it("should resolve '-1' to relative offset", function()
        -- Mock tag_mapper to handle negative offset
        package.loaded["tag_mapper"].resolve_tag = function(spec, base)
          if spec == -1 then
            return true, { name = "tag_" .. (base - 1), index = base - 1 }
          end
          return false, "Tag not found"
        end

        local success, result = resolver.resolve_tag_spec("-1")

        assert.is_true(success)
        assert.are.equal("tag_0", result.name)
        assert.are.equal(0, result.index)
      end)
    end)

    describe("absolute index tags", function()
      it("should resolve '2' to absolute tag index", function()
        local success, result = resolver.resolve_tag_spec("2")

        assert.is_true(success)
        assert.are.equal("tag_2", result.name)
        assert.are.equal(2, result.index)
      end)
    end)

    describe("named tags", function()
      it("should resolve named tag strings", function()
        local success, result = resolver.resolve_tag_spec("project")

        assert.is_true(success)
        assert.are.equal("project", result.name)
        assert.is_nil(result.index)
      end)
    end)

    describe("error handling", function()
      it("should handle tag_mapper errors", function()
        local success, error_msg = resolver.resolve_tag_spec("invalid")

        assert.is_false(success)
        assert.are.equal("Tag not found", error_msg)
      end)

      it("should handle interface without get_current_tag", function()
        local interface_without_method = {}
        local resolver_no_method = create_resolver(interface_without_method)

        local success, result =
          resolver_no_method.resolve_tag_spec("0", { base_tag = 3 })

        assert.is_true(success)
        assert.are.equal("current", result.name)
        assert.are.equal(3, result.index)
      end)
    end)

    describe("options parameter", function()
      it(
        "should use base_tag from options when interface lacks get_current_tag",
        function()
          local minimal_interface = {}
          local minimal_resolver = create_resolver(minimal_interface)

          local success, result =
            minimal_resolver.resolve_tag_spec("0", { base_tag = 5 })

          assert.is_true(success)
          assert.are.equal(5, result.index)
        end
      )

      it("should default to base_tag 1 when no options provided", function()
        local minimal_interface = {}
        local minimal_resolver = create_resolver(minimal_interface)

        -- Mock tag_mapper to verify base_tag = 1 is used
        package.loaded["tag_mapper"].resolve_tag = function(spec, base)
          assert.are.equal(1, base) -- Verify default base_tag
          return true, { name = "default", index = base }
        end

        local success, result = minimal_resolver.resolve_tag_spec("0")

        assert.is_true(success)
        assert.are.equal("default", result.name)
      end)
    end)
  end)
end)
