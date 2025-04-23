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

      def build_request **opts
        # raise if no method present
        # raise if params present, but not an array
        { jsonrpc: "2.0",
          method: opts[:method] }
          .merge({ params: opts[:params] })
          .merge(opts.key?(:id) ? { id: opts[:id] } : {})
      end

      def build_result_response(id:, result:)
        {}.merge(PROTOCOL_VERSION_PRAGMA)
          .merge({ result: result })
          .merge({ id: id })
      end

      def build_error_response **opts
        # raise if no error code present
        # raise if no error message present
        { jsonrpc: "2.0",
          id: opts[:id],
          error: {
            code: opts.dig(:error, :code),
            message: opts.dig(:error, :message),
            data: opts.dig(:error, :data)
          }.reject { |k, _| k == :data && !opts[:error].key?(:data) } }
      end

      def build_error_response_from **opts
        # raise unless opts[:descriptor]
        opts.merge(
          { error:
            { code: opts[:descriptor].code,
              message: opts[:descriptor].message } }
        )
            .then { |hash| build_error_response(**hash) }
      end

      def build_error_response_parse_error **opts
        opts.merge(
          { error:
            { code: ProtocolErrors::PARSE_ERROR.code,
              message: ProtocolErrors::PARSE_ERROR.message } }
        )
            .then { |hash| build_error_response(**hash) }
      end
    end
  end
end
