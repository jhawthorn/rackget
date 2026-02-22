# frozen_string_literal: true

require_relative "rackget/version"

require "rack"
require "rack/builder"
require "rack/mock_request"
require "uri"

module Rackget
  class Error < StandardError; end

  def self.load_app(rackup_file)
    raise Error, "File not found: #{rackup_file}" unless File.exist?(rackup_file)

    result = Rack::Builder.parse_file(rackup_file)
    result.is_a?(Array) ? result.first : result
  end

  def self.request(app, path, method: "GET", query_string: nil, input: nil)
    url = path.dup
    url = "#{url}?#{query_string}" if query_string && !query_string.empty?

    opts = { method: method }
    opts[:input] = input if input

    env = Rack::MockRequest.env_for(url, opts)
    app.call(env)
  end

  def self.get(app, path, query_string: nil)
    request(app, path, method: "GET", query_string: query_string)
  end
end
