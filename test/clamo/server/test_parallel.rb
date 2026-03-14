# frozen_string_literal: true

require "test_helper"

class TestServerParallel < Minitest::Test
  include JSONRPCTestHelpers

  def test_batch_dispatches_through_parallel_when_available
    batch = [
      jsonrpc_request(method: "method_no_params_number", id: 1),
      jsonrpc_request(method: "method_no_params_string", id: 2),
      jsonrpc_request(method: "method_returns_false", id: 3)
    ]

    response = dispatch(batch)

    assert_equal 3, response.size
    assert_equal expected_result(id: 1, result: 42), response[0]
    assert_equal expected_result(id: 2, result: "Hello world"), response[1]
    assert_equal expected_result(id: 3, result: false), response[2]
  end

  def test_batch_produces_correct_results_via_sequential_fallback
    batch = [
      jsonrpc_request(method: "method_no_params_number", id: 1),
      jsonrpc_request(method: "method_no_params_string", id: 2)
    ]

    fallback = ->(items, **, &block) { items.map(&block) }
    response = Clamo::Server.stub(:map_batch, fallback) do
      dispatch(batch)
    end

    assert_equal 2, response.size
    assert_equal expected_result(id: 1, result: 42), response[0]
    assert_equal expected_result(id: 2, result: "Hello world"), response[1]
  end

  def test_keyword_arguments_forwarded_to_parallel_map
    batch = [
      jsonrpc_request(method: "method_no_params_number", id: 1),
      jsonrpc_request(method: "method_no_params_string", id: 2)
    ]

    response = Clamo::Server.dispatch(
      request: batch,
      object: TestFixtures::ExampleService,
      in_threads: 2
    )

    assert_equal 2, response.size
    assert_equal expected_result(id: 1, result: 42), response[0]
    assert_equal expected_result(id: 2, result: "Hello world"), response[1]
  end

  def test_keyword_arguments_silently_ignored_for_single_request
    request = jsonrpc_request(method: "method_no_params_number", id: 1)

    response = Clamo::Server.dispatch(
      request: request,
      object: TestFixtures::ExampleService,
      in_threads: 2
    )

    assert_equal expected_result(id: 1, result: 42), response
  end

  def test_sequential_fallback_handles_mixed_requests_and_notifications
    batch = [
      jsonrpc_request(method: "method_no_params_number", id: 1),
      jsonrpc_request(method: "method_no_params_string")
    ]

    fallback = ->(items, **, &block) { items.map(&block) }
    response = Clamo::Server.stub(:map_batch, fallback) do
      dispatch(batch)
    end

    assert_equal 1, response.size
    assert_equal expected_result(id: 1, result: 42), response[0]
  end
end
