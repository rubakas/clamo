# frozen_string_literal: true

require "test_helper"

class TestServerValidation < Minitest::Test
  include JSONRPCTestHelpers

  def test_blank_request
    assert_equal invalid_request_response, dispatch({})
  end

  def test_number_request
    assert_equal invalid_request_response, dispatch(1)
  end

  def test_string_request
    assert_equal invalid_request_response, dispatch("")
  end

  def test_invalid_pragma
    assert_equal invalid_request_response(id: 1),
                 dispatch({ "xmlrpc" => "2.0", "method" => "method_one_params_echo", "id" => 1 })
  end

  def test_invalid_pragma_version
    request = { "jsonrpc" => "4.2", "method" => "method_one_params_echo", "params" => "invalid", "id" => 1 }
    assert_equal invalid_request_response(id: 1), dispatch(request)
  end

  def test_invalid_params_type_string
    assert_equal invalid_params_response(id: 1),
                 dispatch(jsonrpc_request(method: "method_one_params_echo", params: "invalid", id: 1))
  end

  def test_invalid_params_type_number
    assert_equal invalid_params_response(id: 1),
                 dispatch(jsonrpc_request(method: "method_one_params_echo", params: 42, id: 1))
  end

  def test_unknown_method_request
    assert_equal method_not_found_response(id: 1),
                 dispatch(jsonrpc_request(method: "unknown_method", id: 1))
  end

  def test_unknown_method_notification
    assert_nil dispatch(jsonrpc_request(method: "unknown_method"))
  end

  def test_empty_string_method_returns_method_not_found
    assert_equal method_not_found_response(id: 1),
                 dispatch(jsonrpc_request(method: "", id: 1))
  end

  def test_notification_with_invalid_params_returns_nil
    assert_nil dispatch(jsonrpc_request(method: "method_one_params_echo", params: "invalid"))
  end

  def test_private_method_request_returns_method_not_found
    assert_equal method_not_found_response(id: 1),
                 dispatch(jsonrpc_request(method: "secret_method", id: 1))
  end

  def test_private_method_notification_silently_ignored
    assert_nil dispatch(jsonrpc_request(method: "secret_method"))
  end

  def test_method_that_raises_returns_internal_error
    response = dispatch(jsonrpc_request(method: "method_that_raises", id: 1))

    assert_equal "2.0", response[:jsonrpc]
    assert_equal 1, response[:id]
    assert_equal(-32_603, response[:error][:code])
    assert_equal "Internal error", response[:error][:message]
    refute response[:error].key?(:data)
  end

  def test_method_that_raises_calls_on_error
    captured = []
    Clamo::Server.on_error = ->(e, method, _params) { captured << { error: e, method: method } }

    dispatch(jsonrpc_request(method: "method_that_raises", id: 1))

    assert_equal 1, captured.size
    assert_equal "method_that_raises", captured[0][:method]
    assert_equal "something went wrong", captured[0][:error].message
  ensure
    Clamo::Server.on_error = nil
  end

  def test_too_many_params_returns_internal_error
    response = dispatch(jsonrpc_request(method: "method_no_params_number", params: [1, 2], id: 1))

    assert_equal(-32_603, response[:error][:code])
  end

  def test_too_few_params_returns_internal_error
    response = dispatch(jsonrpc_request(method: "method_two_params_add", params: [1], id: 1))

    assert_equal(-32_603, response[:error][:code])
  end
end

