# Lookbook Theme

System, light, and dark color schemes for **Lookbook's chrome**, not your
application previews. The selector lives in Lookbook's header and remembers its
selection in local storage. System mode follows live OS preference changes. Code
panels, including dynamically inserted panels, follow the effective scheme.

This is a small, temporary integration for Lookbook **2.3.15**, which has static
UI themes but no supported runtime color-scheme or chrome-asset extension point.
It uses Lookbook's CSS variables and DOM structure, not an application palette,
layout, asset pipeline, or Phlex component library. A shared UI gem can remain
entirely separate and use this gem only for its development Lookbook workflow.

## Installation

Install from GitHub; this release is not published to RubyGems:

```ruby
group :development do
  gem "lookbook", "2.3.15"
  gem "lookbook_theme", github: "menloparking/lookbook_theme", tag: "v0.1.0"
end
```

Mount Lookbook in `config/routes.rb`:

```ruby
mount Lookbook::Engine, at: "/lookbook" if Rails.env.development?
```

Opt in in `config/environments/development.rb`:

```ruby
config.lookbook_theme.enabled = true
```

Restart Rails. No assets need to be copied or compiled. The Railtie does nothing
unless enabled, and never installs middleware outside development.

## Configuration

For a custom mount, use exactly the same URL in routes and configuration:

```ruby
config.lookbook_theme.enabled = true
config.lookbook_theme.mount_path = "/tools/catalog"
config.lookbook_theme.storage_key = "my-project:lookbook:color-scheme"
```

- `enabled`: defaults to `false`.
- `mount_path`: defaults to `/lookbook`; absolute, non-root URL with no trailing
  slash. Segments may contain letters, digits, underscores, and hyphens.
- `storage_key`: defaults to `lookbook-theme:<mount_path>:color-scheme`. Use a
  project-specific key when multiple projects share a browser origin and path.

The selector uses the neutral `.lookbook-theme-select` class. Accepted stored
values are `system`, `light`, and `dark`; invalid values fall back to `system`.
When the gem's storage reads/writes fail, the selection survives for the current
page. Lookbook itself may not work when all browser storage is disabled.

For explicit middleware installation instead of the Railtie opt-in, use a
development initializer and leave `enabled` false:

```ruby
if Rails.env.development?
  require "lookbook_theme/middleware"
  Rails.application.config.middleware.insert_before 0,
    LookbookTheme::Middleware, mount_path: "/lookbook"
end
```

Place it before Lookbook's static middleware. Compression applied downstream
prevents injection; use the normal uncompressed development stack. If requiring
the gem before Rails manually, require `lookbook_theme/railtie` after Rails
loads.

## Boundaries

- The compatibility boundary is Lookbook **2.3.15**, Rails **8.1**, and Ruby
  **3.4 or 4.0**. The gem constrains these dependencies; other versions are not
  claimed compatible. CI exercises both Ruby series against Rails 8.1.
- Browser tests use Playwright Chromium. CSS requires `light-dark()` and
  `color-mix()` (Chromium 123+, Firefox 120+, Safari 17.5+). These are feature
  minimums, not a claim that Firefox or Safari have been tested.
- Only successful, unencoded HTML GET responses under the configured mount,
  containing Lookbook's header and a closing head tag, are patched. Preview
  routes, partial responses, range requests, and `no-transform` responses are
  left alone. HEAD responses are passed through without buffering.
- Preview iframes and the host application keep their own styles and scheme. The
  header retains Lookbook's branding; this is not a palette replacement.
- HTML responses are buffered; consumed bodies are closed, including on errors.
  Lengths use bytes. Conditional GET validators are suppressed for candidate
  chrome requests; modified responses discard stale validators and use
  `Cache-Control: no-store`. Streaming chrome is not supported.
- Assets are served from an exact allowlist at
  `<mount_path>/_lookbook_theme/0.1.0/theme.{css,js}`, independent of Rails
  assets. The reserved directory is owned by this gem. No user path is read from
  disk.
- CSP must allow same-origin external scripts and styles. This gem adds no
  inline script or style and does not weaken CSP or change authentication.
- Install once. Do not combine this gem with a local copy of the original patch.

## Development

```sh
bundle install
bundle exec rake test
npm ci
npx playwright install chromium
npm test
bundle exec standardrb
npm run lint:js
gem build lookbook_theme.gemspec
```

The dummy Rails app loads Action Controller and real Lookbook, with a plain Ruby
renderable preview. It uses neither a database nor an application UI gem. Tests
make no third-party HTTP requests; browser traffic is restricted to the local
dummy server. Dependency installation and browser downloads require network
access. Browser tests cover desktop/mobile, real packaged assets, custom mounts,
system/light/dark, persistence, OS changes, code panels, and preview isolation.

This repository does not provision its own development container. The commands
work in an existing Ruby/Node Linux development container; no broader host or
container-runtime matrix is claimed. Tests need no credentials. Source
publishing through GitHub is a separate, explicitly authorized operation.

## License

This standalone gem is distributed under [MIT](LICENSE). No repository-level
license was present in the original application, so no license for the
application as a whole is inferred. The grant here applies only to this
standalone gem. No unverified copyright holder or ownership-transfer claim is
added.

Lookbook is a separate MIT-licensed dependency, copyright 2021 Mark Perkins. Its
code and assets are not vendored here and retain their own license.
