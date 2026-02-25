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

Hooks.LocationAutocomplete = {
  mounted() {
    this.highlightIndex = -1
    this.setupInput()
  },

  updated() {
    this.syncHighlightFromDOM()
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
    this._input = this.el.querySelector("input[role='combobox']")
    if (!this._input) return

    if (this._handler) {
      this._input.removeEventListener("keydown", this._handler)
    }

    this._handler = (e) => this.handleKeydown(e)
    this._input.addEventListener("keydown", this._handler)
  },

  handleKeydown(e) {
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault()
      e.stopPropagation()

      const listbox = this.el.querySelector("[role='listbox']")
      if (!listbox) return

      const options = listbox.querySelectorAll("[role='option']")
      if (options.length === 0) return

      this.moveHighlight(e.key === "ArrowDown" ? 1 : -1, options)
      this.pushEventTo(this.el, "keydown", {key: e.key})
    } else if (e.key === "Enter") {
      const listbox = this.el.querySelector("[role='listbox']")
      if (listbox && this.highlightIndex >= 0) {
        e.preventDefault()
        e.stopPropagation()

        const options = listbox.querySelectorAll("[role='option']")
        const highlighted = options[this.highlightIndex]
        if (highlighted) {
          this.pushEventTo(this.el, "select", {
            "place-id": highlighted.dataset.placeId,
            "display-text": highlighted.dataset.displayText
          })
        }
      }
    } else if (e.key === "Escape") {
      e.stopPropagation()
      this.pushEventTo(this.el, "keydown", {key: "Escape"})
    }
  },

  moveHighlight(direction, options) {
    const maxIdx = options.length - 1
    const newIdx = direction > 0
      ? Math.min(this.highlightIndex + 1, maxIdx)
      : Math.max(this.highlightIndex - 1, -1)

    if (this.highlightIndex >= 0 && this.highlightIndex < options.length) {
      options[this.highlightIndex].classList.remove("bg-primary/20", "border-l-primary")
      options[this.highlightIndex].classList.add("border-l-transparent")
    }

    if (newIdx >= 0 && newIdx < options.length) {
      options[newIdx].classList.add("bg-primary/20", "border-l-primary")
      options[newIdx].classList.remove("border-l-transparent")
    }

    this.highlightIndex = newIdx
  },

  syncHighlightFromDOM() {
    const listbox = this.el.querySelector("[role='listbox']")
    if (!listbox) {
      this.highlightIndex = -1
      return
    }

    const options = listbox.querySelectorAll("[role='option']")
    this.highlightIndex = -1
    options.forEach((opt, idx) => {
      if (opt.classList.contains("border-l-primary") &&
          !opt.matches(":hover")) {
        this.highlightIndex = idx
      }
    })
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

// connect if there are any LiveViews on the page
liveSocket.connect()

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
