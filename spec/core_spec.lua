local assert = require("luassert")

describe("Diligent Core", function()
  it("should load the main module", function()
    local diligent = require("diligent")
    assert.is_table(diligent)
  end)

  it("should have required functions", function()
    local diligent = require("diligent")
    assert.is_function(diligent.setup)
    assert.is_function(diligent.hello)
    assert.are.equal("Hello from Diligent!", diligent.hello())
  end)
end)
