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
                 dispatch({ "xmlrpc" => "2.0", "method" => "method_one_params_echo", "params" => "invalid", "id" => 1 })
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
end

class TestServerSecurity < Minitest::Test
  include JSONRPCTestHelpers

  def test_private_method_request_returns_method_not_found
    assert_equal method_not_found_response(id: 1),
                 dispatch(jsonrpc_request(method: "secret_method", id: 1))
  end

  def test_private_method_notification_silently_ignored
    assert_nil dispatch(jsonrpc_request(method: "secret_method"))
  end
end

class TestServerExceptionHandling < Minitest::Test
  include JSONRPCTestHelpers

  def test_method_that_raises_returns_internal_error
    response = dispatch(jsonrpc_request(method: "method_that_raises", id: 1))

    assert_equal "2.0", response[:jsonrpc]
    assert_equal 1, response[:id]
    assert_equal(-32_603, response[:error][:code])
    assert_equal "Internal error", response[:error][:message]
    assert_equal "something went wrong", response[:error][:data]
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
    sleep 0.1 # allow thread to execute

    assert_equal 1, @captured_errors.size
    assert_equal "method_that_raises", @captured_errors[0][:method]
    assert_equal "something went wrong", @captured_errors[0][:error].message
  end

  def test_notification_error_without_callback_does_not_raise
    Clamo::Server.on_error = nil
    assert_nil dispatch(jsonrpc_request(method: "method_that_raises"))
    sleep 0.1 # allow thread to finish without blowing up
  end
end
