# frozen_string_literal: true

require "test_helper"

class TestServerConcurrency < Minitest::Test
  include JSONRPCTestHelpers

  def test_concurrent_dispatch_from_multiple_threads
    threads = 10.times.map do |i|
      Thread.new do
        dispatch(jsonrpc_request(method: "method_two_params_add", params: [i, 1], id: i + 1))
      end
    end

    results = threads.map(&:value)
    results.each_with_index do |response, i|
      assert_equal i + 1, response["result"]
    end
  end

  def test_concurrent_notifications_do_not_interfere
    threads = 10.times.map do
      Thread.new do
        dispatch(jsonrpc_request(method: "method_no_params_number"))
      end
    end

    results = threads.map(&:value)
    results.each { |r| assert_nil r }
  end
end
