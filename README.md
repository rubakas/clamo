# Clamo

JSON-RPC protocol toolkit for Ruby.

Consume, Serve or test JSON-RPC endpoints with Clamo.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add clamo

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install clamo


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machi# Clamo

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

# Handle a JSON-RPC request
request_body = '{"jsonrpc": "2.0", "method": "add", "params": [1, 2], "id": 1}'
response = Clamo::Server.unparsed_dispatch_to_object(
  request: request_body,
  object: MyService
)

puts response
# => {"jsonrpc":"2.0","result":3,"id":1}
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
# => [{"jsonrpc":"2.0","result":3,"id":1},{"jsonrpc":"2.0","result":2,"id":2}]
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
# => {:jsonrpc=>"2.0", :method=>"add", :params=>[1, 2], :id=>1}
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

## Advanced Features

### Parallel Processing

Batch requests are processed in parallel using the [parallel](https://github.com/grosser/parallel) gem. You can pass options to `Parallel.map` via the `parsed_dispatch_to_object` method:

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

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).ne, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rubakas/clamo
