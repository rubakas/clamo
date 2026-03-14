# Clamo

[![CI](https://github.com/rubakas/clamo/actions/workflows/main.yml/badge.svg)](https://github.com/rubakas/clamo/actions/workflows/main.yml)
[![Gem Version](https://badge.fury.io/rb/clamo.svg)](https://badge.fury.io/rb/clamo)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.3-ruby.svg)](https://www.ruby-lang.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![JSON-RPC 2.0](https://img.shields.io/badge/JSON--RPC-2.0-orange.svg)](https://www.jsonrpc.org/specification)

A Ruby implementation of [JSON-RPC 2.0](https://www.jsonrpc.org/specification) designed for simplicity and compliance with the specification.


## Usage

### Basic Usage

```ruby
require 'clamo'

# Define a service object with methods you want to expose
module MyService
  def self.add(a, b)
    a + b
  end

  def self.subtract(a:, b:)
    a - b
  end

  # Private methods won't be accessible via JSON-RPC
  private_class_method def self.internal_method
    # This won't be exposed
  end
end

# JSON string in, JSON string out — the primary entry point for HTTP/socket integrations.
# Returns nil for notifications (no response expected).
json_response = Clamo::Server.handle_json(
  request: '{"jsonrpc": "2.0", "method": "add", "params": [1, 2], "id": 1}',
  object: MyService
)
# => '{"jsonrpc":"2.0","result":3,"id":1}'
```

If you need the parsed hash instead of a JSON string, use the lower-level methods directly or via their shorter aliases:

```ruby
# From a JSON string
response = Clamo::Server.dispatch_json(
  request: '{"jsonrpc": "2.0", "method": "add", "params": [1, 2], "id": 1}',
  object: MyService
)
# => {"jsonrpc" => "2.0", "result" => 3, "id" => 1}

# From a pre-parsed hash
response = Clamo::Server.dispatch(
  request: { "jsonrpc" => "2.0", "method" => "add", "params" => [1, 2], "id" => 1 },
  object: MyService
)
```

The longer names `parsed_dispatch_to_object`, `unparsed_dispatch_to_object`, and `handle` still work as deprecated aliases.

### Handling Different Parameter Types

Clamo supports both positional (array) and named (object/hash) parameters:

```ruby
# Positional parameters
request = '{"jsonrpc": "2.0", "method": "add", "params": [1, 2], "id": 1}'

# Named parameters
request = '{"jsonrpc": "2.0", "method": "subtract", "params": {"a": 5, "b": 3}, "id": 2}'
```

### Batch Requests

Clamo handles batch requests automatically:

```ruby
batch_request = <<~JSON
[
  {"jsonrpc": "2.0", "method": "add", "params": [1, 2], "id": 1},
  {"jsonrpc": "2.0", "method": "subtract", "params": {"a": 5, "b": 3}, "id": 2}
]
JSON

batch_response = Clamo::Server.dispatch_json(
  request: batch_request,
  object: MyService
)

puts batch_response
# => [{"jsonrpc" => "2.0", "result" => 3, "id" => 1}, {"jsonrpc" => "2.0", "result" => 2, "id" => 2}]
```

### Notifications

Notifications are requests without an ID field. They don't produce a response:

```ruby
notification = '{"jsonrpc": "2.0", "method": "add", "params": [1, 2]}'
response = Clamo::Server.dispatch_json(
  request: notification,
  object: MyService
)

puts response
# => nil
```

### Building JSON-RPC Requests

Clamo provides utilities for building JSON-RPC requests:

```ruby
request = Clamo::JSONRPC.build_request(
  method: "add",
  params: [1, 2],
  id: 1
)

puts request
# => {"jsonrpc" => "2.0", "method" => "add", "params" => [1, 2], "id" => 1}
```

## Error Handling

Clamo follows the JSON-RPC 2.0 specification for error handling:

| Error Code | Message          | Description                                          |
|------------|------------------|------------------------------------------------------|
| -32700     | Parse error      | Invalid JSON was received                            |
| -32600     | Invalid request  | The JSON sent is not a valid Request object          |
| -32601     | Method not found | The method does not exist / is not available         |
| -32602     | Invalid params   | Invalid method parameter(s) or arity mismatch        |
| -32603     | Internal error   | Internal JSON-RPC error                              |
| -32000     | Server error     | Exception raised by dispatched method                |

Parameter arity is validated before dispatch. If the number of positional arguments or keyword arguments doesn't match the Ruby method signature, a `-32602 Invalid params` error is returned.

## Configuration

### Error Callback

Errors during dispatch are reported through `on_error`, which is called for both requests and notifications. Notifications are silent by default (no response is sent to the client, but `on_error` still fires); requests return a generic `-32000 Server error` without leaking exception details. Use `on_error` to capture the full exception for logging:

```ruby
Clamo::Server.on_error = ->(exception, method, params) {
  Rails.logger.error("#{method} failed: #{exception.message}")
}
```

### Per-Call Configuration

Configuration can be overridden per-call. Module-level settings serve as defaults:

```ruby
Clamo::Server.handle_json(
  request: body,
  object: MyService,
  on_error: ->(e, method, params) { MyLogger.error(e) }
)
```

Per-call config is snapshotted at the start of each dispatch, so concurrent mutations to module-level settings cannot affect in-flight requests.

## Advanced Features

### Parallel Processing

Batch requests are processed in parallel when the [parallel](https://github.com/grosser/parallel) gem is available. If `parallel` is not installed, batches fall back to sequential processing. You can pass options to `Parallel.map`:

```ruby
Clamo::Server.dispatch(
  request: batch_request,
  object: MyService,
  in_processes: 4  # Parallel processing option
)
```

## Roadmap

- [ ] Method metadata caching
- [ ] Method allowlists/denylists
- [ ] Observability and logging
- [ ] Profiling
- [ ] Hooks
- [ ] Rack helpers and framework helpers (Rails)
- [ ] Autodoc (Markdown?)
- [ ] Error data builder
- [ ] Schemas

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rubakas/clamo.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