class TestServerDispatch < Minitest::Test
  include JSONRPCTestHelpers

  def test_no_params_result_nil
    assert_equal expected_result(id: 1, result: nil),
                 dispatch(jsonrpc_request(method: "method_no_params_nil", id: 1))
  end

  def test_no_params_result_number
    assert_equal expected_result(id: 1, result: 42),
                 dispatch(jsonrpc_request(method: "method_no_params_number", id: 1))
  end

  def test_no_params_result_string
    assert_equal expected_result(id: 1, result: "Hello world"),
                 dispatch(jsonrpc_request(method: "method_no_params_string", id: 1))
  end

  def test_no_params_result_array
    assert_equal expected_result(id: 1, result: []),
                 dispatch(jsonrpc_request(method: "method_no_params_array", id: 1))
  end

  def test_no_params_result_object
    assert_equal expected_result(id: 1, result: {}),
                 dispatch(jsonrpc_request(method: "method_no_params_object", id: 1))
  end

  def test_one_positional_param_nil
    assert_equal expected_result(id: 1, result: nil),
                 dispatch(jsonrpc_request(method: "method_one_params_echo", params: [nil], id: 1))
  end

  def test_one_positional_param_number
    assert_equal expected_result(id: 1, result: 42),
                 dispatch(jsonrpc_request(method: "method_one_params_echo", params: [42], id: 1))
  end

  def test_one_positional_param_string
    assert_equal expected_result(id: 1, result: "hello"),
                 dispatch(jsonrpc_request(method: "method_one_params_echo", params: ["hello"], id: 1))
  end

  def test_one_positional_param_array
    assert_equal expected_result(id: 1, result: []),
                 dispatch(jsonrpc_request(method: "method_one_params_echo", params: [[]], id: 1))
  end

  def test_one_positional_param_object
    assert_equal expected_result(id: 1, result: {}),
                 dispatch(jsonrpc_request(method: "method_one_params_echo", params: [{}], id: 1))
  end

  def test_one_positional_param_non_empty_object
    assert_equal expected_result(id: 1, result: { "e" => "cho" }),
                 dispatch(jsonrpc_request(method: "method_one_params_echo", params: [{ "e" => "cho" }], id: 1))
  end

  def test_one_named_param
    request = jsonrpc_request(method: "method_one_named_params_echo", params: { "named" => "value" }, id: 1)
    assert_equal expected_result(id: 1, result: "value"), dispatch(request)
  end

  def test_two_positional_params
    assert_equal expected_result(id: 1, result: 3),
                 dispatch(jsonrpc_request(method: "method_two_params_add", params: [1, 2], id: 1))
  end

  def test_result_wrapped_in_array
    assert_equal expected_result(id: 1, result: [nil]),
                 dispatch(jsonrpc_request(method: "method_one_params_array_echo", params: [nil], id: 1))
  end

  def test_result_wrapped_in_object
    assert_equal expected_result(id: 1, result: { value: nil }),
                 dispatch(jsonrpc_request(method: "method_one_params_object_echo", params: [nil], id: 1))
  end

  def test_result_object_in_object
    assert_equal expected_result(id: 1, result: { value: {} }),
                 dispatch(jsonrpc_request(method: "method_one_params_object_echo", params: [{}], id: 1))
  end

  def test_explicit_null_id_returns_response
    assert_equal expected_result(id: nil, result: 42),
                 dispatch(jsonrpc_request(method: "method_no_params_number", id: nil))
  end

  def test_string_id
    assert_equal expected_result(id: "abc", result: 42),
                 dispatch(jsonrpc_request(method: "method_no_params_number", id: "abc"))
  end
end

class TestServerSymbolKeyDispatch < Minitest::Test
  include JSONRPCTestHelpers

  def test_symbol_key_request
    request = { jsonrpc: "2.0", method: "method_no_params_number", id: 1 }
    assert_equal expected_result(id: 1, result: 42), dispatch(request)
  end

  def test_symbol_key_request_with_params
    request = { jsonrpc: "2.0", method: "method_two_params_add", params: [1, 2], id: 1 }
    assert_equal expected_result(id: 1, result: 3), dispatch(request)
  end

  def test_symbol_key_notification
    request = { jsonrpc: "2.0", method: "method_no_params_number" }
    assert_nil dispatch(request)
  end

  def test_symbol_key_batch
    response = dispatch([
                          { jsonrpc: "2.0", method: "method_no_params_number", id: 1 },
                          { jsonrpc: "2.0", method: "method_no_params_string", id: 2 }
                        ])

    assert_instance_of Array, response
    assert_equal 2, response.size
    assert_equal expected_result(id: 1, result: 42), response[0]
    assert_equal expected_result(id: 2, result: "Hello world"), response[1]
  end

  def test_symbol_key_invalid_request
    assert_equal invalid_request_response(id: 1), dispatch({ jsonrpc: "1.0", method: "test", id: 1 })
  end
