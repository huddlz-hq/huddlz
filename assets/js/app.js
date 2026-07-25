// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

const Hooks = {}

const focusWithoutScrolling = (element) => {
  if (!element) return

  try {
    element.focus({preventScroll: true})
  } catch (_error) {
    element.focus()
  }
}

Hooks.FocusManagement = {
  mounted() {
    this.submittedForm = null
    this.submittedFormId = null
    this.handleSubmit = (event) => {
      this.submittedForm = event.target
      this.submittedFormId = event.target.id || null
    }

    this.el.addEventListener("submit", this.handleSubmit, true)
  },

  updated() {
    if (!this.submittedForm) return

    const submittedForm =
      (this.submittedFormId && document.getElementById(this.submittedFormId)) ||
      (this.submittedForm.isConnected && this.submittedForm)

    const focusTarget =
      submittedForm?.querySelector("[data-error-summary]") ||
      submittedForm?.querySelector("[aria-invalid='true']") ||
      this.el.querySelector("[role='alert']:not([hidden])")

    if (focusTarget) {
      window.requestAnimationFrame(() => focusTarget.focus())
      this.submittedForm = null
      this.submittedFormId = null
    }
  },

  destroyed() {
    this.el.removeEventListener("submit", this.handleSubmit, true)
  }
}

Hooks.LocationAutocomplete = {
  mounted() {
    this.setupInput()
  },

  updated() {
    if (!this._input || !this.el.contains(this._input)) {
      this.setupInput()
    }
  },

  destroyed() {
    if (this._input && this._handler) {
      this._input.removeEventListener("keydown", this._handler)
    }
  },

  setupInput() {
    if (this._input && this._handler) {
      this._input.removeEventListener("keydown", this._handler)
    }

    this._input = this.el.querySelector("input[role='combobox']")
    if (!this._input) return

    this._handler = (e) => this.handleKeydown(e)
    this._input.addEventListener("keydown", this._handler)
  },

  handleKeydown(e) {
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault()
    } else if (e.key === "Enter" && this.el.dataset.hasHighlight === "true") {
      e.preventDefault()
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

let liveNavigationPending = false

window.addEventListener("phx:page-loading-start", ({detail}) => {
  if (detail?.kind === "redirect") {
    liveNavigationPending = true
  }
})

window.addEventListener("phx:page-loading-stop", () => {
  if (!liveNavigationPending) return

  liveNavigationPending = false
  window.requestAnimationFrame(() => {
    const main = document.getElementById("main-content")
    focusWithoutScrolling(main)

    const announcer = document.getElementById("page-change-announcer")
    const heading = main?.querySelector("h1")
    if (announcer) announcer.textContent = heading?.textContent?.trim() || document.title
  })
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// "/" focuses the chrome search box, GitHub-style. Skipped while the user
// is already typing in an editable field, or when modifier keys are held.
document.addEventListener("keydown", (event) => {
  if (event.key !== "/" || event.metaKey || event.ctrlKey || event.altKey) return

  const target = event.target
  if (target && target.matches && target.matches('input, textarea, select, [contenteditable="true"], [contenteditable=""]')) return

  const inputs = document.querySelectorAll('input[type="search"][name="q"]')
  for (const input of inputs) {
    // offsetParent is null for inputs hidden via display: none — pick the
    // visible one (desktop chrome on >= md, mobile chrome below).
    if (input.offsetParent !== null) {
      event.preventDefault()
      input.focus()
      input.select()
      return
    }
  }
})

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
