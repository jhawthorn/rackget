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

  def run_cli(*argv, rackup:, stdin: nil)
    out = StringIO.new
    stdin_io = stdin ? StringIO.new(stdin) : StringIO.new
    cli = Rackget::CLI.new(["-r", rackup, *argv], stdout: out, stdin: stdin_io)
    exit_code = cli.run
    [out.string, exit_code]
  end

  def test_simple_path
    with_rackup(ECHO_APP) do |_dir, rackup|
      output, _exit = run_cli("/users", rackup: rackup)
      assert_includes output, "method=GET path=/users qs="
    end
  end

  def test_root_default
    with_rackup(ECHO_APP) do |_dir, rackup|
      output, _exit = run_cli(rackup: rackup)
      assert_includes output, "method=GET path=/ qs="
    end
  end

  def test_path_with_query_string
    with_rackup(ECHO_APP) do |_dir, rackup|
      output, _exit = run_cli("/search?q=hello&page=2", rackup: rackup)
      assert_includes output, "method=GET path=/search qs=q=hello&page=2"
    end
  end

  def test_full_url
    with_rackup(ECHO_APP) do |_dir, rackup|
      output, _exit = run_cli("http://localhost/users?page=2", rackup: rackup)
      assert_includes output, "method=GET path=/users qs=page=2"
    end
  end

  def test_full_url_without_query
    with_rackup(ECHO_APP) do |_dir, rackup|
      output, _exit = run_cli("http://localhost/about", rackup: rackup)
      assert_includes output, "method=GET path=/about qs="
    end
  end

  def test_full_url_with_port
    with_rackup(ECHO_APP) do |_dir, rackup|
      output, _exit = run_cli("http://localhost:3000/items?sort=name", rackup: rackup)
      assert_includes output, "method=GET path=/items qs=sort=name"
    end
  end

  def test_post_with_data_flag
    with_rackup(ECHO_APP) do |_dir, rackup|
      output, _exit = run_cli("-X", "POST", "-d", "name=foo", "/users", rackup: rackup)
      assert_includes output, "method=POST path=/users"
      assert_includes output, "body=name=foo"
    end
  end

  def test_put_with_data_flag
    with_rackup(ECHO_APP) do |_dir, rackup|
      output, _exit = run_cli("-X", "PUT", "-d", '{"name":"bar"}', "/users/1", rackup: rackup)
      assert_includes output, "method=PUT path=/users/1"
      assert_includes output, 'body={"name":"bar"}'
    end
  end

  def test_delete
    with_rackup(ECHO_APP) do |_dir, rackup|
      output, _exit = run_cli("-X", "DELETE", "/users/1", rackup: rackup)
      assert_includes output, "method=DELETE path=/users/1"
    end
  end

  def test_patch_with_data
    with_rackup(ECHO_APP) do |_dir, rackup|
      output, _exit = run_cli("-X", "PATCH", "-d", "status=active", "/users/1", rackup: rackup)
      assert_includes output, "method=PATCH path=/users/1"
      assert_includes output, "body=status=active"
    end
  end

  def test_method_is_uppercased
    with_rackup(ECHO_APP) do |_dir, rackup|
      output, _exit = run_cli("-X", "post", "-d", "x=1", "/", rackup: rackup)
      assert_includes output, "method=POST"
    end
  end

  def test_post_with_stdin
    with_rackup(ECHO_APP) do |_dir, rackup|
      output, _exit = run_cli("-X", "POST", "/submit", rackup: rackup, stdin: "from_stdin=yes")
      assert_includes output, "method=POST path=/submit"
      assert_includes output, "body=from_stdin=yes"
    end
  end

  def test_data_flag_takes_precedence_over_stdin
    with_rackup(ECHO_APP) do |_dir, rackup|
      output, _exit = run_cli("-X", "POST", "-d", "from_flag", "/submit", rackup: rackup, stdin: "from_stdin")
      assert_includes output, "body=from_flag"
      refute_includes output, "from_stdin"
    end
  end

  def test_show_headers_flag
    with_rackup(ECHO_APP) do |_dir, rackup|
      output, _exit = run_cli("-i", "/test", rackup: rackup)
      lines = output.lines
      assert_equal "200 OK\n", lines[0]
      assert_includes output, "content-type: text/plain\n"
      assert_includes output, "x-custom: yes\n"
      assert_includes output, "path=/test qs="
    end
  end

  def test_show_headers_blank_line_separates_body
    with_rackup(ECHO_APP) do |_dir, rackup|
      output, _exit = run_cli("-i", "/", rackup: rackup)
      assert_match(/\n\n.*path=\/ qs=/, output)
    end
  end

  # Custom headers

  HEADER_APP = <<~RUBY
    run ->(env) {
      parts = []
      parts << "host=\#{env["HTTP_HOST"]}" if env["HTTP_HOST"]
      parts << "accept=\#{env["HTTP_ACCEPT"]}" if env["HTTP_ACCEPT"]
      parts << "auth=\#{env["HTTP_AUTHORIZATION"]}" if env["HTTP_AUTHORIZATION"]
      parts << "ct=\#{env["CONTENT_TYPE"]}" if env["CONTENT_TYPE"]
      [200, {}, [parts.join(" ")]]
    }
  RUBY

  def test_custom_header
    with_rackup(HEADER_APP) do |_dir, rackup|
      output, _exit = run_cli("-H", "Accept: application/json", "/", rackup: rackup)
      assert_includes output, "accept=application/json"
    end
  end

  def test_multiple_custom_headers
    with_rackup(HEADER_APP) do |_dir, rackup|
      output, _exit = run_cli(
        "-H", "Accept: text/html",
        "-H", "Authorization: Bearer token123",
        "/", rackup: rackup
      )
      assert_includes output, "accept=text/html"
      assert_includes output, "auth=Bearer token123"
    end
  end

  def test_host_from_full_url
    with_rackup(HEADER_APP) do |_dir, rackup|
      output, _exit = run_cli("http://myapp.example.com/", rackup: rackup)
      assert_includes output, "host=myapp.example.com"
    end
  end

  def test_host_from_full_url_with_port
    with_rackup(HEADER_APP) do |_dir, rackup|
      output, _exit = run_cli("http://localhost:3000/", rackup: rackup)
      assert_includes output, "host=localhost:3000"
    end
  end

  def test_host_not_set_for_plain_path
    with_rackup(HEADER_APP) do |_dir, rackup|
      output, _exit = run_cli("/", rackup: rackup)
      refute_includes output, "host=myapp"
    end
  end

  def test_explicit_host_header_overrides_url
    with_rackup(HEADER_APP) do |_dir, rackup|
      output, _exit = run_cli("-H", "Host: custom.test", "http://fromurl.test/", rackup: rackup)
      assert_includes output, "host=custom.test"
      refute_includes output, "fromurl"
    end
  end

  def test_content_type_header
    with_rackup(HEADER_APP) do |_dir, rackup|
      output, _exit = run_cli(
        "-X", "POST",
        "-H", "Content-Type: application/json",
        "-d", '{"a":1}',
        "/", rackup: rackup
      )
      assert_includes output, "ct=application/json"
    end
  end

  # Exit codes

  STATUS_APP = <<~RUBY
    run ->(env) {
      status = env["PATH_INFO"].delete_prefix("/").to_i
      [status, {}, ["status=\#{status}"]]
    }
  RUBY

  def test_exit_0_for_200
    with_rackup(STATUS_APP) do |_dir, rackup|
      _output, exit_code = run_cli("/200", rackup: rackup)
      assert_equal 0, exit_code
    end
  end

  def test_exit_0_for_201
    with_rackup(STATUS_APP) do |_dir, rackup|
      _output, exit_code = run_cli("/201", rackup: rackup)
      assert_equal 0, exit_code
    end
  end

  def test_exit_0_for_301
    with_rackup(STATUS_APP) do |_dir, rackup|
      _output, exit_code = run_cli("/301", rackup: rackup)
      assert_equal 0, exit_code
    end
  end

  def test_exit_1_for_404
    with_rackup(STATUS_APP) do |_dir, rackup|
      _output, exit_code = run_cli("/404", rackup: rackup)
      assert_equal 1, exit_code
    end
  end

  def test_exit_1_for_500
    with_rackup(STATUS_APP) do |_dir, rackup|
      _output, exit_code = run_cli("/500", rackup: rackup)
      assert_equal 1, exit_code
    end
  end

  def test_body_still_output_on_error_status
    with_rackup(STATUS_APP) do |_dir, rackup|
      output, exit_code = run_cli("/422", rackup: rackup)
      assert_equal 1, exit_code
      assert_includes output, "status=422"
    end
  end
end
