# frozen_string_literal: true

require "json"

module Clamo
  module Server
    class << self
      # Clamo::Server.unparsed_dispatch_to_object(
      #   request:  request_body,
      #   object:   MyModule
      # )
      def unparsed_dispatch_to_object(request:, object:, **opts)
        # TODO: raise unless object is present?
        begin
          parsed = JSON.parse(request)
        rescue JSON::JSONError # TODO: any error
          return JSONRPC.build_error_response_parse_error
        end

        parsed_dispatch_to_object(request: parsed, object: object, **opts)
      end

      def parsed_dispatch_to_object(request:, object:, **opts)
        response_for(request: request, object: object, **opts) do |method, params|
          dispatch_to_ruby(
            object: object,
            method: method,
            params: params # consider splating
          )
        end
      end

      def method_known?(object:, method:)
        (object.public_methods - Object.methods)
          .map(&:to_sym)
          .include?(method.to_sym)
      end

      def dispatch_to_ruby(object:, method:, params:)
        case params
        when Array
          object.send method.to_sym, *params
        when Hash
          object.send method.to_sym, **(params.transform_keys(&:to_sym))
        when NilClass
          object.send method.to_sym
        else
          # TODO: raise
          raise "WTF"
        end
      end

      def response_for(request:, object:, **opts, &block)
        case request
        when Array # batch request
          Parallel.map(request, **opts) do |item|
            response_for_single_request(
              request: item,
              object: object,
              block: block
            )
          end.compact
        when Hash # single request
          response_for_single_request(
            request: request,
            object: object,
            block: block
          )
        else
          JSONRPC.build_error_response_from(
            id: nil,
            descriptor: JSONRPC::ProtocolErrors::INVALID_REQUEST
          )
        end
      end

      def yield_to_execution(block:, method:, params:)
        block.yield method, params
      end

      def response_for_single_request(request:, object:, block:)
        unless JSONRPC.valid_request?(request)
          return JSONRPC.build_error_response_from(
            id: request["id"],
            descriptor: JSONRPC::ProtocolErrors::INVALID_REQUEST
          )
        end

        unless JSONRPC.valid_params?(request)
          return JSONRPC.build_error_response_from(
            id: request["id"],
            descriptor: JSONRPC::ProtocolErrors::INVALID_PARAMS
          )
        end

        unless request.key?("id") # notification - no result needed
          # TODO: block.call off the current thread
          Thread.new do
            yield_to_execution(
              block: block,
              method: request["method"],
              params: request["params"]
            )
          rescue StandardError
            # TODO: add exception handler
            nil
          end

          return nil
        end

        unless method_known?(object: object, method: request["method"])
          return JSONRPC.build_error_response_from(
            id: request["id"],
            descriptor: JSONRPC::ProtocolErrors::METHOD_NOT_FOUND
          )
        end

        JSONRPC.build_result_response(
          id: request["id"],
          result: yield_to_execution(
            block: block,
            method: request["method"],
            params: request["params"]
          )
        )
      end
    end
  end
end
