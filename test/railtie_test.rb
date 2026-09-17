require "minitest/autorun"
require "open3"
require "rbconfig"

class RailtieTest < Minitest::Test
  %w[development test production].product([nil, "true", "false"]).each do |environment, enabled|
    define_method("test_#{environment}_#{enabled || "default"}") do
      expected = environment == "development" && enabled != "false"
      configured = enabled.nil? ? environment == "development" : enabled == "true"
      ["/lookbook", "/tools/catalog"].each do |mount|
        script = <<~RUBY
          require_relative "test/dummy/application"
          require "rack/mock"
          app = Rails.application
          abort "unexpected enabled config" unless app.config.lookbook_theme.enabled == #{configured}
          installed = app.middleware.any? { |entry| entry.klass == LookbookTheme::Middleware }
          abort "unexpected middleware presence" unless installed == #{expected}
          if installed
            request = Rack::MockRequest.new(app)
            response = request.get("#{mount}/inspect/example/default", "HTTP_HOST" => "localhost")
            abort "inspector failed: \#{response.status}" unless response.status == 200
            asset = "#{mount}/_lookbook_theme/\#{LookbookTheme::VERSION}/theme.js"
            abort "missing assets" unless response.body.include?(asset)
            abort "asset failed" unless request.get(asset, "HTTP_HOST" => "localhost").status == 200
            preview = request.get("#{mount}/preview/example/default", "HTTP_HOST" => "localhost")
            abort "preview failed" unless preview.status == 200
            abort "preview polluted" if preview.body.include?("_lookbook_theme")
            abort "missing preview" unless preview.body.include?("Independent preview")
          end
        RUBY
        output, status = Open3.capture2e(
          {"RAILS_ENV" => environment, "THEME_ENABLED" => enabled,
           "THEME_MOUNT" => (mount unless mount == "/lookbook")},
          RbConfig.ruby, "-Ilib", "-e", script, chdir: File.expand_path("..", __dir__)
        )
        assert status.success?, "#{environment}/#{enabled}/#{mount}: #{output}"
      end
    end
  end
end