end

class TestServerUnparsedDispatch < Minitest::Test
  include JSONRPCTestHelpers

  def test_valid_json
    assert_equal expected_result(id: 1, result: 42),
                 dispatch_raw('{"jsonrpc": "2.0", "method": "method_no_params_number", "id": 1}')
  end

  def test_invalid_json
    assert_equal parse_error_response, dispatch_raw("not json at all")
  end

  def test_batch_json
    json = '[{"jsonrpc": "2.0", "method": "method_no_params_number", "id": 1}, ' \
           '{"jsonrpc": "2.0", "method": "method_no_params_string", "id": 2}]'
    response = dispatch_raw(json)

    assert_instance_of Array, response
    assert_equal 2, response.size
    assert_equal expected_result(id: 1, result: 42), response[0]
    assert_equal expected_result(id: 2, result: "Hello world"), response[1]
  end
end

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

class TestServerHandle < Minitest::Test
  include JSONRPCTestHelpers

  def test_returns_json_string_for_request
    json = handle('{"jsonrpc": "2.0", "method": "method_no_params_number", "id": 1}')

    assert_instance_of String, json
    parsed = JSON.parse(json, symbolize_names: true)
    assert_equal({ jsonrpc: "2.0", result: 42, id: 1 }, parsed)
  end

  def test_returns_json_string_for_error
    json = handle("not json")

    parsed = JSON.parse(json, symbolize_names: true)
    assert_equal(-32_700, parsed[:error][:code])
  end

  def test_returns_nil_for_notification
    assert_nil handle('{"jsonrpc": "2.0", "method": "method_no_params_number"}')
  end

  def test_returns_json_array_for_batch
    json = handle('[{"jsonrpc": "2.0", "method": "method_no_params_number", "id": 1}]')

    parsed = JSON.parse(json, symbolize_names: true)
    assert_instance_of Array, parsed
    assert_equal 1, parsed.size
    assert_equal 42, parsed[0][:result]
  end

  def test_returns_timeout_error_as_json
    original_timeout = Clamo::Server.timeout
    Clamo::Server.timeout = 0.1

    json = handle('{"jsonrpc": "2.0", "method": "method_slow", "params": [1], "id": 1}')

    parsed = JSON.parse(json, symbolize_names: true)
    assert_equal(-32_000, parsed[:error][:code])
    assert_equal "Request timed out", parsed[:error][:data]
  ensure
    Clamo::Server.timeout = original_timeout
  end
end

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

class TestServerBeforeDispatch < Minitest::Test
  include JSONRPCTestHelpers

  def teardown
    Clamo::Server.before_dispatch = nil
  end

  def test_called_with_method_and_params
    captured = []
    Clamo::Server.before_dispatch = ->(method, params) { captured << { method: method, params: params } }

    dispatch(jsonrpc_request(method: "method_two_params_add", params: [1, 2], id: 1))

    assert_equal 1, captured.size
    assert_equal "method_two_params_add", captured[0][:method]
    assert_equal [1, 2], captured[0][:params]
  end

  def test_raising_halts_dispatch_and_returns_error
    Clamo::Server.before_dispatch = ->(_method, _params) { raise "unauthorized" }

    response = dispatch(jsonrpc_request(method: "method_no_params_number", id: 1))

    assert_equal(-32_603, response[:error][:code])
  end

  def test_raising_halts_notification
    TestFixtures::ExampleService.reset_test_state!
    Clamo::Server.before_dispatch = ->(_method, _params) { raise "blocked" }

    dispatch(jsonrpc_request(method: "method_recording"))

    assert_nil TestFixtures::ExampleService.last_recording
  end

  def test_called_for_notifications
    captured = []
    Clamo::Server.before_dispatch = ->(method, _params) { captured << method }

    dispatch(jsonrpc_request(method: "method_no_params_number"))

    assert_equal ["method_no_params_number"], captured
  end
