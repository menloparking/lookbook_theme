require "minitest/autorun"
require "open3"
require "rbconfig"

class RailtieTest < Minitest::Test
  def test_opt_in_only_installs_in_development
    [["development", "true", true], ["development", "false", false],
      ["test", "true", false], ["production", "true", false]].each do |environment, enabled, expected|
      script = <<~RUBY
        require_relative "test/dummy/application"
        require "rack/mock"
        app = Rails.application
        installed = app.middleware.any? { |entry| entry.klass == LookbookTheme::Middleware }
        abort "unexpected middleware presence" unless installed == #{expected}
        if installed
          request = Rack::MockRequest.new(app)
          response = request.get("/tools/catalog/inspect/example/default", "HTTP_HOST" => "localhost")
          abort "inspector failed: \#{response.status}" unless response.status == 200
          abort "missing assets" unless response.body.include?("/_lookbook_theme/0.1.0/theme.js")
          preview = request.get("/tools/catalog/preview/example/default", "HTTP_HOST" => "localhost")
          abort "preview failed" unless preview.status == 200
          abort "preview polluted" if preview.body.include?("_lookbook_theme")
          abort "missing preview" unless preview.body.include?("Independent preview")
        end
      RUBY
      output, status = Open3.capture2e(
        {"RAILS_ENV" => environment, "THEME_ENABLED" => enabled},
        RbConfig.ruby, "-Ilib", "-e", script, chdir: File.expand_path("..", __dir__)
      )
      assert status.success?, "#{environment}/#{enabled}: #{output}"
    end
  end
end
