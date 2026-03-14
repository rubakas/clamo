# frozen_string_literal: true

require_relative "clamo/version"
require_relative "clamo/jsonrpc"
require_relative "clamo/server"

# Clamo is a minimal, spec-compliant JSON-RPC 2.0 server for Ruby.
# Expose any module or class as a JSON-RPC service — public methods
# become callable via JSON-RPC requests.
#
# See Clamo::Server for the main entry points.
module Clamo
end
