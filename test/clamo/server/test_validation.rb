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

  def test_method_that_raises_returns_server_error
    response = dispatch(jsonrpc_request(method: "method_that_raises", id: 1))

    assert_equal "2.0", response["jsonrpc"]
    assert_equal 1, response["id"]
    assert_equal(-32_000, response["error"]["code"])
    assert_equal "Server error", response["error"]["message"]
    refute response["error"].key?("data")
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

  def test_too_many_params_returns_invalid_params
    response = dispatch(jsonrpc_request(method: "method_no_params_number", params: [1, 2], id: 1))

    assert_equal(-32_602, response["error"]["code"])
  end

  def test_too_few_params_returns_invalid_params
    response = dispatch(jsonrpc_request(method: "method_two_params_add", params: [1], id: 1))

    assert_equal(-32_602, response["error"]["code"])
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
