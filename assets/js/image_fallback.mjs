const selector = "img[data-image-fallback]"

export function mountImageFallbacks(documentRef = document) {
  const targetImage = ({target}) => target.matches?.(selector) ? target : null

  documentRef.addEventListener("error", (event) => {
    const image = targetImage(event)
    if (image) image.hidden = true
  }, true)

  documentRef.addEventListener("load", (event) => {
    const image = targetImage(event)
    if (image) image.hidden = false
  }, true)

  documentRef.querySelectorAll(selector).forEach((image) => {
    image.hidden = image.complete && image.naturalWidth === 0
  })
}

// LiveView patches otherwise remove the client-owned hidden attribute.
export function preserveImageFallback(fromElement, toElement) {
  if (fromElement.matches(selector) && fromElement.hidden) {
    toElement.hidden = true
  }
}
