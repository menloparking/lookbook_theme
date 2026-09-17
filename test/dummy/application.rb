require "bundler/setup"
require "action_controller/railtie"
require "lookbook"
require "lookbook_theme"

module Dummy
  class Application < Rails::Application
    config.root = File.expand_path(__dir__)
    config.eager_load = false
    config.secret_key_base = "lookbook-theme-test-only-secret-" * 4
    config.hosts = ["127.0.0.1", "localhost", "example.org"]
    config.logger = Logger.new(File::NULL)
    config.action_dispatch.show_exceptions = :none
    config.lookbook.preview_paths = [File.join(__dir__, "previews")]
    config.autoload_paths << File.join(__dir__, "previews")
    config.lookbook.page_paths = []
    config.lookbook.listen = false
    config.lookbook.live_updates = false
    config.lookbook.reload_on_change = false
    if ENV.key?("THEME_ENABLED")
      config.lookbook_theme.enabled = ENV.fetch("THEME_ENABLED") == "true"
    end
    config.lookbook_theme.mount_path = ENV["THEME_MOUNT"] if ENV.key?("THEME_MOUNT")

    routes.append do
      mount Lookbook::Engine, at: Rails.application.config.lookbook_theme.mount_path
      get "/", to: ->(_) { [200, {"content-type" => "text/html"}, ["<head></head>Host app"]] }
    end
  end
end

Dummy::Application.initialize!
