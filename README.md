# Clamo

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
json_response = Clamo::Server.handle(
  request: '{"jsonrpc": "2.0", "method": "add", "params": [1, 2], "id": 1}',
  object: MyService
)
# => '{"jsonrpc":"2.0","result":3,"id":1}'
```

If you need the parsed hash instead of a JSON string, use the lower-level methods:

```ruby
# From a JSON string
response = Clamo::Server.unparsed_dispatch_to_object(
  request: '{"jsonrpc": "2.0", "method": "add", "params": [1, 2], "id": 1}',
  object: MyService
)
# => {"jsonrpc" => "2.0", "result" => 3, "id" => 1}

# From a pre-parsed hash
response = Clamo::Server.parsed_dispatch_to_object(
  request: { "jsonrpc" => "2.0", "method" => "add", "params" => [1, 2], "id" => 1 },
  object: MyService
)
```

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

batch_response = Clamo::Server.unparsed_dispatch_to_object(
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
response = Clamo::Server.unparsed_dispatch_to_object(
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
| -32602     | Invalid params   | Invalid method parameter(s)                          |
| -32603     | Internal error   | Internal JSON-RPC error                              |
| -32000     | Server error     | Reserved for implementation-defined server errors    |

## Configuration

### Timeout

Every method dispatch is wrapped in a timeout. The default is 30 seconds. Timed-out requests return a `-32000 Server error` response.

```ruby
Clamo::Server.timeout = 10  # seconds
Clamo::Server.timeout = nil # disable timeout
```

### Error Callback

Errors during dispatch are reported through `on_error`. Notifications are silent by default (no response is sent); requests return a generic `-32603 Internal error` without leaking exception details. Use `on_error` to capture the full exception for logging:

```ruby
Clamo::Server.on_error = ->(exception, method, params) {
  Rails.logger.error("#{method} failed: #{exception.message}")
}
```

### Dispatch Hooks

`before_dispatch` and `after_dispatch` run around every method call (requests and notifications). Raise in `before_dispatch` to halt execution:

```ruby
Clamo::Server.before_dispatch = ->(method, params) {
  raise "unauthorized" unless allowed?(method)
}

Clamo::Server.after_dispatch = ->(method, params, result) {
  Rails.logger.info("#{method} completed")
}
```

### Per-Call Configuration

All configuration options can be overridden per-call. Module-level settings serve as defaults:

```ruby
Clamo::Server.handle(
  request: body,
  object: MyService,
  timeout: 5,
  on_error: ->(e, method, params) { MyLogger.error(e) },
  before_dispatch: ->(method, params) { authorize!(method) },
  after_dispatch: ->(method, params, result) { track(method) }
)
```

Per-call config is snapshotted at the start of each dispatch, so concurrent mutations to module-level settings cannot affect in-flight requests.

## Advanced Features

### Parallel Processing

Batch requests are processed in parallel using the [parallel](https://github.com/grosser/parallel) gem. You can pass options to `Parallel.map`:

```ruby
Clamo::Server.parsed_dispatch_to_object(
  request: batch_request,
  object: MyService,
  in_processes: 4  # Parallel processing option
)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rubakas/clamo.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
