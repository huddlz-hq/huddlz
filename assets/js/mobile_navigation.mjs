const MOBILE_NAVIGATION_QUERY = "(max-width: 760px)"
const FOCUSABLE_SELECTOR = [
  "a[href]",
  "button:not([disabled])",
  "input:not([disabled])",
  "select:not([disabled])",
  "textarea:not([disabled])",
  "[tabindex]:not([tabindex='-1'])"
].join(",")

export class MobileNavigation {
  constructor(documentRef = document, windowRef = window) {
    this.document = documentRef
    this.window = windowRef
    this.listeners = []
    this.opened = false

    this.handleClick = this.handleClick.bind(this)
    this.handleKeydown = this.handleKeydown.bind(this)
    this.handleBreakpointChange = this.handleBreakpointChange.bind(this)
    this.handlePageLoaded = this.handlePageLoaded.bind(this)
  }

  mount() {
    if (!this.resolveElements()) return false

    this.mobileQuery = this.window.matchMedia(MOBILE_NAVIGATION_QUERY)
    this.listen(this.document, "click", this.handleClick)
    this.listen(this.document, "keydown", this.handleKeydown)
    this.listen(this.mobileQuery, "change", this.handleBreakpointChange)
    if (this.window.addEventListener) {
      this.listen(this.window, "phx:page-loading-stop", this.handlePageLoaded)
    }
    this.syncResponsiveState()
    this.observeLiveViewPatches()

    return true
  }

  resolveElements() {
    const trigger = this.document.querySelector("[data-mobile-nav-trigger]")
    const drawer = this.document.querySelector("#mobile-navigation-drawer")
    const scrim = this.document.querySelector("[data-mobile-nav-scrim]")
    const background = this.document.querySelector("[data-mobile-nav-background]")
    const closeButton = this.document.querySelector("[data-mobile-nav-close]")

    if (!trigger || !drawer || !scrim || !background || !closeButton) return false

    Object.assign(this, {trigger, drawer, scrim, background, closeButton})
    return true
  }

  // Live navigation renders a fresh chrome, so the nodes mounted against are
  // detached afterwards. LiveView fires page-loading-stop once when the old
  // view is swapped out and again once the new one has rendered; rebind as
  // soon as the new nodes exist and put them in the closed state.
  handlePageLoaded() {
    if (this.drawer.isConnected !== false) return
    if (!this.resolveElements()) return

    if (this.observer) this.observer.disconnect()
    this.opened = false
    this.syncDomState()
    this.observeLiveViewPatches()
  }

  destroy() {
    for (const removeListener of this.listeners) removeListener()
    this.listeners = []
    if (this.observer) this.observer.disconnect()
    this.close({restoreFocus: false})
  }

  open() {
    if (!this.mobileQuery.matches || this.opened) return

    this.opened = true
    this.syncDomState()
    this.closeButton.focus()
  }

  close({restoreFocus = true} = {}) {
    const wasOpen = this.opened

    this.opened = false
    this.syncDomState()

    if (wasOpen && restoreFocus && this.mobileQuery.matches) this.trigger.focus()
  }

  syncResponsiveState() {
    if (this.mobileQuery.matches) {
      this.close({restoreFocus: false})
    } else {
      this.opened = false
      this.syncDomState()
    }
  }

  syncDomState() {
    if (this.opened) {
      this.setDatasetState("open")
      this.setAttribute(this.drawer, "inert", false)
      this.setAttribute(this.background, "inert", true)
      this.setAttribute(this.trigger, "aria-expanded", "true")
      this.document.body.classList.add("mobile-nav-open")
    } else {
      this.setDatasetState(this.mobileQuery.matches ? "closed" : "desktop")
      this.setAttribute(this.drawer, "inert", this.mobileQuery.matches)
      this.setAttribute(this.background, "inert", false)
      this.setAttribute(this.trigger, "aria-expanded", "false")
      this.document.body.classList.remove("mobile-nav-open")
    }
  }

  handleClick(event) {
    if (event.target.closest("[data-mobile-nav-trigger]")) {
      if (this.opened) {
        this.close()
      } else {
        this.open()
      }

      return
    }

    if (
      event.target.closest("[data-mobile-nav-close]") ||
      event.target.closest("[data-mobile-nav-scrim]")
    ) {
      this.close()
      return
    }

    if (this.opened && event.target.closest("#mobile-navigation-drawer a[href]")) {
      this.close({restoreFocus: false})
    }
  }

  handleKeydown(event) {
    if (!this.opened) return

    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
      return
    }

    if (event.key !== "Tab") return

    const focusable = this.focusableElements()
    if (focusable.length === 0) {
      event.preventDefault()
      this.drawer.focus()
      return
    }

    const first = focusable[0]
    const last = focusable[focusable.length - 1]
    const activeElement = this.document.activeElement

    if (event.shiftKey && (activeElement === first || !this.drawer.contains(activeElement))) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && (activeElement === last || !this.drawer.contains(activeElement))) {
      event.preventDefault()
      first.focus()
    }
  }

  handleBreakpointChange() {
    this.syncResponsiveState()
  }

  focusableElements() {
    return Array.from(this.drawer.querySelectorAll(FOCUSABLE_SELECTOR)).filter(element => {
      return !element.hasAttribute("hidden") && element.getClientRects().length > 0
    })
  }

  listen(target, eventName, handler) {
    target.addEventListener(eventName, handler)
    this.listeners.push(() => target.removeEventListener(eventName, handler))
  }

  observeLiveViewPatches() {
    if (!this.window.MutationObserver) return

    this.observer = new this.window.MutationObserver(() => this.syncDomState())

    for (const element of [this.trigger, this.drawer, this.background]) {
      this.observer.observe(element, {attributes: true})
    }
  }

  setDatasetState(state) {
    if (this.drawer.dataset.mobileNavState !== state) {
      this.drawer.dataset.mobileNavState = state
    }
  }

  setAttribute(element, name, value) {
    if (value === false) {
      if (element.hasAttribute(name)) element.removeAttribute(name)
    } else if (value === true) {
      if (!element.hasAttribute(name)) element.setAttribute(name, "")
    } else if (element.getAttribute(name) !== value) {
      element.setAttribute(name, value)
    }
  }
}

export function mountMobileNavigation(documentRef = document, windowRef = window) {
  const navigation = new MobileNavigation(documentRef, windowRef)
  return navigation.mount() ? navigation : null
}
