# frozen_string_literal: true

require "json"
require "parallel"
require "timeout"

module Clamo
  module Server
    Config = Data.define(:timeout, :on_error, :before_dispatch, :after_dispatch)

    class << self
      # Module-level defaults. These are snapshotted at the start of each
      # dispatch call, so mutations mid-request do not affect in-flight work.
      # All four can be overridden per-call via keyword arguments.
      attr_accessor :on_error, :before_dispatch, :after_dispatch
      attr_writer :timeout

      def timeout
        return @timeout if defined?(@timeout)

        30
      end

      # JSON string in, JSON string out. Full round-trip for HTTP/socket integrations.
      #
      #   Clamo::Server.handle(request: body, object: MyService)
      #
      def handle(request:, object:, **)
        response = unparsed_dispatch_to_object(request: request, object: object, **)
        response&.to_json
      end

      # Clamo::Server.unparsed_dispatch_to_object(
      #   request:  request_body,
      #   object:   MyModule
      # )
      def unparsed_dispatch_to_object(request:, object:, **)
        raise ArgumentError, "object is required" unless object

        begin
          parsed = JSON.parse(request)
        rescue JSON::JSONError
          return JSONRPC.build_error_response_parse_error
        end

        parsed_dispatch_to_object(request: parsed, object: object, **)
      end

      def parsed_dispatch_to_object(request:, object:,
                                    timeout: self.timeout,
                                    on_error: self.on_error,
                                    before_dispatch: self.before_dispatch,
                                    after_dispatch: self.after_dispatch,
                                    **opts)
        raise ArgumentError, "object is required" unless object

        request = normalize_request_keys(request)
        config = Config.new(timeout: timeout, on_error: on_error,
                            before_dispatch: before_dispatch, after_dispatch: after_dispatch)

        response_for(request: request, object: object, config: config, **opts) do |method, params|
          dispatch_to_ruby(object: object, method: method, params: params)
        end
      end

      private

      def normalize_request_keys(request)
        case request
        when Hash  then request.transform_keys(&:to_s)
        when Array then request.map { |r| r.is_a?(Hash) ? r.transform_keys(&:to_s) : r }
        else request
        end
      end

      def method_known?(object:, method:)
        object.public_methods(false).map(&:to_sym).include?(method.to_sym)
      end

      def dispatch_to_ruby(object:, method:, params:)
        case params
        when Array    then object.public_send(method.to_sym, *params)
        when Hash     then object.public_send(method.to_sym, **params.transform_keys(&:to_sym))
        when NilClass then object.public_send(method.to_sym)
        end
      end

      # Extra keyword arguments (**) are forwarded to response_for_batch only,
      # where they become options for Parallel.map (e.g., in_processes: 4).
      # For single requests they are silently ignored.
      def response_for(request:, object:, config:, **, &block)
        case request
        when Array
          response_for_batch(request: request, object: object, block: block, config: config, **)
        when Hash
          response_for_single_request(request: request, object: object, block: block, config: config)
        else
          JSONRPC.build_error_response_from(id: nil, descriptor: JSONRPC::ProtocolErrors::INVALID_REQUEST)
        end
      end

      def response_for_single_request(request:, object:, block:, config:)
        error = validate_request_structure(request)
        return error if error

        unless method_known?(object: object, method: request["method"])
          return request.key?("id") ? method_not_found_error(request) : nil
        end

        return dispatch_notification(request, block, config) unless request.key?("id")

        dispatch_request(request, block, config)
      end

      def response_for_batch(request:, object:, block:, config:, **opts)
        if request.empty?
          return JSONRPC.build_error_response_from(id: nil, descriptor: JSONRPC::ProtocolErrors::INVALID_REQUEST)
        end

        if request.size == 1
          result = response_for_single_request(request: request.first, object: object, block: block, config: config)
          return result ? [result] : nil
        end

        result = Parallel.map(request, **opts) do |item|
          response_for_single_request(request: item, object: object, block: block, config: config)
        end.compact
        result.empty? ? nil : result
      end

      def validate_request_structure(request)
        unless JSONRPC.valid_request?(request)
          return JSONRPC.build_error_response_from(
            id: request.is_a?(Hash) ? request["id"] : nil,
            descriptor: JSONRPC::ProtocolErrors::INVALID_REQUEST
          )
        end

        return if JSONRPC.proper_params_if_any?(request)

        # Notifications must never produce a response, even for invalid params
        return nil unless request.key?("id")

        JSONRPC.build_error_response_from(id: request["id"], descriptor: JSONRPC::ProtocolErrors::INVALID_PARAMS)
      end

      def method_not_found_error(request)
        JSONRPC.build_error_response_from(id: request["id"], descriptor: JSONRPC::ProtocolErrors::METHOD_NOT_FOUND)
      end

      def dispatch_notification(request, block, config)
        method = request["method"]
        params = request["params"]
        config.before_dispatch&.call(method, params)
        with_timeout(config.timeout) { block.yield(method, params) }
        config.after_dispatch&.call(method, params, nil)
        nil
      rescue StandardError => e
        config.on_error&.call(e, method, params)
        nil
      end

      def dispatch_request(request, block, config)
        method = request["method"]
        params = request["params"]
        config.before_dispatch&.call(method, params)
        result = with_timeout(config.timeout) { block.yield(method, params) }
        config.after_dispatch&.call(method, params, result)
        JSONRPC.build_result_response(id: request["id"], result: result)
      rescue Timeout::Error
        timeout_error(request)
      rescue StandardError => e
        config.on_error&.call(e, method, params)
        JSONRPC.build_error_response_from(id: request["id"], descriptor: JSONRPC::ProtocolErrors::INTERNAL_ERROR)
      end

      def timeout_error(request)
        JSONRPC.build_error_response(
          id: request["id"],
          error: {
            code: JSONRPC::ProtocolErrors::SERVER_ERROR.code,
            message: JSONRPC::ProtocolErrors::SERVER_ERROR.message,
            data: "Request timed out"
          }
        )
      end

      def with_timeout(seconds, &block)
        if seconds
          Timeout.timeout(seconds, &block)
        else
          block.call
        end
      end
    end
  end
end
