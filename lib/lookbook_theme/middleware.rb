require "cgi/escape"
require_relative "version"

module LookbookTheme
  class Middleware
    ASSETS = {"theme.css" => "text/css; charset=utf-8",
              "theme.js" => "text/javascript; charset=utf-8"}.freeze
    ASSET_ROOT = File.expand_path("../../assets", __dir__)
    STALE_HEADERS = %w[content-length content-md5 digest etag last-modified repr-digest
      content-digest cache-control].freeze

    def call(env)
      path = "#{env["SCRIPT_NAME"]}#{env["PATH_INFO"]}"
      return asset_response(env, path) if path.start_with?("#{@mount_path}/_lookbook_theme/")

      eligible = env["REQUEST_METHOD"] == "GET" && !env.key?("HTTP_RANGE") &&
        (path == @mount_path || path.start_with?("#{@mount_path}/")) &&
        !path.match?(%r{\A#{Regexp.escape(@mount_path)}/preview(?:/|\z)})
      # Avoid a downstream 304 for the original, unpatched representation.
      request = eligible ? env.except(*CONDITIONAL_HEADERS) : env
      response = @app.call(request)
      status, headers, body = response
      normalized = headers.transform_keys(&:downcase)
      return response unless eligible && status == 200 &&
        normalized["content-type"].to_s.split(";").first == "text/html" &&
        !normalized.key?("content-encoding") && !normalized.key?("content-range") &&
        !normalized["cache-control"].to_s.match?(/\bno-transform\b/i)

      html = +""
      begin
        body.each { |chunk| html << chunk }
      ensure
        body.close if body.respond_to?(:close)
      end
      # Preview HTML must never inherit chrome colors, even with custom preview routes.
      return [status, headers, [html]] unless html.match?(/\bid=["']app-header["']/) &&
        html.include?("</head>") && !html.include?('data-lookbook-theme="assets"')

      html = html.sub("</head>", "#{@tags}</head>")
      patched_headers = normalized.except(*STALE_HEADERS)
      patched_headers["content-length"] = html.bytesize.to_s
      patched_headers["cache-control"] = "no-store"
      [status, patched_headers, [html]]
    end

    def initialize(app, mount_path: "/lookbook", storage_key: nil)
      unless mount_path.is_a?(String) && mount_path.match?(%r{\A(?:/[A-Za-z0-9_-]+)+\z})
        raise ArgumentError, "mount_path must contain safe, nonempty URL segments (no trailing slash)"
      end
      @app = app
      @mount_path = mount_path
      @asset_prefix = "#{mount_path}/_lookbook_theme/#{VERSION}/"
      key = CGI.escapeHTML(storage_key || "lookbook-theme:#{mount_path}:color-scheme")
      @tags = <<~HTML
        <link rel="stylesheet" href="#{@asset_prefix}theme.css" data-lookbook-theme="assets">
        <script src="#{@asset_prefix}theme.js" data-storage-key="#{key}"></script>
      HTML
    end

    private

    CONDITIONAL_HEADERS = %w[HTTP_IF_MODIFIED_SINCE HTTP_IF_NONE_MATCH].freeze

    def asset_response(env, path)
      name = path.delete_prefix(@asset_prefix)
      type = ASSETS[name] if path.start_with?(@asset_prefix)
      unless type
        return [404, {"content-type" => "text/plain"},
          (env["REQUEST_METHOD"] == "HEAD") ? [] : ["Not found"]]
      end
      unless %w[GET HEAD].include?(env["REQUEST_METHOD"])
        return [405, {"allow" => "GET, HEAD", "content-type" => "text/plain"}, ["Method not allowed"]]
      end
      content = File.binread(File.join(ASSET_ROOT, name))
      headers = {"cache-control" => "no-store", "content-length" => content.bytesize.to_s,
                 "content-type" => type, "x-content-type-options" => "nosniff"}
      [200, headers, (env["REQUEST_METHOD"] == "HEAD") ? [] : [content]]
    end
  end
end
