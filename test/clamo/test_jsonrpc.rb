# frozen_string_literal: true

require "test_helper"

class TestJSONRPCBuildRequest < Minitest::Test
  def test_with_params_and_id
    result = Clamo::JSONRPC.build_request(method: "add", params: [1, 2], id: 1)
    assert_equal({ jsonrpc: "2.0", method: "add", params: [1, 2], id: 1 }, result)
  end

  def test_without_params
    result = Clamo::JSONRPC.build_request(method: "ping", id: 1)
    assert_equal({ jsonrpc: "2.0", method: "ping", id: 1 }, result)
    refute result.key?(:params)
  end

  def test_without_id_is_notification
    result = Clamo::JSONRPC.build_request(method: "notify", params: [1])
    assert_equal({ jsonrpc: "2.0", method: "notify", params: [1] }, result)
    refute result.key?(:id)
  end

  def test_with_hash_params
    result = Clamo::JSONRPC.build_request(method: "subtract", params: { a: 5, b: 3 }, id: 2)
    assert_equal({ jsonrpc: "2.0", method: "subtract", params: { a: 5, b: 3 }, id: 2 }, result)
  end

  def test_raises_without_method
    assert_raises(ArgumentError) { Clamo::JSONRPC.build_request(params: [1]) }
  end

  def test_raises_with_invalid_params_type
    assert_raises(ArgumentError) { Clamo::JSONRPC.build_request(method: "x", params: "invalid") }
  end
end

class TestJSONRPCBuildResultResponse < Minitest::Test
  def test_basic
    result = Clamo::JSONRPC.build_result_response(id: 1, result: 42)
    assert_equal({ jsonrpc: "2.0", result: 42, id: 1 }, result)
  end

  def test_with_nil_result
    result = Clamo::JSONRPC.build_result_response(id: 1, result: nil)
    assert_equal({ jsonrpc: "2.0", result: nil, id: 1 }, result)
  end
end

class TestJSONRPCBuildErrorResponse < Minitest::Test
  def test_without_data
    result = Clamo::JSONRPC.build_error_response(id: 1, error: { code: -32_600, message: "Invalid request" })
    assert_equal({ jsonrpc: "2.0", id: 1, error: { code: -32_600, message: "Invalid request" } }, result)
    refute result[:error].key?(:data)
  end

  def test_with_data
    result = Clamo::JSONRPC.build_error_response(
      id: 1,
      error: { code: -32_603, message: "Internal error", data: "details" }
    )
    assert_equal(
      { jsonrpc: "2.0", id: 1, error: { code: -32_603, message: "Internal error", data: "details" } },
      result
    )
  end

  def test_raises_without_code
    assert_raises(ArgumentError) do
      Clamo::JSONRPC.build_error_response(id: 1, error: { message: "oops" })
    end
  end

  def test_raises_without_message
    assert_raises(ArgumentError) do
      Clamo::JSONRPC.build_error_response(id: 1, error: { code: -32_600 })
    end
  end
end

class TestJSONRPCBuildErrorResponseFrom < Minitest::Test
  def test_with_descriptor
    result = Clamo::JSONRPC.build_error_response_from(
      id: 1,
      descriptor: Clamo::JSONRPC::ProtocolErrors::METHOD_NOT_FOUND
    )
    assert_equal({ jsonrpc: "2.0", id: 1, error: { code: -32_601, message: "Method not found" } }, result)
  end

  def test_raises_without_descriptor
    assert_raises(ArgumentError) do
      Clamo::JSONRPC.build_error_response_from(id: 1)
    end
  end
end

class TestJSONRPCBuildParseError < Minitest::Test
  def test_default
    result = Clamo::JSONRPC.build_error_response_parse_error
    assert_equal({ jsonrpc: "2.0", id: nil, error: { code: -32_700, message: "Parse error" } }, result)
  end
end
