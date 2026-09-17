require_relative "lib/lookbook_theme/version"

Gem::Specification.new do |spec|
  spec.name = "lookbook_theme"
  spec.version = LookbookTheme::VERSION
  spec.authors = ["lookbook_theme contributors"]
  spec.summary = "Development light, dark, and system chrome for Lookbook 2.3.15"
  spec.description = "Development-only Lookbook chrome theming with packaged assets and Rack middleware."
  spec.homepage = "https://github.com/menloparking/lookbook_theme"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4", "< 4.1"
  spec.files = Dir["lib/**/*.rb", "assets/*", "LICENSE", "README.md"]
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.add_dependency "lookbook", "= 2.3.15"
  spec.add_dependency "railties", "~> 8.1.0"
end