end

class TestServerAfterDispatch < Minitest::Test
  include JSONRPCTestHelpers

  def teardown
    Clamo::Server.after_dispatch = nil
  end

  def test_called_with_method_params_and_result
    captured = []
    Clamo::Server.after_dispatch = lambda { |method, params, result|
      captured << { method: method, params: params, result: result }
    }

    dispatch(jsonrpc_request(method: "method_two_params_add", params: [1, 2], id: 1))

    assert_equal 1, captured.size
    assert_equal "method_two_params_add", captured[0][:method]
    assert_equal [1, 2], captured[0][:params]
    assert_equal 3, captured[0][:result]
  end

  def test_not_called_on_error
    captured = []
    Clamo::Server.after_dispatch = ->(method, _params, _result) { captured << method }

    dispatch(jsonrpc_request(method: "method_that_raises", id: 1))

    assert_empty captured
  end

  def test_called_for_notifications_with_nil_result
    captured = []
    Clamo::Server.after_dispatch = lambda { |method, _params, result|
      captured << { method: method, result: result }
    }

    dispatch(jsonrpc_request(method: "method_no_params_number"))

    assert_equal 1, captured.size
    assert_nil captured[0][:result]
  end
end

class TestServerArgumentValidation < Minitest::Test
  def test_nil_object_raises_argument_error
    assert_raises(ArgumentError) do
      Clamo::Server.unparsed_dispatch_to_object(
        request: '{"jsonrpc": "2.0", "method": "test", "id": 1}',
        object: nil
      )
    end
  end

  def test_nil_object_raises_argument_error_for_parsed_dispatch
    assert_raises(ArgumentError) do
      Clamo::Server.parsed_dispatch_to_object(
        request: { "jsonrpc" => "2.0", "method" => "test", "id" => 1 },
        object: nil
      )
    end
  end
end

class TestServerTimeout < Minitest::Test
  include JSONRPCTestHelpers

  def setup
    @original_timeout = Clamo::Server.timeout
    Clamo::Server.timeout = 0.1
  end

  def teardown
    Clamo::Server.timeout = @original_timeout
  end

  def test_default_timeout_is_thirty_seconds
    assert_equal 30, @original_timeout
  end

  def test_request_timeout_returns_server_error
    response = dispatch(jsonrpc_request(method: "method_slow", params: [1], id: 1))

    assert_equal(-32_000, response[:error][:code])
    assert_equal "Server error", response[:error][:message]
    assert_equal "Request timed out", response[:error][:data]
  end

  def test_notification_timeout_calls_on_error
    captured = []
    Clamo::Server.on_error = ->(e, method, _params) { captured << { error: e, method: method } }

    dispatch(jsonrpc_request(method: "method_slow", params: [1]))

    assert_equal 1, captured.size
    assert_kind_of Timeout::Error, captured[0][:error]
  ensure
    Clamo::Server.on_error = nil
  end

  def test_nil_timeout_disables_enforcement
    Clamo::Server.timeout = nil
    response = dispatch(jsonrpc_request(method: "method_no_params_number", id: 1))

    assert_equal 42, response[:result]
  end

  def test_fast_method_succeeds_within_timeout
    response = dispatch(jsonrpc_request(method: "method_no_params_number", id: 1))

    assert_equal 42, response[:result]
  end
end
