# frozen_string_literal: true

require "test_helper"

class TestServerArityCheck < Minitest::Test
  include JSONRPCTestHelpers

  def test_too_many_positional_params
    response = dispatch(jsonrpc_request(method: "method_one_params_echo", params: [1, 2, 3], id: 1))

    assert_equal(-32_602, response["error"]["code"])
  end

  def test_too_few_positional_params
    response = dispatch(jsonrpc_request(method: "method_two_params_add", params: [], id: 1))

    assert_equal(-32_602, response["error"]["code"])
  end

  def test_optional_params_accepted
    response = dispatch(jsonrpc_request(method: "method_recording", params: [], id: 1))

    assert_equal "called", response["result"]
  end

  def test_optional_params_with_value
    response = dispatch(jsonrpc_request(method: "method_recording", params: ["custom"], id: 1))

    assert_equal "custom", response["result"]
  end

  def test_nil_params_to_required_args_method
    response = dispatch(jsonrpc_request(method: "method_two_params_add", id: 1))

    assert_equal(-32_602, response["error"]["code"])
  end

  def test_unknown_keyword
    response = dispatch(jsonrpc_request(method: "method_one_named_params_echo", params: { "unknown" => 1 }, id: 1))

    assert_equal(-32_602, response["error"]["code"])
  end

  def test_missing_required_keyword
    response = dispatch(jsonrpc_request(method: "method_required_keyword", params: {}, id: 1))

    assert_equal(-32_602, response["error"]["code"])
  end

  def test_required_keyword_provided
    response = dispatch(jsonrpc_request(method: "method_required_keyword", params: { "name" => "test" }, id: 1))

    assert_equal expected_result(id: 1, result: "test"), response
  end

  def test_notification_arity_mismatch_returns_nil
    assert_nil dispatch(jsonrpc_request(method: "method_two_params_add", params: []))
  end

  def test_splat_args_accepts_any_count
    assert_equal expected_result(id: 1, result: [1, 2, 3]),
                 dispatch(jsonrpc_request(method: "method_splat_args", params: [1, 2, 3], id: 1))
  end

  def test_splat_args_accepts_zero
    assert_equal expected_result(id: 1, result: []),
                 dispatch(jsonrpc_request(method: "method_splat_args", params: [], id: 1))
  end

  def test_splat_kwargs_accepts_any_keys
    assert_equal expected_result(id: 1, result: { a: 1, b: 2 }),
                 dispatch(jsonrpc_request(method: "method_splat_kwargs", params: { "a" => 1, "b" => 2 }, id: 1))
  end

  def test_splat_kwargs_accepts_empty
    assert_equal expected_result(id: 1, result: {}),
                 dispatch(jsonrpc_request(method: "method_splat_kwargs", params: {}, id: 1))
  end

  def test_splat_kwargs_rejects_positional_params
    response = dispatch(jsonrpc_request(method: "method_splat_kwargs", params: [1], id: 1))

    assert_equal(-32_602, response["error"]["code"])
  end

  def test_mixed_positional_and_keyword_rejects_array_params
    response = dispatch(jsonrpc_request(method: "method_mixed", params: [1, 2], id: 1))

    assert_equal(-32_602, response["error"]["code"])
  end

  def test_mixed_positional_and_keyword_rejects_hash_params
    response = dispatch(jsonrpc_request(method: "method_mixed", params: { "pos" => 1, "key" => 2 }, id: 1))

    assert_equal(-32_602, response["error"]["code"])
  end
end
