# frozen_string_literal: true

require "test_helper"

class TestServerOnError < Minitest::Test
  include JSONRPCTestHelpers

  def setup
    @captured_errors = []
    Clamo::Server.on_error = lambda { |e, method, _params|
      @captured_errors << { error: e, method: method }
    }
  end

  def teardown
    Clamo::Server.on_error = nil
  end

  def test_notification_error_calls_on_error
    dispatch(jsonrpc_request(method: "method_that_raises"))

    assert_equal 1, @captured_errors.size
    assert_equal "method_that_raises", @captured_errors[0][:method]
    assert_equal "something went wrong", @captured_errors[0][:error].message
  end

  def test_notification_error_without_callback_does_not_raise
    Clamo::Server.on_error = nil
    assert_nil dispatch(jsonrpc_request(method: "method_that_raises"))
  end
end

class TestServerPerCallConfig < Minitest::Test
  include JSONRPCTestHelpers

  def test_per_call_on_error_overrides_default
    captured = []
    response = Clamo::Server.dispatch(
      request: jsonrpc_request(method: "method_that_raises", id: 1),
      object: TestFixtures::ExampleService,
      on_error: ->(e, method, _params) { captured << { error: e, method: method } }
    )

    assert_equal(-32_000, response["error"]["code"])
    assert_equal 1, captured.size
    assert_equal "something went wrong", captured[0][:error].message
  end

  def test_per_call_config_does_not_affect_module_defaults
    assert_nil Clamo::Server.on_error

    Clamo::Server.dispatch(
      request: jsonrpc_request(method: "method_that_raises", id: 1),
      object: TestFixtures::ExampleService,
      on_error: ->(_e, _m, _p) {}
    )

    assert_nil Clamo::Server.on_error
  end

  def test_per_call_config_flows_through_handle
    captured = []
    Clamo::Server.handle_json(
      request: '{"jsonrpc": "2.0", "method": "method_that_raises", "id": 1}',
      object: TestFixtures::ExampleService,
      on_error: ->(e, method, _params) { captured << { error: e, method: method } }
    )

    assert_equal 1, captured.size
    assert_equal "something went wrong", captured[0][:error].message
  end
end
