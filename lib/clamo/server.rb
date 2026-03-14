# frozen_string_literal: true

require "json"

module Clamo
  # JSON-RPC 2.0 request dispatcher. All public methods on the target +object+
  # become callable JSON-RPC methods.
  #
  # Three entry points, from highest to lowest level:
  # - handle_json — JSON string in, JSON string out
  # - dispatch_json — JSON string in, parsed Hash out
  # - dispatch — parsed Hash in, parsed Hash out
  #
  # == Example
  #
  #   Clamo::Server.handle_json(
  #     request: '{"jsonrpc":"2.0","method":"add","params":[1,2],"id":1}',
  #     object:  MyService
  #   )
  #   # => '{"jsonrpc":"2.0","result":3,"id":1}'
  module Server
    Config = Data.define(:on_error)

    class << self
      # Global error callback. Called with +(exception, method, params)+ whenever
      # a dispatched method raises. Fires for both requests and notifications.
      attr_accessor :on_error

      # JSON string in, JSON string out. The primary entry point for HTTP/socket
      # integrations. Returns +nil+ for notifications (no response expected).
      #
      #   Clamo::Server.handle_json(request: body, object: MyService)
      #
      # All extra keyword arguments are forwarded to #dispatch.
      def handle_json(request:, object:, **)
        response = dispatch_json(request: request, object: object, **)
        response&.to_json
      end

      alias handle handle_json

      # JSON string in, parsed response Hash out. Parses the JSON and delegates
      # to #dispatch. Returns a Hash (or Array of Hashes for batches), or +nil+
      # for notifications.
      #
      #   Clamo::Server.dispatch_json(request: json_string, object: MyService)
      #
      # All extra keyword arguments are forwarded to #dispatch.
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

      # Parsed Hash (or Array) in, parsed response Hash out. Validates the
      # request, resolves the method on +object+, checks parameter arity,
      # and dispatches. Returns +nil+ for notifications.
      #
      #   Clamo::Server.dispatch(request: hash_or_array, object: MyService)
      #
      # ==== Options
      # +on_error+:: Error callback for this call, overrides the global on_error.
      # Extra keyword arguments are forwarded to +Parallel.map+ for batch requests.
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

        error = validate_params_type(request)
        return error if error

        unless method_known?(object: object, method: request["method"])
          return error_for(request, JSONRPC::ProtocolErrors::METHOD_NOT_FOUND)
        end

        unless params_match_arity?(object: object, method: request["method"], params: request["params"])
          return error_for(request, JSONRPC::ProtocolErrors::INVALID_PARAMS)
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

      def error_for(request, descriptor)
        return unless request.key?("id")

        JSONRPC.build_error_response_from(id: request["id"], descriptor: descriptor)
      end

      def validate_request_structure(request)
        return if JSONRPC.valid_request?(request)

        JSONRPC.build_error_response_from(
          id: request.is_a?(Hash) ? request["id"] : nil,
          descriptor: JSONRPC::ProtocolErrors::INVALID_REQUEST
        )
      end

      def validate_params_type(request)
        return if JSONRPC.proper_params_if_any?(request)

        error_for(request, JSONRPC::ProtocolErrors::INVALID_PARAMS)
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
