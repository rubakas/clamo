# frozen_string_literal: true

module Clamo
  module JSONRPC
    module ProtocolErrors
      ErrorDescriptor = Data.define(:code, :message)

      PARSE_ERROR       = ErrorDescriptor.new(code: -32_700, message: "Parse error")
      INVALID_REQUEST   = ErrorDescriptor.new(code: -32_600, message: "Invalid request")
      METHOD_NOT_FOUND  = ErrorDescriptor.new(code: -32_601, message: "Method not found")
      INVALID_PARAMS    = ErrorDescriptor.new(code: -32_602, message: "Invalid params")
      INTERNAL_ERROR    = ErrorDescriptor.new(code: -32_603, message: "Internal error")
      SERVER_ERROR      = ErrorDescriptor.new(code: -32_000, message: "Server error")
    end

    class << self
      def proper_pragma?(request)
        fetch_indifferent(request, "jsonrpc") == "2.0"
      end

      def proper_method?(request)
        fetch_indifferent(request, "method").is_a?(String)
      end

      def proper_id_if_any?(request)
        if key_indifferent?(request, "id")
          id = fetch_indifferent(request, "id")
          id.is_a?(String) || id.is_a?(Integer) || id.is_a?(NilClass)
        else
          true
        end
      end

      def proper_params_if_any?(request)
        if key_indifferent?(request, "params")
          params = fetch_indifferent(request, "params")
          params.is_a?(Array) || params.is_a?(Hash)
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

      def build_request(**opts)
        raise ArgumentError, "method is required" unless opts.key?(:method)

        validate_params_type!(opts[:params]) if opts.key?(:params)

        { jsonrpc: "2.0", method: opts[:method] }
          .then { |r| opts.key?(:params) ? r.merge(params: opts[:params]) : r }
          .then { |r| opts.key?(:id) ? r.merge(id: opts[:id]) : r }
      end

      def build_result_response(id:, result:)
        { jsonrpc: "2.0", result: result, id: id }
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

      def build_error_response_from(descriptor:, id: nil)
        build_error_response(
          id: id,
          error: {
            code: descriptor.code,
            message: descriptor.message
          }
        )
      end

      def build_error_response_parse_error
        build_error_response(
          id: nil,
          error: {
            code: ProtocolErrors::PARSE_ERROR.code,
            message: ProtocolErrors::PARSE_ERROR.message
          }
        )
      end

      private

      def validate_params_type!(params)
        return if params.is_a?(Array) || params.is_a?(Hash)

        raise ArgumentError, "params must be an Array or Hash"
      end

      def fetch_indifferent(hash, key)
        hash.fetch(key.to_s) { hash.fetch(key.to_sym, nil) }
      end

      def key_indifferent?(hash, key)
        hash.key?(key.to_s) || hash.key?(key.to_sym)
      end
    end
  end
end
