const { test, expect } = require('@playwright/test')

const inspector = '/tools/catalog/inspect/example/default'
const storageKey = 'lookbook-theme:/tools/catalog:color-scheme'

test.beforeEach(async ({ context }) => {
  await context.route('**/*', (route) => {
    const url = new URL(route.request().url())
    return url.hostname === '127.0.0.1' ? route.continue() : route.abort()
  })
})

test('real Lookbook chrome supports system, persistence, OS changes and isolated previews', async ({ page }) => {
  const failures = []
  page.on('pageerror', (error) => failures.push(error.message))
  await page.emulateMedia({ colorScheme: 'light' })
  await page.goto(inspector)
  const select = page.getByRole('combobox', { name: 'Lookbook color scheme' })
  const sidebar = page.locator('#app-sidebar')
  await expect(select).toHaveValue('system')
  const lightColor = await sidebar.evaluate((element) => getComputedStyle(element).backgroundColor)
  expect(lightColor).not.toBe('rgba(0, 0, 0, 0)')

  await page.emulateMedia({ colorScheme: 'dark' })
  await expect(sidebar).not.toHaveCSS('background-color', lightColor)
  const darkColor = await sidebar.evaluate((element) => getComputedStyle(element).backgroundColor)
  await select.selectOption('light')
  await expect(sidebar).toHaveCSS('background-color', lightColor)
  await select.selectOption('dark')
  await page.reload()
  await expect(select).toHaveValue('dark')
  await page.emulateMedia({ colorScheme: 'light' })
  await expect(sidebar).toHaveCSS('background-color', darkColor)
  expect(await page.evaluate((key) => localStorage.getItem(key), storageKey)).toBe('dark')

  const code = page.locator('.theme-github').first()
  await expect(code).toHaveClass(/dark/)
  // Exercise the real code-panel markup when Lookbook inserts it after navigation.
  await code.evaluate((element) => {
    const clone = element.cloneNode(true)
    clone.id = 'dynamic-code-panel'
    clone.classList.remove('dark')
    document.body.append(clone)
  })
  await expect(page.locator('#dynamic-code-panel')).toHaveClass(/dark/)

  await page.getByRole('button', { name: 'Example', exact: true }).click()
  await page.getByRole('link', { name: 'Alternate', exact: true }).click()
  await expect(page).toHaveURL(/\/inspect\/example\/alternate/)
  await expect(page.locator('.theme-github').first()).toHaveClass(/dark/)
  await expect(select).toHaveCount(1)
  await select.selectOption('system')
  await expect(code).not.toHaveClass(/dark/)
  await page.emulateMedia({ colorScheme: 'dark' })
  await expect(code).toHaveClass(/dark/)
  await expect(page.locator('#dynamic-code-panel')).toHaveClass(/dark/)

  const frame = page.frameLocator('iframe[src*="/preview/"]')
  await expect(frame.locator('#example-button')).toHaveText('Independent preview')
  await expect(frame.locator('html')).not.toHaveAttribute('data-lookbook-color-scheme')
  await expect(frame.locator('script[src*="_lookbook_theme"]')).toHaveCount(0)

  const asset = await page.request.get('/tools/catalog/_lookbook_theme/0.1.0/theme.css')
  expect(asset.status()).toBe(200)
  expect(await asset.text()).toContain('--lookbook-sidebar-bg')
  await page.goto('/')
  await expect(page.locator('html')).not.toHaveAttribute('data-lookbook-color-scheme')
  expect(failures).toEqual([])
})

test('invalid stored schemes fall back to system', async ({ page }) => {
  await page.addInitScript((key) => localStorage.setItem(key, 'invalid'), storageKey)
  await page.goto(inspector)
  await expect(page.getByRole('combobox', { name: 'Lookbook color scheme' })).toHaveValue('system')
  await expect(page.locator('html')).toHaveAttribute('data-lookbook-color-scheme', 'system')
})

test('mobile selector remains usable and storage failure preserves the in-memory choice', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.emulateMedia({ colorScheme: 'light' })
  await page.addInitScript(() => {
    // Lookbook itself does not tolerate blocked storage. Isolate our fallback.
    for (const method of ['getItem', 'setItem']) {
      const original = Storage.prototype[method]
      Storage.prototype[method] = function (key, ...args) {
        if (key.startsWith('lookbook-theme:')) throw new Error('Storage disabled')
        return original.call(this, key, ...args)
      }
    }
  })
  await page.goto(inspector)
  const select = page.getByRole('combobox', { name: 'Lookbook color scheme' })
  await expect(select).toBeVisible()
  await select.selectOption('dark')
  await page.locator('.theme-github').first().evaluate((element) => {
    const clone = element.cloneNode(true)
    clone.id = 'late-code'
    clone.classList.remove('dark')
    document.body.append(clone)
  })
  await expect(page.locator('#late-code')).toHaveClass(/dark/)
  await page.emulateMedia({ colorScheme: 'dark' })
  await page.emulateMedia({ colorScheme: 'light' })
  await expect(page.locator('#late-code')).toHaveClass(/dark/)
  await expect(page.locator('html')).toHaveAttribute('data-lookbook-color-scheme', 'dark')
})
