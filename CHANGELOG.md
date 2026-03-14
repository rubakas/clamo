# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.9.0] - 2026-03-14

### Changed

- **Breaking:** All response and request builder hashes now use string keys (`"jsonrpc"`, `"result"`, `"id"`, `"error"`) instead of symbol keys. This makes the entire pipeline consistent — `JSON.parse` produces string keys, `normalize_request_keys` uses string keys, and now responses match. Callers using the lower-level `parsed_dispatch_to_object` or `unparsed_dispatch_to_object` must update hash access from `response[:result]` to `response["result"]`. The `handle` method (JSON string in/out) is unaffected.
- `after_dispatch` hook now receives the actual return value for notifications. Previously always passed `nil`; now passes the value returned by the dispatched method.

### Fixed

- **Security:** `method_known?` no longer exposes inherited `Module` methods (`define_method`, `class_eval`, `const_set`, `freeze`, `include`, and 55 others) on module-based service objects. The previous `public_methods(false)` implementation included these; the new `public_method_defined?` check restricts dispatch to methods explicitly defined on the service object.

### Internal

- `method_known?` replaced array-allocating `public_methods(false).map(&:to_sym).include?` with zero-allocation `public_method_defined?` lookups. Handles both module targets (singleton class) and class instance targets (class + singleton class).

## [0.8.0] - 2026-03-14

### Added

- `before_dispatch` and `after_dispatch` hooks — run around every method call (requests and notifications). Raise in `before_dispatch` to halt execution; `after_dispatch` fires only on success with `(method, params, result)`.
- Per-call configuration — `timeout`, `on_error`, `before_dispatch`, and `after_dispatch` can be passed as keyword arguments to `handle`, `unparsed_dispatch_to_object`, and `parsed_dispatch_to_object`, overriding module-level defaults.
- `Clamo::Server::Config` — immutable `Data` struct that snapshots configuration at the start of each dispatch, eliminating race conditions from concurrent mutations to module-level settings.

### Changed

- Internal error responses no longer include `e.message` in the `data` field, preventing leakage of internal details to clients. Exceptions are routed through `on_error` instead.
- `parsed_dispatch_to_object` normalizes request keys to strings at the boundary, fixing silent dispatch failures when callers pass symbol-key hashes.
- `on_error` is now called for request dispatch errors (previously only for notification errors).
- Test suite expanded to 95 tests / 138 assertions.

## [0.7.0] - 2026-03-14

### Added

- `Clamo::Server.timeout` — per-dispatch timeout with 30-second default; returns `-32000 Server error` on timeout for requests, calls `on_error` for notifications. Set to `nil` to disable.
- MIT LICENSE file and `spec.license` in gemspec
- Indifferent key access in JSONRPC validators (symbol and string keys both accepted)
- Tests for string ids, arity mismatch, single-item batches, and handle+timeout (77 tests / 105 assertions)

### Changed

- `proper_pragma?`, `proper_method?`, `proper_id_if_any?` moved from public to private API on `Clamo::JSONRPC`
- Notifications with invalid params type now return `nil` instead of an error response (spec compliance)
- `parsed_dispatch_to_object` now validates `object:` argument (raises `ArgumentError` if nil)
- Single-item batches skip `Parallel.map` overhead
- Gemspec description expanded (no longer identical to summary)
- README updated with `Server.handle`, `timeout`, and `on_error` documentation

### Removed

- `Clamo::Error` base exception class (unused)
- `sig/clamo.rbs` type signatures (misleadingly incomplete)
- Dead `else` branch in `dispatch_to_ruby`

## [0.6.0] - 2026-03-14

### Added

- `Clamo::Server.handle` — JSON string in, JSON string out entry point for HTTP/socket integrations
- `Clamo::Server.on_error` callback for notification failure reporting
- `Clamo::Error` base exception class

### Changed

- Notifications now dispatch synchronously instead of spawning a background thread per call; callers control their own concurrency
- `build_error_response_from` accepts explicit `descriptor:` and `id:` keyword arguments instead of `**opts`
- `build_error_response_parse_error` takes no arguments (always returns `id: nil`)
- `parallel` dependency relaxed from `~> 1.27.0` to `~> 1.27`
- Minimum Ruby version raised from 3.0 to 3.3

### Removed

- `JSONRPC.valid_params?` (use `JSONRPC.proper_params_if_any?` directly)
- `JSONRPC::PROTOCOL_VERSION_PRAGMA` constant (unused)
- `JSONRPC::ProtocolErrors::SERVER_ERROR_CODE_RANGE` constant (unused)

### Fixed

- **Security:** replaced `send` with `public_send` to prevent remote invocation of private methods
- **Security:** `method_known?` now uses `public_methods(false)` to expose only explicitly defined methods
- Notifications now validate method existence before dispatch (previously skipped validation)
- Empty batch requests correctly return Invalid Request error per spec
- All-notification batches return `nil` instead of empty array per spec
- `build_error_response_from` no longer leaks the `:descriptor` key into the error response builder

### Internal

- `method_known?`, `dispatch_to_ruby`, `response_for` moved from public to private API
- `response_for_single_request` extracted into focused private helpers
- Test suite expanded from scaffold to 62 tests / 84 assertions covering validation, dispatch, security, error handling, batching, notifications, and argument edge cases
- CI matrix set to Ruby 3.3, 3.4, 4.0

## [0.5.0] - 2025-02-07

### Changed

- Updated README with detailed usage examples, error table, and batch/notification documentation

## [0.4.0] - 2025-02-07

### Fixed

- Corrected gem metadata URLs

## [0.3.0] - 2025-02-06

### Added

- Batch request support via `parallel` gem
- Named parameter (Hash) dispatch
- JSON-RPC 2.0 validation (pragma, method, id, params)
- Protocol error constants (`PARSE_ERROR`, `INVALID_REQUEST`, etc.)
- RuboCop configuration

### Changed

- Multiple version bumps during initial development

## [0.1.0] - 2025-02-06

### Added

- Initial release
- Basic JSON-RPC 2.0 server with positional parameter dispatch
- `Clamo::JSONRPC` request/response builders
