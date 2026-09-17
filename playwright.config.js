const { defineConfig } = require('@playwright/test')

module.exports = defineConfig({
  testDir: './test/browser',
  use: { baseURL: 'http://127.0.0.1:4317' },
  webServer: {
    command: 'bundle exec rackup -I lib -s puma -o 127.0.0.1 -p 4317 test/dummy/config.ru',
    url: 'http://127.0.0.1:4317',
    reuseExistingServer: false
  }
})
