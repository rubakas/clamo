# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "clamo"

require "minitest/autorun"
require "minitest/pride"

module TestFixtures
  module ExampleService
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

      def method_required_keyword(name:)
        name
      end

      def method_two_params_add(left, right)
        left + right
      end

      def method_recording(value = "called")
        @last_recording = value
      end

      attr_reader :last_recording

      def reset_test_state!
        @last_recording = nil
      end

      def method_that_raises
        raise "something went wrong"
      end

      def method_slow(duration = 2)
        sleep(duration)
        "done"
      end

      private

      def secret_method
        "should not be accessible"
      end
    end
  end
end

module JSONRPCTestHelpers
  private

  def jsonrpc_request(method:, params: :omit, id: :omit)
    req = { "jsonrpc" => "2.0", "method" => method }
    req["params"] = params unless params == :omit
    req["id"] = id unless id == :omit
    req
  end

  def dispatch(request)
    Clamo::Server.parsed_dispatch_to_object(
      object: TestFixtures::ExampleService,
      request: request
    )
  end

  def dispatch_raw(json)
    Clamo::Server.unparsed_dispatch_to_object(
      object: TestFixtures::ExampleService,
      request: json
    )
  end

  def handle(json)
    Clamo::Server.handle(
      object: TestFixtures::ExampleService,
      request: json
    )
  end

  def expected_result(id:, result:)
    { "jsonrpc" => "2.0", "result" => result, "id" => id }
  end

  def expected_error(id:, descriptor:)
    { "jsonrpc" => "2.0", "id" => id, "error" => { "code" => descriptor.code, "message" => descriptor.message } }
  end

  def parse_error_response
    expected_error(id: nil, descriptor: Clamo::JSONRPC::ProtocolErrors::PARSE_ERROR)
  end

  def invalid_request_response(id: nil)
    expected_error(id: id, descriptor: Clamo::JSONRPC::ProtocolErrors::INVALID_REQUEST)
  end

  def method_not_found_response(id:)
    expected_error(id: id, descriptor: Clamo::JSONRPC::ProtocolErrors::METHOD_NOT_FOUND)
  end

  def invalid_params_response(id:)
    expected_error(id: id, descriptor: Clamo::JSONRPC::ProtocolErrors::INVALID_PARAMS)
  end
end
