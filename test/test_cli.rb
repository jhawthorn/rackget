# frozen_string_literal: true

require "test_helper"
require "rackget/cli"
require "stringio"

class TestCLI < Minitest::Test
  def with_rackup(code)
    Dir.mktmpdir do |dir|
      rackup = File.join(dir, "config.ru")
      File.write(rackup, code)
      yield dir, rackup
    end
  end

  ECHO_APP = <<~RUBY
    run ->(env) {
      body = "method=\#{env["REQUEST_METHOD"]} path=\#{env["PATH_INFO"]} qs=\#{env["QUERY_STRING"]}"
      body << " body=\#{env["rack.input"].read}" if env["rack.input"]
      [200, { "content-type" => "text/plain", "x-custom" => "yes" }, [body]]
    }
  RUBY

  def run_cli(*argv, rackup:)
    out = StringIO.new
    cli = Rackget::CLI.new(["-r", rackup, *argv])
    $stdout = out
    cli.run
    out.string
  ensure
    $stdout = STDOUT
  end

  def test_simple_path
    with_rackup(ECHO_APP) do |_dir, rackup|
      output = run_cli("/users", rackup: rackup)
      assert_includes output, "method=GET path=/users qs="
    end
  end

  def test_root_default
    with_rackup(ECHO_APP) do |_dir, rackup|
      output = run_cli(rackup: rackup)
      assert_includes output, "method=GET path=/ qs="
    end
  end

  def test_path_with_query_string
    with_rackup(ECHO_APP) do |_dir, rackup|
      output = run_cli("/search?q=hello&page=2", rackup: rackup)
      assert_includes output, "method=GET path=/search qs=q=hello&page=2"
    end
  end

  def test_full_url
    with_rackup(ECHO_APP) do |_dir, rackup|
      output = run_cli("http://localhost/users?page=2", rackup: rackup)
      assert_includes output, "method=GET path=/users qs=page=2"
    end
  end

  def test_full_url_without_query
    with_rackup(ECHO_APP) do |_dir, rackup|
      output = run_cli("http://localhost/about", rackup: rackup)
      assert_includes output, "method=GET path=/about qs="
    end
  end

  def test_full_url_with_port
    with_rackup(ECHO_APP) do |_dir, rackup|
      output = run_cli("http://localhost:3000/items?sort=name", rackup: rackup)
      assert_includes output, "method=GET path=/items qs=sort=name"
    end
  end

  def test_post_with_data_flag
    with_rackup(ECHO_APP) do |_dir, rackup|
      output = run_cli("-X", "POST", "-d", "name=foo", "/users", rackup: rackup)
      assert_includes output, "method=POST path=/users"
      assert_includes output, "body=name=foo"
    end
  end

  def test_put_with_data_flag
    with_rackup(ECHO_APP) do |_dir, rackup|
      output = run_cli("-X", "PUT", "-d", '{"name":"bar"}', "/users/1", rackup: rackup)
      assert_includes output, "method=PUT path=/users/1"
      assert_includes output, 'body={"name":"bar"}'
    end
  end

  def test_delete
    with_rackup(ECHO_APP) do |_dir, rackup|
      output = run_cli("-X", "DELETE", "/users/1", rackup: rackup)
      assert_includes output, "method=DELETE path=/users/1"
    end
  end

  def test_patch_with_data
    with_rackup(ECHO_APP) do |_dir, rackup|
      output = run_cli("-X", "PATCH", "-d", "status=active", "/users/1", rackup: rackup)
      assert_includes output, "method=PATCH path=/users/1"
      assert_includes output, "body=status=active"
    end
  end

  def test_method_is_uppercased
    with_rackup(ECHO_APP) do |_dir, rackup|
      output = run_cli("-X", "post", "-d", "x=1", "/", rackup: rackup)
      assert_includes output, "method=POST"
    end
  end

  def test_show_headers_flag
    with_rackup(ECHO_APP) do |_dir, rackup|
      output = run_cli("-i", "/test", rackup: rackup)
      lines = output.lines
      assert_equal "200 OK\n", lines[0]
      assert_includes output, "content-type: text/plain\n"
      assert_includes output, "x-custom: yes\n"
      assert_includes output, "path=/test qs="
    end
  end

  def test_show_headers_blank_line_separates_body
    with_rackup(ECHO_APP) do |_dir, rackup|
      output = run_cli("-i", "/", rackup: rackup)
      assert_match(/\n\n.*path=\/ qs=/, output)
    end
  end
end
