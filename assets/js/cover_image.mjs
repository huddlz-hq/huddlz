// Reveals a `.cover-image` once its picture has decoded.
//
// The element paints its picture as a CSS background, so a missing or failed
// file leaves the surrounding fallback visible with no client-side state.
// This hook only layers a loading surface on top while the picture is still
// arriving, and only after a short delay so cached pictures never flash it.
export const PENDING_DELAY_MS = 150

export function createCoverImageHook({
  ImageCtor = globalThis.Image,
  setTimeoutFn = globalThis.setTimeout,
  clearTimeoutFn = globalThis.clearTimeout
} = {}) {
  return {
    mounted() {
      this.watch()
    },

    updated() {
      if (this.url !== this.el.dataset.coverUrl) this.watch()
    },

    destroyed() {
      this.release()
    },

    watch() {
      this.release()
      this.url = this.el.dataset.coverUrl
      this.el.classList.remove("is-pending")
      delete this.el.dataset.coverState
      if (!this.url) return

      const probe = new ImageCtor()
      this.probe = probe
      probe.onload = () => this.settle("loaded")
      probe.onerror = () => this.settle("failed")
      probe.src = this.url

      this.timer = setTimeoutFn(() => this.el.classList.add("is-pending"), PENDING_DELAY_MS)
    },

    settle(state) {
      this.release()
      this.el.classList.remove("is-pending")
      this.el.dataset.coverState = state
    },

    release() {
      if (this.timer) clearTimeoutFn(this.timer)
      this.timer = null

      if (this.probe) {
        this.probe.onload = null
        this.probe.onerror = null
        this.probe = null
      }
    }
  }
}
