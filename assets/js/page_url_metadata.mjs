// The root layout renders initial HTTP metadata, but LiveView navigation only
// replaces the live layout. Keep its URL metadata in sync with the current view.
function syncURL(selector, tag, identity, attribute, value) {
  const elements = [...document.head.querySelectorAll(selector)]
  const element = elements.shift()
  elements.forEach(duplicate => duplicate.remove())

  if (!value) {
    element?.remove()
    return
  }

  const target = element || document.createElement(tag)
  target.setAttribute(...identity)
  target.setAttribute(attribute, value)
  if (!element) document.head.appendChild(target)
}

function syncPageURLs() {
  syncURL('link[rel="canonical"]', "link", ["rel", "canonical"], "href", this.el.dataset.canonicalUrl)
  syncURL('meta[property="og:url"]', "meta", ["property", "og:url"], "content", this.el.dataset.ogUrl)
}

export const PageURLMetadata = {
  mounted: syncPageURLs,
  updated: syncPageURLs
}
