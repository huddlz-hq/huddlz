// Shows the "Share…" button only where the browser has a share sheet, and
// hands it the page's title, words and link. The sheet covers whatever is
// installed (Messages, Instagram, Slack), so nothing per platform lives here.
// A dismissed sheet is not an error.

// The share payload for a button carrying data-title, data-text and data-url.
export function sharePayload({title, text, url}) {
  const payload = {}
  if (title) payload.title = title
  if (text && text !== title) payload.text = text
  if (url) payload.url = url
  return payload
}

export function createNativeShareHook({navigatorRef = navigator} = {}) {
  return {
    mounted() {
      if (typeof navigatorRef.share !== "function") return

      this.el.hidden = false
      this.onClick = () => {
        navigatorRef.share(sharePayload(this.el.dataset)).catch(() => {})
      }
      this.el.addEventListener("click", this.onClick)
    },

    destroyed() {
      if (this.onClick) this.el.removeEventListener("click", this.onClick)
    }
  }
}
