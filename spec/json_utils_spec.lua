local assert = require("luassert")
local json_utils = require("json_utils")

describe("json_utils", function()
  describe("encode", function()
    it("should encode simple table to JSON string", function()
      local data = { status = "success", message = "test" }
      local success, result = json_utils.encode(data)

      assert.is_true(success)
      assert.is_string(result)
      assert.matches('"status":"success"', result)
      assert.matches('"message":"test"', result)
    end)

    it("should encode nested table to JSON string", function()
      local data = {
        status = "success",
        data = {
          id = 123,
          name = "test_name",
        },
      }
      local success, result = json_utils.encode(data)

      assert.is_true(success)
      assert.is_string(result)
      assert.matches('"id":123', result)
      assert.matches('"name":"test_name"', result)
    end)

    it("should encode array to JSON string", function()
      local data = { "item1", "item2", "item3" }
      local success, result = json_utils.encode(data)

      assert.is_true(success)
      assert.is_string(result)
      assert.matches('"item1"', result)
      assert.matches('"item2"', result)
      assert.matches('"item3"', result)
    end)

    it("should encode empty table to JSON string", function()
      local data = {}
      local success, result = json_utils.encode(data)

      assert.is_true(success)
      assert.is_string(result)
      -- dkjson encodes empty tables as arrays by default
      assert.matches("%[%]", result)
    end)

    it("should handle nil input gracefully", function()
      local success, result = json_utils.encode(nil)

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("input is required", result)
    end)

    it("should handle encoding errors gracefully", function()
      -- Create a table with circular reference to trigger encoding error
      local data = {}
      data.self = data

      local success, result = json_utils.encode(data)

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("JSON encoding error", result)
    end)
  end)

  describe("decode", function()
    it("should decode valid JSON string to table", function()
      local json_string = '{"status":"success","message":"test"}'
      local success, result = json_utils.decode(json_string)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal("success", result.status)
      assert.are.equal("test", result.message)
    end)

    it("should decode nested JSON string to table", function()
      local json_string =
        '{"status":"success","data":{"id":123,"name":"test_name"}}'
      local success, result = json_utils.decode(json_string)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal("success", result.status)
      assert.is_table(result.data)
      assert.are.equal(123, result.data.id)
      assert.are.equal("test_name", result.data.name)
    end)

    it("should decode JSON array to table", function()
      local json_string = '["item1","item2","item3"]'
      local success, result = json_utils.decode(json_string)

      assert.is_true(success)
      assert.is_table(result)
      assert.are.equal("item1", result[1])
      assert.are.equal("item2", result[2])
      assert.are.equal("item3", result[3])
    end)

    it("should decode empty JSON object", function()
      local json_string = "{}"
      local success, result = json_utils.decode(json_string)

      assert.is_true(success)
      assert.is_table(result)
    end)

    it("should handle nil input gracefully", function()
      local success, result = json_utils.decode(nil)

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("input is required", result)
    end)

    it("should handle empty string input gracefully", function()
      local success, result = json_utils.decode("")

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("input is required", result)
    end)

    it("should handle invalid JSON gracefully", function()
      local json_string = '{"invalid": json}'
      local success, result = json_utils.decode(json_string)

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("JSON parsing error", result)
    end)

    it("should handle malformed JSON gracefully", function()
      local json_string = '{"status":"success"' -- missing closing brace
      local success, result = json_utils.decode(json_string)

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("JSON parsing error", result)
    end)

    it("should handle non-string input gracefully", function()
      local success, result = json_utils.decode(123)

      assert.is_false(success)
      assert.is_string(result)
      assert.matches("input must be a string", result)
    end)
  end)

  describe("round-trip encoding and decoding", function()
    it("should maintain data integrity through encode/decode cycle", function()
      local original_data = {
        status = "success",
        message = "test message",
        data = {
          id = 123,
          active = true,
          items = { "a", "b", "c" },
        },
      }

      local encode_success, json_string = json_utils.encode(original_data)
      assert.is_true(encode_success)

      local decode_success, decoded_data = json_utils.decode(json_string)
      assert.is_true(decode_success)

      assert.are.equal(original_data.status, decoded_data.status)
      assert.are.equal(original_data.message, decoded_data.message)
      assert.are.equal(original_data.data.id, decoded_data.data.id)
      assert.are.equal(original_data.data.active, decoded_data.data.active)
      assert.are.equal(original_data.data.items[1], decoded_data.data.items[1])
      assert.are.equal(original_data.data.items[2], decoded_data.data.items[2])
      assert.are.equal(original_data.data.items[3], decoded_data.data.items[3])
    end)
  end)
end)
