require "rails/railtie"
require_relative "middleware"

module LookbookTheme
  class Railtie < Rails::Railtie
    config.lookbook_theme = ActiveSupport::OrderedOptions.new
    config.lookbook_theme.enabled = Rails.env.development?
    config.lookbook_theme.mount_path = "/lookbook"
    config.lookbook_theme.storage_key = nil

    initializer "lookbook_theme.middleware" do |app|
      options = app.config.lookbook_theme
      if Rails.env.development? && options.enabled
        app.middleware.insert_before 0, Middleware,
          mount_path: options.mount_path, storage_key: options.storage_key
      end
    end
  end
end
