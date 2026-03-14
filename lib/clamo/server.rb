# frozen_string_literal: true

require "json"

module Clamo
  module Server
    Config = Data.define(:on_error)

    class << self
      attr_accessor :on_error

      # JSON string in, JSON string out. Full round-trip for HTTP/socket integrations.
      #
      #   Clamo::Server.handle_json(request: body, object: MyService)
      #
      def handle_json(request:, object:, **)
        response = dispatch_json(request: request, object: object, **)
        response&.to_json
      end

      alias handle handle_json

      # JSON string in, parsed response out.
      #
      #   Clamo::Server.dispatch_json(request: json_string, object: MyModule)
      #
      def dispatch_json(request:, object:, **)
        raise ArgumentError, "object is required" unless object

        begin
          parsed = JSON.parse(request)
        rescue JSON::JSONError
          return JSONRPC.build_error_response_parse_error
        end

        dispatch(request: parsed, object: object, **)
      end

      alias unparsed_dispatch_to_object dispatch_json

      # Parsed hash in, parsed response out.
      #
      #   Clamo::Server.dispatch(request: hash_or_array, object: MyModule)
      #
      def dispatch(request:, object:,
                   on_error: self.on_error,
                   **opts)
        raise ArgumentError, "object is required" unless object

        request = normalize_request_keys(request)
        config = Config.new(on_error: on_error)

        response_for(request: request, object: object, config: config, **opts) do |method, params|
          dispatch_to_ruby(object: object, method: method, params: params)
        end
      end

      alias parsed_dispatch_to_object dispatch

      private

      def normalize_request_keys(request)
        case request
        when Hash  then request.transform_keys(&:to_s)
        when Array then request.map { |r| r.is_a?(Hash) ? r.transform_keys(&:to_s) : r }
        else request
        end
      end

      def method_known?(object:, method:)
        name = method.to_sym
        if object.is_a?(Module)
          object.singleton_class.public_method_defined?(name, false)
        else
          object.class.public_method_defined?(name, false) ||
            object.singleton_class.public_method_defined?(name, false)
        end
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

        unless params_match_arity?(object: object, method: request["method"], params: request["params"])
          return request.key?("id") ? arity_mismatch_error(request) : nil
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

        result = map_batch(request, **opts) do |item|
          response_for_single_request(request: item, object: object, block: block, config: config)
        end.compact
        result.empty? ? nil : result
      end

      def map_batch(items, **, &)
        require "parallel"
        Parallel.map(items, **, &)
      rescue LoadError
        items.map(&)
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

      def arity_mismatch_error(request)
        JSONRPC.build_error_response_from(id: request["id"], descriptor: JSONRPC::ProtocolErrors::INVALID_PARAMS)
      end

      def dispatch_notification(request, block, config)
        method = request["method"]
        params = request["params"]
        block.yield(method, params)
        nil
      rescue StandardError => e
        config.on_error&.call(e, method, params)
        nil
      end

      def dispatch_request(request, block, config)
        method = request["method"]
        params = request["params"]
        result = block.yield(method, params)
        JSONRPC.build_result_response(id: request["id"], result: result)
      rescue StandardError => e
        config.on_error&.call(e, method, params)
        JSONRPC.build_error_response_from(id: request["id"], descriptor: JSONRPC::ProtocolErrors::SERVER_ERROR)
      end

      def params_match_arity?(object:, method:, params:)
        ruby_method = resolve_method(object, method)
        return true unless ruby_method

        parameters = ruby_method.parameters

        case params
        when Array then array_params_match?(parameters, params.size)
        when Hash  then hash_params_match?(parameters, params.keys.map(&:to_sym))
        when nil   then nil_params_match?(parameters)
        else true
        end
      end

      def resolve_method(object, method_name)
        object.method(method_name.to_sym)
      rescue NameError
        nil
      end

      def array_params_match?(parameters, count)
        by_type = parameters.group_by(&:first)

        return false if by_type.key?(:keyreq)
        return true if by_type.key?(:rest)

        required = by_type.fetch(:req, []).size
        count.between?(required, required + by_type.fetch(:opt, []).size)
      end

      def hash_params_match?(parameters, keys)
        by_type = parameters.group_by(&:first)
        required = by_type.fetch(:keyreq, []).map(&:last)
        allowed = required + by_type.fetch(:key, []).map(&:last)

        return false if by_type.key?(:req)
        return false unless (required - keys).empty?

        by_type.key?(:keyrest) || (keys - allowed).empty?
      end

      def nil_params_match?(parameters)
        by_type = parameters.group_by(&:first)

        by_type.fetch(:req, []).empty? && !by_type.key?(:keyreq)
      end
    end
  end
end
