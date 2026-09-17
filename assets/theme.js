(() => {
  const storageKey = document.currentScript.dataset.storageKey
  const schemes = ['system', 'light', 'dark']
  const media = window.matchMedia('(prefers-color-scheme: dark)')
  let scheme = 'system'

  try {
    const stored = window.localStorage.getItem(storageKey)
    if (schemes.includes(stored)) scheme = stored
  } catch (_error) {
    // The in-memory selection still works when browser storage is unavailable.
  }

  const updateCodeThemes = () => {
    const dark = scheme === 'dark' || (scheme === 'system' && media.matches)
    document.querySelectorAll('.theme-github').forEach((element) => {
      element.classList.toggle('dark', dark)
    })
  }

  const applyScheme = () => {
    document.documentElement.dataset.lookbookColorScheme = scheme
    updateCodeThemes()
  }

  const installControl = () => {
    if (document.querySelector('.lookbook-theme-select')) return
    const target = document.querySelector('#app-header .toolbar-sections > :last-child')
    if (!target) return

    const select = document.createElement('select')
    select.className = 'lookbook-theme-select'
    select.setAttribute('aria-label', 'Lookbook color scheme')
    select.title = 'Lookbook color scheme'
    schemes.forEach((value) => {
      const option = document.createElement('option')
      option.value = value
      option.textContent = value[0].toUpperCase() + value.slice(1)
      select.append(option)
    })
    select.value = scheme
    select.addEventListener('change', () => {
      scheme = select.value
      try {
        window.localStorage.setItem(storageKey, scheme)
      } catch (_error) {
        // Keep the selected scheme, including for subsequently inserted code panels.
      }
      applyScheme()
    })
    target.prepend(select)
  }

  applyScheme()
  window.addEventListener('DOMContentLoaded', () => {
    installControl()
    updateCodeThemes()
    new MutationObserver(() => {
      installControl()
      updateCodeThemes()
    }).observe(document.body, { childList: true, subtree: true })
  })
  media.addEventListener('change', updateCodeThemes)
})()
