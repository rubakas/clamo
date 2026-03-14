# frozen_string_literal: true

require "test_helper"

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

class TestServerAliases < Minitest::Test
  include JSONRPCTestHelpers

  def test_dispatch_is_alias_for_parsed_dispatch_to_object
    request = jsonrpc_request(method: "method_no_params_number", id: 1)
    assert_equal expected_result(id: 1, result: 42),
                 Clamo::Server.dispatch(request: request, object: TestFixtures::ExampleService)
  end

  def test_dispatch_json_is_alias_for_unparsed_dispatch_to_object
    json = '{"jsonrpc": "2.0", "method": "method_no_params_number", "id": 1}'
    assert_equal expected_result(id: 1, result: 42),
                 Clamo::Server.dispatch_json(request: json, object: TestFixtures::ExampleService)
  end
end
