# frozen_string_literal: true

require "json"
require "parallel"

module Clamo
  module Server
    class << self
      # Global error callback for notification failures.
      # This is module-level state shared across all callers.
      # Set to any callable (lambda, method, proc) that accepts (exception, method, params).
      #
      #   Clamo::Server.on_error = ->(e, method, params) { Rails.logger.error(e) }
      #
      attr_accessor :on_error

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

      def parsed_dispatch_to_object(request:, object:, **opts)
        raise ArgumentError, "object is required" unless object

        response_for(request: request, object: object, **opts) do |method, params|
          dispatch_to_ruby(object: object, method: method, params: params)
        end
      end

      private

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
      def response_for(request:, object:, **, &block)
        case request
        when Array
          response_for_batch(request: request, object: object, block: block, **)
        when Hash
          response_for_single_request(request: request, object: object, block: block)
        else
          JSONRPC.build_error_response_from(id: nil, descriptor: JSONRPC::ProtocolErrors::INVALID_REQUEST)
        end
      end

      def response_for_single_request(request:, object:, block:)
        error = validate_request_structure(request)
        return error if error

        unless method_known?(object: object, method: request["method"])
          return request.key?("id") ? method_not_found_error(request) : nil
        end

        return dispatch_notification(request, block) unless request.key?("id")

        dispatch_request(request, block)
      end

      def response_for_batch(request:, object:, block:, **opts)
        if request.empty?
          return JSONRPC.build_error_response_from(id: nil, descriptor: JSONRPC::ProtocolErrors::INVALID_REQUEST)
        end

        if request.size == 1
          result = response_for_single_request(request: request.first, object: object, block: block)
          return result ? [result] : nil
        end

        result = Parallel.map(request, **opts) do |item|
          response_for_single_request(request: item, object: object, block: block)
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

      def dispatch_notification(request, block)
        block.yield request["method"], request["params"]
        nil
      rescue StandardError => e
        on_error&.call(e, request["method"], request["params"])
        nil
      end

      def dispatch_request(request, block)
        JSONRPC.build_result_response(
          id: request["id"],
          result: block.yield(request["method"], request["params"])
        )
      rescue StandardError => e
        JSONRPC.build_error_response(
          id: request["id"],
          error: {
            code: JSONRPC::ProtocolErrors::INTERNAL_ERROR.code,
            message: JSONRPC::ProtocolErrors::INTERNAL_ERROR.message,
            data: e.message
          }
        )
      end
    end
  end
end
