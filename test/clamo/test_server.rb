# frozen_string_literal: true

require "test_helper"

class TestServer < Minitest::Test
  module ExampleModule
    class << self
      def method_no_params_nil
        nil
      end

      def method_no_params_number
        42
      end

      def method_no_params_string
        "Hello world"
      end

      def method_no_params_array
        []
      end

      def method_no_params_object
        {}
      end

      def method_one_params_echo(arg)
        arg
      end

      def method_one_params_array_echo(arg)
        [arg]
      end

      def method_one_params_object_echo(arg)
        { value: arg }
      end

      def method_one_named_params_echo(named: nil)
        named
      end
    end
  end

  PARSE_ERROR_RESPONSE = { jsonrpc: "2.0",
                           id: nil,
                           error: { code: -32_700,
                                    message: "Parse error" } }.freeze
  INVALID_REQUEST_ERROR_RESPONSE = { jsonrpc: "2.0",
                                     id: nil,
                                     error: { code: -32_600,
                                              message: "Invalid request" } }.freeze

  def with_request(req)
    @response = Clamo::Server.parsed_dispatch_to_object(
      object: ExampleModule,
      request: req
    )
  end

  def test_blank_request
    with_request({})
    assert_equal INVALID_REQUEST_ERROR_RESPONSE, @response
  end

  def test_number_request
    with_request(1)
    assert_equal INVALID_REQUEST_ERROR_RESPONSE, @response
  end

  def test_string_request
    with_request("")
    assert_equal INVALID_REQUEST_ERROR_RESPONSE, @response
  end

  def test_unknown_method_request
    with_request({ "jsonrpc" => "2.0", "method" => "unknown_method", "id" => 1 })
    method_not_found_response = { jsonrpc: "2.0", id: 1, error: { code: -32_601, message: "Method not found" } }
    assert_equal method_not_found_response, @response
  end

  def test_unknown_method_notification
    with_request({ "jsonrpc" => "2.0", "method" => "unknown_method" })
    assert_nil @response
  end

  def test_no_params_result_nil
    with_request({ "jsonrpc" => "2.0", "method" => "method_no_params_nil", "id" => 1 })
    assert_equal({ jsonrpc: "2.0", result: nil, id: 1 }, @response)
  end

  def test_no_params_result_number
    with_request({ "jsonrpc" => "2.0", "method" => "method_no_params_number", "id" => 1 })
    assert_equal({ jsonrpc: "2.0", result: 42, id: 1 }, @response)
  end

  def test_no_params_result_string
    with_request({ "jsonrpc" => "2.0", "method" => "method_no_params_string", "id" => 1 })
    assert_equal({ jsonrpc: "2.0", result: "Hello world", id: 1 }, @response)
  end

  def test_no_params_result_array
    with_request({ "jsonrpc" => "2.0", "method" => "method_no_params_array", "id" => 1 })
    assert_equal({ jsonrpc: "2.0", result: [], id: 1 }, @response)
  end

  def test_no_params_result_object
    with_request({ "jsonrpc" => "2.0", "method" => "method_no_params_object", "id" => 1 })
    assert_equal({ jsonrpc: "2.0", result: {}, id: 1 }, @response)
  end

  def test_one_params_result_nil
    with_request({ "jsonrpc" => "2.0", "method" => "method_one_params_echo", "params" => [nil], "id" => 1 })
    assert_equal({ jsonrpc: "2.0", result: nil, id: 1 }, @response)
  end

  def test_one_params_result_number
    with_request({ "jsonrpc" => "2.0", "method" => "method_one_params_echo", "params" => [42], "id" => 1 })
    assert_equal({ jsonrpc: "2.0", result: 42, id: 1 }, @response)
  end

  def test_one_params_result_string
    with_request({ "jsonrpc" => "2.0", "method" => "method_one_params_echo", "params" => ["hello"], "id" => 1 })
    assert_equal({ jsonrpc: "2.0", result: "hello", id: 1 }, @response)
  end

  def test_one_params_result_array
    with_request({ "jsonrpc" => "2.0", "method" => "method_one_params_echo", "params" => [[]], "id" => 1 })
    assert_equal({ jsonrpc: "2.0", result: [], id: 1 }, @response)
  end

  def test_one_params_result_object
    with_request({ "jsonrpc" => "2.0", "method" => "method_one_params_echo", "params" => [{}], "id" => 1 })
    assert_equal({ jsonrpc: "2.0", result: {}, id: 1 }, @response)
  end

  def test_one_params_result_object_non_empty
    with_request({ "jsonrpc" => "2.0", "method" => "method_one_params_echo", "params" => [{ "e" => "cho" }],
                   "id" => 1 })
    assert_equal({ jsonrpc: "2.0", result: { "e" => "cho" }, id: 1 }, @response)
  end

  def test_one_param_result_named
    with_request({ "jsonrpc" => "2.0", "method" => "method_one_named_params_echo", "params" => { "named" => "value" },
                   "id" => 1 })
    assert_equal({ jsonrpc: "2.0", result: "value", id: 1 }, @response)
  end

  def test_one_params_result_nil_in_array
    with_request({ "jsonrpc" => "2.0", "method" => "method_one_params_array_echo", "params" => [nil], "id" => 1 })
    assert_equal({ jsonrpc: "2.0", result: [nil], id: 1 }, @response)
  end

  def test_one_params_result_nil_in_object
    with_request({ "jsonrpc" => "2.0", "method" => "method_one_params_object_echo", "params" => [nil], "id" => 1 })
    assert_equal({ jsonrpc: "2.0", result: { value: nil }, id: 1 }, @response)
  end

  def test_one_params_result_object_in_object
    with_request({ "jsonrpc" => "2.0", "method" => "method_one_params_object_echo", "params" => [{}], "id" => 1 })
    assert_equal({ jsonrpc: "2.0", result: { value: {} }, id: 1 }, @response)
  end

  def test_invalid_pragma
    with_request({ "xmlrpc" => "2.0", "method" => "method_one_params_echo", "params" => "invalid", "id" => 1 })
    assert_equal({ jsonrpc: "2.0", id: 1, error: { code: -32_600, message: "Invalid request" } }, @response)
  end

  def test_invalid_pragma_version
    with_request({ "jsonrpc" => "4.2", "method" => "method_one_params_echo", "params" => "invalid", "id" => 1 })
    assert_equal({ jsonrpc: "2.0", id: 1, error: { code: -32_600, message: "Invalid request" } }, @response)
  end

  def test_invalid_params_type_string
    with_request({ "jsonrpc" => "2.0", "method" => "method_one_params_echo", "params" => "invalid", "id" => 1 })
    assert_equal({ jsonrpc: "2.0", id: 1, error: { code: -32_602, message: "Invalid params" } }, @response)
  end

  def test_invalid_params_type_number
    with_request({ "jsonrpc" => "2.0", "method" => "method_one_params_echo", "params" => 42, "id" => 1 })
    assert_equal({ jsonrpc: "2.0", id: 1, error: { code: -32_602, message: "Invalid params" } }, @response)
  end
end
