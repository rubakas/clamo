# frozen_string_literal: true

require "json"

module GPTJsonRpcServer
  PROTOCOL_VERSION = "2.0"

  def self.handle_request(object:, request_json:)
    requests = JSON.parse(request_json)
    if requests.is_a?(Array)
      responses = requests.map do |request|
        Thread.new { process_request(object, request) }
      end.map(&:value).compact
      responses.empty? ? nil : responses.to_json
    else
      response = process_request(object, requests)
      response&.to_json
    end
  rescue JSON::ParserError
    { jsonrpc: PROTOCOL_VERSION, error: { code: -32_700, message: "Parse error" }, id: nil }.to_json
  end

  def self.process_request(object, request)
    method = request["method"]
    params = request["params"]
    id = request["id"]

    unless valid_id?(id)
      return { jsonrpc: PROTOCOL_VERSION, error: { code: -32_600, message: "Invalid Request" }, id: nil }
    end

    unless method.is_a?(String) && object.public_methods(false).include?(method.to_sym)
      return { jsonrpc: PROTOCOL_VERSION, error: { code: -32_601, message: "Method not found" }, id: id }
    end

    method_object = object.method(method)
    param_list = method_object.parameters
    valid_params = case params
                   when Array
                     param_list.none? { |type, _| type == :rest } && params.size == param_list.count do |type, _|
                       %i[req opt rest].include?(type)
                     end
                   when Hash
                     required_params = param_list.slice(:keyreq).map(&:last)
                     required_params.all? { |key| params.key?(key) } && param_list.all? do |type, name|
                       type != :keyreq || params.key?(name)
                     end
                   when NilClass
                     param_list.empty?
                   else
                     false
                   end

    unless valid_params
      return { jsonrpc: PROTOCOL_VERSION, error: { code: -32_602, message: "Invalid params" },
               id: id }
    end

    if id.nil?
      # Treat id: null as a notification
      Thread.new { safe_call_method(method_object, params) }
      return nil
    end

    begin
      result = safe_call_method(method_object, params)
      { jsonrpc: PROTOCOL_VERSION, result: result, id: id }
    rescue StandardError => e
      { jsonrpc: PROTOCOL_VERSION, error: { code: -32_603, message: "Internal error", data: e.message }, id: id }
    end
  end

  def self.safe_call_method(method_object, params)
    if params.is_a?(Array)
      method_object.call(*params)
    elsif params.is_a?(Hash)
      method_object.call(**params)
    else
      method_object.call
    end
  end

  def self.valid_id?(id)
    return false unless id.is_a?(String) || id.is_a?(Numeric) || id.nil?
    return false if id.is_a?(Numeric) && id != id.to_i

    true
  end
end

# Example usage

class MyService
  def add(a, b)
    a + b
  end

  def subtract(a:, b:)
    a - b
  end

  private

  def private_method
    "This should not be exposed"
  end
end

service = MyService.new

# Example JSON-RPC requests
single_request_positional = {
  jsonrpc: "2.0",
  method: "add",
  params: [1, 2],
  id: 1
}.to_json

single_request_keyword = {
  jsonrpc: "2.0",
  method: "subtract",
  params: { a: 5, b: 3 },
  id: 2
}.to_json

batch_request = [
  { jsonrpc: "2.0", method: "add", params: [1, 2], id: 1 },
  { jsonrpc: "2.0", method: "subtract", params: { a: 5, b: 3 }, id: 2 },
  { jsonrpc: "2.0", method: "add", params: [7, 3], id: 3 }
].to_json

notification_request = {
  jsonrpc: "2.0",
  method: "add",
  params: [1, 2]
}.to_json

invalid_id_null_request = {
  jsonrpc: "2.0",
  method: "add",
  params: [1, 2],
  id: nil
}.to_json

invalid_id_object_request = {
  jsonrpc: "2.0",
  method: "add",
  params: [1, 2],
  id: {}
}.to_json

invalid_method_request = {
  jsonrpc: "2.0",
  method: {},
  params: [1, 2],
  id: 1
}.to_json

# Handling single request with positional parameters
response_json_positional = GPTJsonRpcServer.handle_request(object: service, request_json: single_request_positional)
puts response_json_positional # Output: {"jsonrpc":"2.0","result":3,"id":1}

# Handling single request with keyword parameters
response_json_keyword = GPTJsonRpcServer.handle_request(object: service, request_json: single_request_keyword)
puts response_json_keyword # Output: {"jsonrpc":"2.0","result":2,"id":2}

# Handling batch request
batch_response_json = GPTJsonRpcServer.handle_request(object: service, request_json: batch_request)
puts batch_response_json # Output: [{"jsonrpc":"2.0","result":3,"id":1},{"jsonrpc":"2.0","result":2,"id":2},{"jsonrpc":"2.0","result":10,"id":3}]

# Handling notification request (no response expected)
notification_response_json = GPTJsonRpcServer.handle_request(object: service, request_json: notification_request)
puts notification_response_json.nil? # Output: true

# Handling request with id = null (treated as a notification)
invalid_id_null_response_json = GPTJsonRpcServer.handle_request(object: service, request_json: invalid_id_null_request)
puts invalid_id_null_response_json.nil? # Output: true

# Handling request with id as an object (should return an error)
invalid_id_object_response_json = GPTJsonRpcServer.handle_request(object: service,
                                                                  request_json: invalid_id_object_request)
puts invalid_id_object_response_json # Output: {"jsonrpc":"2.0","error":{"code":-32600,"message":"Invalid Request"},"id":null}

# Handling request with method as an object (should return an error)
invalid_method_response_json = GPTJsonRpcServer.handle_request(object: service, request_json: invalid_method_request)
puts invalid_method_response_json # Output: {"jsonrpc":"2.0","error":{"code":-32600,"message":"Invalid Request"},"id":1}
