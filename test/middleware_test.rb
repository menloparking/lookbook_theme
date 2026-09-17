require "minitest/autorun"
require "rack/lint"
require "rack/mock"
require "lookbook_theme"

class MiddlewareTest < Minitest::Test
  HTML = '<html><head></head><body><header id="app-header"></header>caf' + "\u00e9</body></html>"

  class Body
    attr_reader :closed

    def close
      @closed = true
    end

    def each
      yield HTML
    end
  end

  def test_assets_are_packaged_and_head_has_no_body
    app = LookbookTheme::Middleware.new(->(_) { flunk "asset reached downstream" })
    request = Rack::MockRequest.new(Rack::Lint.new(app))
    %w[css js].each do |extension|
      path = "/lookbook/_lookbook_theme/0.1.0/theme.#{extension}"
      response = request.get(path)
      assert_equal 200, response.status
      assert_equal response.body.bytesize.to_s, response["content-length"]
      assert_equal "nosniff", response["x-content-type-options"]
      head = request.head(path)
      assert_equal "", head.body
      assert_equal response["content-length"], head["content-length"]
      assert_equal 405, request.post(path).status
    end
  end

  def test_body_is_closed_even_when_enumeration_fails
    body = Body.new
    def body.each
      raise "stream failed"
    end
    app = LookbookTheme::Middleware.new(->(_) { [200, {"content-type" => "text/html"}, body] })
    assert_raises(RuntimeError) { app.call(env) }
    assert body.closed
  end

  def test_custom_mount_and_storage_key_are_escaped
    app = middleware(mount_path: "/tools/ui", storage_key: 'custom"key')
    _, _, body = app.call(env("/tools/ui/inspect/example"))
    assert_includes body.join, "/tools/ui/_lookbook_theme/0.1.0/theme.js"
    assert_includes body.join, 'data-storage-key="custom&quot;key"'
  end

  def test_duplicate_injection_is_avoided
    app = LookbookTheme::Middleware.new(middleware)
    _, _, body = app.call(env)
    assert_equal 1, body.join.scan('data-lookbook-theme="assets"').length
  end

  def test_injection_closes_body_and_invalidates_cached_representation
    body = Body.new
    headers = {"Content-Type" => "text/html", "Content-Length" => "1", "ETag" => '"old"',
               "Last-Modified" => "yesterday", "Content-MD5" => "old", "Digest" => "old"}
    app = LookbookTheme::Middleware.new(->(request) {
      refute request.key?("HTTP_IF_NONE_MATCH")
      refute request.key?("HTTP_IF_MODIFIED_SINCE")
      [200, headers.freeze, body]
    })
    request = env.merge("HTTP_IF_NONE_MATCH" => '"old"', "HTTP_IF_MODIFIED_SINCE" => "yesterday")
    status, result, chunks = app.call(request)
    assert_equal 200, status
    assert body.closed
    assert_equal chunks.join.bytesize.to_s, result["content-length"]
    assert_equal "no-store", result["cache-control"]
    %w[etag last-modified content-md5 digest].each { |key| refute result.key?(key) }
    assert_equal '"old"', request["HTTP_IF_NONE_MATCH"]
    assert_equal '"old"', headers["ETag"]
  end

  def test_invalid_mounts_are_rejected
    ["/", "lookbook", "/foo/../bar", "/foo/", '/foo"', "/foo%20bar", "//foo"].each do |path|
      assert_raises(ArgumentError) { middleware(mount_path: path) }
    end
  end

  def test_mount_is_captured_before_downstream_rewrites_env
    app = LookbookTheme::Middleware.new(->(request) {
      request["SCRIPT_NAME"] = "/lookbook"
      request["PATH_INFO"] = "/inspect/example"
      [200, {"content-type" => "text/html"}, [HTML]]
    })
    assert_includes app.call(env).last.join, "theme.js"
    assert_includes middleware.call(env("/inspect/example").merge("SCRIPT_NAME" => "/lookbook"))
      .last.join, "theme.js"
  end

  def test_non_chrome_html_is_unchanged
    ["<head></head><body>Application</body>", '<header id="app-header"></header>'].each do |html|
      response = [200, {"content-type" => "text/html"}, [html]]
      app = LookbookTheme::Middleware.new(->(_) { response })
      assert_equal response, app.call(env)
    end
  end

  def test_non_eligible_responses_are_not_consumed_or_closed
    [
      [env("/lookbook/preview/example"), 200, "text/html", {}],
      [env("/lookbook/preview"), 200, "text/html", {}],
      [env("/lookbookish"), 200, "text/html", {}],
      [env("/application"), 200, "text/html", {}],
      [env.merge("REQUEST_METHOD" => "HEAD"), 200, "text/html", {}],
      [env.merge("HTTP_RANGE" => "bytes=0-5"), 200, "text/html", {}],
      [env, 206, "text/html", {}],
      [env, 304, "text/html", {}],
      [env, 200, "application/json", {}],
      [env, 200, "text/html", {"Content-Encoding" => "gzip"}],
      [env, 200, "text/html", {"cache-control" => "private, no-transform"}]
    ].each do |request, status, type, headers|
      body = Body.new
      response = [status, {"content-type" => type}.merge(headers), body]
      app = LookbookTheme::Middleware.new(->(_) { response })
      assert_same response, app.call(request)
      refute body.closed
    end
  end

  def test_unknown_and_traversal_asset_paths_never_read_files
    request = Rack::MockRequest.new(Rack::Lint.new(middleware))
    %w[other.js ../version.rb %2e%2e/LICENSE theme.js/extra].each do |name|
      assert_equal 404, request.get("/lookbook/_lookbook_theme/0.1.0/#{name}").status
      assert_equal "", request.head("/lookbook/_lookbook_theme/0.1.0/#{name}").body
    end
  end

  private

  def env(path = "/lookbook/inspect/example")
    Rack::MockRequest.env_for(path)
  end

  def middleware(**options)
    LookbookTheme::Middleware.new(
      ->(_) { [200, {"content-type" => "text/html"}, [HTML]] }, **options
    )
  end
end
