# frozen_string_literal: true

require "test_helper"

class TestServerNotificationExecution < Minitest::Test
  include JSONRPCTestHelpers

  def setup
    TestFixtures::ExampleService.reset_test_state!
  end

  def test_notification_executes_method
    result = dispatch(jsonrpc_request(method: "method_recording"))
    assert_nil result
    assert_equal "called", TestFixtures::ExampleService.last_recording
  end

  def test_notification_with_params_executes_method
    result = dispatch(jsonrpc_request(method: "method_recording", params: ["custom_value"]))
    assert_nil result
    assert_equal "custom_value", TestFixtures::ExampleService.last_recording
  end
end
