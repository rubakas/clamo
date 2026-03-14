# frozen_string_literal: true

require "test_helper"

class TestServerBatch < Minitest::Test
  include JSONRPCTestHelpers

  def test_normal_requests
    response = dispatch([
                          jsonrpc_request(method: "method_no_params_number", id: 1),
                          jsonrpc_request(method: "method_no_params_string", id: 2)
                        ])

    assert_instance_of Array, response
    assert_equal 2, response.size
    assert_equal expected_result(id: 1, result: 42), response[0]
    assert_equal expected_result(id: 2, result: "Hello world"), response[1]
  end

  def test_mixed_requests_and_notifications
    response = dispatch([
                          jsonrpc_request(method: "method_no_params_number", id: 1),
                          jsonrpc_request(method: "method_no_params_string")
                        ])

    assert_instance_of Array, response
    assert_equal 1, response.size
    assert_equal expected_result(id: 1, result: 42), response[0]
  end

  def test_all_notifications_returns_nil
    assert_nil dispatch([
                          jsonrpc_request(method: "method_no_params_number"),
                          jsonrpc_request(method: "method_no_params_string")
                        ])
  end

  def test_single_item_batch
    response = dispatch([jsonrpc_request(method: "method_no_params_number", id: 1)])

    assert_instance_of Array, response
    assert_equal 1, response.size
    assert_equal expected_result(id: 1, result: 42), response[0]
  end

  def test_single_notification_batch_returns_nil
    assert_nil dispatch([jsonrpc_request(method: "method_no_params_number")])
  end

  def test_empty_array_returns_invalid_request
    assert_equal invalid_request_response, dispatch([])
  end
end

class TestServerBatchMixedErrors < Minitest::Test
  include JSONRPCTestHelpers

  def test_batch_with_success_and_method_not_found
    batch = [
      jsonrpc_request(method: "method_no_params_number", id: 1),
      jsonrpc_request(method: "nonexistent_method", id: 2)
    ]

    response = dispatch(batch)

    assert_equal 2, response.size
    assert_equal expected_result(id: 1, result: 42), response[0]
    assert_equal method_not_found_response(id: 2), response[1]
  end

  def test_batch_with_success_and_exception
    batch = [
      jsonrpc_request(method: "method_no_params_number", id: 1),
      jsonrpc_request(method: "method_that_raises", id: 2)
    ]

    response = dispatch(batch)

    assert_equal 2, response.size
    assert_equal expected_result(id: 1, result: 42), response[0]
    assert_equal server_error_response(id: 2), response[1]
  end

  def test_batch_with_success_and_invalid_params
    batch = [
      jsonrpc_request(method: "method_no_params_number", id: 1),
      jsonrpc_request(method: "method_two_params_add", params: [1], id: 2)
    ]

    response = dispatch(batch)

    assert_equal 2, response.size
    assert_equal expected_result(id: 1, result: 42), response[0]
    assert_equal invalid_params_response(id: 2), response[1]
  end

  def test_batch_with_all_failures
    batch = [
      jsonrpc_request(method: "nonexistent_method", id: 1),
      jsonrpc_request(method: "method_that_raises", id: 2),
      jsonrpc_request(method: "method_two_params_add", params: [1], id: 3)
    ]
    response = dispatch(batch)

    assert_equal 3, response.size
    error_codes = response.map { |r| r["error"]["code"] }
    assert_equal [-32_601, -32_000, -32_602], error_codes
  end

  def test_batch_with_notification_that_raises
    batch = [
      jsonrpc_request(method: "method_no_params_number", id: 1),
      jsonrpc_request(method: "method_that_raises")
    ]

    response = dispatch(batch)

    assert_equal 1, response.size
    assert_equal expected_result(id: 1, result: 42), response[0]
  end
end

class TestServerBatchNonHashItems < Minitest::Test
  include JSONRPCTestHelpers

  def test_batch_with_integer_item_returns_invalid_request
    response = dispatch([
                          jsonrpc_request(method: "method_no_params_number", id: 1),
                          42
                        ])

    assert_equal 2, response.size
    assert_equal expected_result(id: 1, result: 42), response[0]
    assert_equal invalid_request_response, response[1]
  end

  def test_batch_with_string_item_returns_invalid_request
    response = dispatch([
                          jsonrpc_request(method: "method_no_params_number", id: 1),
                          "not a hash"
                        ])

    assert_equal 2, response.size
    assert_equal expected_result(id: 1, result: 42), response[0]
    assert_equal invalid_request_response, response[1]
  end

  def test_batch_with_null_item_returns_invalid_request
    response = dispatch([
                          jsonrpc_request(method: "method_no_params_number", id: 1),
                          nil
                        ])

    assert_equal 2, response.size
    assert_equal expected_result(id: 1, result: 42), response[0]
    assert_equal invalid_request_response, response[1]
  end

  def test_batch_of_all_non_hash_items
    response = dispatch([1, "two", nil])

    assert_equal 3, response.size
    response.each { |r| assert_equal invalid_request_response, r }
  end
end
