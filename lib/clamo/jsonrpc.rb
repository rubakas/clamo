# frozen_string_literal: true

module Clamo
  module JSONRPC
    PROTOCOL_VERSION_PRAGMA = { jsonrpc: "2.0" }.freeze

    module ProtocolErrors
      ErrorDescriptor = Data.define(:code, :message)
      SERVER_ERROR_CODE_RANGE = ((-32_099)..(-32_000))

      PARSE_ERROR       = ErrorDescriptor.new(code: -32_700, message: "Parse error")
      INVALID_REQUEST   = ErrorDescriptor.new(code: -32_600, message: "Invalid request")
      METHOD_NOT_FOUND  = ErrorDescriptor.new(code: -32_601, message: "Method not found")
      INVALID_PARAMS    = ErrorDescriptor.new(code: -32_602, message: "Invalid params")
      INTERNAL_ERROR    = ErrorDescriptor.new(code: -32_603, message: "Internal error")
      SERVER_ERROR      = ErrorDescriptor.new(code: -32_000, message: "Server error")
    end

    class << self
      def proper_pragma?(request)
        request["jsonrpc"] == "2.0"
      end

      def proper_method?(request)
        request["method"].is_a?(String)
      end

      def proper_id_if_any?(request)
        if request.key?("id")
          request["id"].is_a?(String) ||
            request["id"].is_a?(Integer) ||
            request["id"].is_a?(NilClass)
        else
          true
        end
      end

      def proper_params_if_any?(request)
        if request.key?("params")
          request["params"].is_a?(Array) || request["params"].is_a?(Hash)
        else
          true
        end
      end

      def valid_request?(request)
        request.is_a?(Hash) &&
          proper_pragma?(request) &&
          proper_method?(request) &&
          proper_id_if_any?(request)
      end

      def valid_params?(request)
        proper_params_if_any?(request)
      end

      def build_request(**opts)
        raise ArgumentError, "method is required" unless opts.key?(:method)

        validate_params_type!(opts[:params]) if opts.key?(:params)

        { jsonrpc: "2.0", method: opts[:method] }
          .then { |r| opts.key?(:params) ? r.merge(params: opts[:params]) : r }
          .then { |r| opts.key?(:id) ? r.merge(id: opts[:id]) : r }
      end

      def build_result_response(id:, result:)
        {}.merge(PROTOCOL_VERSION_PRAGMA)
          .merge({ result: result })
          .merge({ id: id })
      end

      def build_error_response(**opts)
        raise ArgumentError, "error code is required" unless opts.dig(:error, :code)
        raise ArgumentError, "error message is required" unless opts.dig(:error, :message)

        { jsonrpc: "2.0",
          id: opts[:id],
          error: {
            code: opts.dig(:error, :code),
            message: opts.dig(:error, :message),
            data: opts.dig(:error, :data)
          }.reject { |k, _| k == :data && !opts[:error].key?(:data) } }
      end

      def build_error_response_from(**opts)
        raise ArgumentError, "descriptor is required" unless opts[:descriptor]

        opts.merge(
          { error:
            { code: opts[:descriptor].code,
              message: opts[:descriptor].message } }
        )
            .then { |hash| build_error_response(**hash) }
      end

      def build_error_response_parse_error(**opts)
        opts.merge(
          { error:
            { code: ProtocolErrors::PARSE_ERROR.code,
              message: ProtocolErrors::PARSE_ERROR.message } }
        )
            .then { |hash| build_error_response(**hash) }
      end

      private

      def validate_params_type!(params)
        return if params.is_a?(Array) || params.is_a?(Hash)

        raise ArgumentError, "params must be an Array or Hash"
      end
    end
  end
end
