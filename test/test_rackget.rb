# frozen_string_literal: true

require "test_helper"

class TestRackget < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Rackget::VERSION
  end

  def simple_app
    ->(env) { [200, { "content-type" => "text/plain" }, ["hello from #{env["PATH_INFO"]}"]] }
  end

  def test_get_root
    status, headers, body = Rackget.get(simple_app, "/")
    assert_equal 200, status
    assert_equal "text/plain", headers["content-type"]

    chunks = []
    body.each { |chunk| chunks << chunk }
    assert_equal "hello from /", chunks.join
  end

  def test_get_with_path
    status, _headers, body = Rackget.get(simple_app, "/users")
    assert_equal 200, status

    chunks = []
    body.each { |chunk| chunks << chunk }
    assert_equal "hello from /users", chunks.join
  end

  def test_get_with_query_string
    app = ->(env) { [200, {}, ["qs=#{env["QUERY_STRING"]}"]] }
    _status, _headers, body = Rackget.get(app, "/search", query_string: "q=hello")

    chunks = []
    body.each { |chunk| chunks << chunk }
    assert_equal "qs=q=hello", chunks.join
  end

  def test_load_app
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "config.ru"), 'run ->(env) { [200, {}, ["ok"]] }')
      app = Rackget.load_app(File.join(dir, "config.ru"))
      status, _headers, body = app.call(Rack::MockRequest.env_for("/"))

      assert_equal 200, status
      chunks = []
      body.each { |chunk| chunks << chunk }
      assert_equal "ok", chunks.join
    end
  end

  def test_load_app_missing_file
    assert_raises(Rackget::Error) { Rackget.load_app("nonexistent.ru") }
  end

  def test_request_post
    app = ->(env) { [201, {}, ["method=#{env["REQUEST_METHOD"]}"]] }
    status, _headers, body = Rackget.request(app, "/users", method: "POST")
    assert_equal 201, status
    assert_equal "method=POST", body_string(body)
  end

  def test_request_put
    app = ->(env) { [200, {}, ["method=#{env["REQUEST_METHOD"]}"]] }
    _status, _headers, body = Rackget.request(app, "/users/1", method: "PUT")
    assert_equal "method=PUT", body_string(body)
  end

  def test_request_delete
    app = ->(env) { [200, {}, ["method=#{env["REQUEST_METHOD"]}"]] }
    _status, _headers, body = Rackget.request(app, "/users/1", method: "DELETE")
    assert_equal "method=DELETE", body_string(body)
  end

  def test_request_patch
    app = ->(env) { [200, {}, ["method=#{env["REQUEST_METHOD"]}"]] }
    _status, _headers, body = Rackget.request(app, "/users/1", method: "PATCH")
    assert_equal "method=PATCH", body_string(body)
  end

  def test_request_with_input
    app = ->(env) { [200, {}, ["body=#{env["rack.input"].read}"]] }
    _status, _headers, body = Rackget.request(app, "/users", method: "POST", input: "name=foo")
    assert_equal "body=name=foo", body_string(body)
  end

  def test_request_defaults_to_get
    app = ->(env) { [200, {}, ["method=#{env["REQUEST_METHOD"]}"]] }
    _status, _headers, body = Rackget.request(app, "/")
    assert_equal "method=GET", body_string(body)
  end

  def test_request_with_custom_headers
    app = ->(env) { [200, {}, ["accept=#{env["HTTP_ACCEPT"]}"]] }
    _status, _headers, body = Rackget.request(app, "/", headers: { "Accept" => "application/json" })
    assert_equal "accept=application/json", body_string(body)
  end

  def test_request_with_content_type_header
    app = ->(env) { [200, {}, ["ct=#{env["CONTENT_TYPE"]}"]] }
    _status, _headers, body = Rackget.request(app, "/", method: "POST", input: "{}", headers: { "Content-Type" => "application/json" })
    assert_equal "ct=application/json", body_string(body)
  end

  def test_request_with_multiple_headers
    app = ->(env) { [200, {}, ["#{env["HTTP_ACCEPT"]}|#{env["HTTP_AUTHORIZATION"]}"]] }
    _status, _headers, body = Rackget.request(app, "/", headers: {
      "Accept" => "text/html",
      "Authorization" => "Bearer token123"
    })
    assert_equal "text/html|Bearer token123", body_string(body)
  end

  private

  def body_string(body)
    chunks = []
    body.each { |chunk| chunks << chunk }
    chunks.join
  end
end
