local assert = require("luassert")

describe("awe module", function()
  local awe

  setup(function()
    _G._TEST = true
  end)

  teardown(function()
    _G._TEST = nil
  end)

  before_each(function()
    -- Clean module cache to get fresh instance
    package.loaded["awe"] = nil
    awe = require("awe")
  end)

  it("should be require-able", function()
    assert.is_table(awe)
  end)

  it("should provide direct access to interface modules", function()
    assert.is_table(awe.awesome_interface)
    assert.is_table(awe.dry_run_interface)
    assert.is_table(awe.mock_interface)
  end)

  it("should have working awesome_interface functions", function()
    assert.is_function(awe.awesome_interface.get_screen_context)
    assert.is_function(awe.awesome_interface.find_tag_by_name)
    assert.is_function(awe.awesome_interface.create_named_tag)
  end)

  it("should have working mock_interface functions", function()
    assert.is_function(awe.mock_interface.get_screen_context)
    assert.is_function(awe.mock_interface.find_tag_by_name)
    assert.is_function(awe.mock_interface.create_named_tag)
  end)

  it("should have working dry_run_interface functions", function()
    assert.is_function(awe.dry_run_interface.get_screen_context)
    assert.is_function(awe.dry_run_interface.find_tag_by_name)
    assert.is_function(awe.dry_run_interface.create_named_tag)
  end)

  describe("mock_interface behavior", function()
    it("should provide mock screen context", function()
      local context = awe.mock_interface.get_screen_context()
      assert.is_table(context)
      assert.is_table(context.screen)
      assert.is_number(context.current_tag_index)
      assert.is_table(context.available_tags)
      assert.is_number(context.tag_count)
    end)

    it("should handle tag finding for testing", function()
      local tag = awe.mock_interface.find_tag_by_name("test")
      assert.is_table(tag)
      assert.are.equal("test", tag.name)
    end)

    it("should handle tag creation for testing", function()
      local tag = awe.mock_interface.create_named_tag("new-tag")
      assert.is_table(tag)
      assert.are.equal("new-tag", tag.name)
    end)
  end)
end)
