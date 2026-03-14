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
