# frozen_string_literal: true

require "optparse"
require_relative "../rackget"

module Rackget
  class CLI
    def initialize(argv)
      @options = {
        rackup_file: "config.ru",
        include_headers: false,
        method: "GET",
        data: nil
      }

      @parser = OptionParser.new do |opts|
        opts.banner = "Usage: rackget [options] PATH"

        opts.on("-r", "--rackup FILE", "Rackup file (default: config.ru)") do |f|
          @options[:rackup_file] = f
        end

        opts.on("-X", "--request METHOD", "HTTP method (default: GET)") do |m|
          @options[:method] = m.upcase
        end

        opts.on("-d", "--data DATA", "Request body data") do |d|
          @options[:data] = d
        end

        opts.on("-i", "--show-headers", "Include status and headers in output") do
          @options[:include_headers] = true
        end
      end

      @args = @parser.parse(argv)
    end

    def run
      target = @args.first || "/"
      path, query_string = parse_target(target)

      input = @options[:data]
      input = $stdin.read if input.nil? && !$stdin.tty?

      app = Rackget.load_app(@options[:rackup_file])
      status, headers, body = Rackget.request(app, path,
        method: @options[:method],
        query_string: query_string,
        input: input
      )

      if @options[:include_headers]
        $stdout.puts "#{status} #{Rack::Utils::HTTP_STATUS_CODES[status]}"
        headers.each { |k, v| $stdout.puts "#{k}: #{v}" }
        $stdout.puts
      end

      body.each { |chunk| $stdout.write(chunk) }
      body.close if body.respond_to?(:close)
    end

    private

    def parse_target(target)
      uri = URI.parse(target)
      path = uri.path
      path = "/" if path.nil? || path.empty?
      [path, uri.query]
    rescue URI::InvalidURIError
      [target, nil]
    end
  end
end
