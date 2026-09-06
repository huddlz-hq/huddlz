import {mountImageFallbacks, preserveImageFallback} from "../../assets/js/image_fallback.mjs"

const validImage = "data:image/svg+xml," + encodeURIComponent(
  '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="9"><rect width="16" height="9" fill="teal"/></svg>'
)
const invalidImage = "data:image/png;base64,broken"
const results = document.querySelector("#results")
const checks = []

function cover(className, fallbackEnabled = true) {
  const frame = document.createElement("div")
  frame.style.cssText = "position:relative;width:240px;height:135px"
  const fallback = document.createElement("div")
  fallback.className = "group-cover-fallback"
  fallback.textContent = "huddlz group"
  const image = document.createElement("img")
  image.className = className
  image.alt = ""
  if (fallbackEnabled) image.setAttribute("data-image-fallback", "")
  frame.append(fallback, image)
  document.querySelector("#fixtures").append(frame)
  return image
}

function load(image, src) {
  return new Promise((resolve) => {
    image.onload = image.onerror = () => resolve()
    image.src = src
  })
}

function assert(condition, description) {
  if (!condition) throw new Error(description)
  checks.push(`PASS ${description}`)
  results.textContent = checks.join("\n")
}

function hidden(image) {
  return getComputedStyle(image).display === "none" && image.getClientRects().length === 0
}

try {
  const cachedFailure = cover("group-cover-image")
  await load(cachedFailure, invalidImage)
  const cachedSuccess = cover("hero-img")
  await load(cachedSuccess, validImage)
  mountImageFallbacks()
  assert(hidden(cachedFailure), "A cover that failed before initialization is hidden")
  assert(!hidden(cachedSuccess), "An already-loaded cover stays visible")

  for (const className of ["group-cover-image", "card-cover-img", "hero-img"]) {
    const image = cover(className)
    await load(image, invalidImage)
    assert(hidden(image), `${className}: a newly inserted failed image is hidden`)
    assert(getComputedStyle(image.previousElementSibling).display !== "none",
      `${className}: the fallback remains visible`)
    const serverImage = image.cloneNode()
    serverImage.removeAttribute("hidden")
    preserveImageFallback(image, serverImage)
    image.hidden = serverImage.hidden
    assert(hidden(image), `${className}: a DOM patch preserves the failed-image fallback`)
    await load(image, validImage)
    assert(!hidden(image) && image.naturalWidth > 0,
      `${className}: a successful replacement becomes visible`)
    await load(image, invalidImage)
    assert(hidden(image), `${className}: a failed replacement restores the fallback`)
  }

  const ordinaryImage = cover("card-cover-img", false)
  await load(ordinaryImage, invalidImage)
  assert(!ordinaryImage.hidden, "Images outside the fallback contract are untouched")
  for (const location of ["Long Location Avenue Building District ".repeat(12), "LongLocation".repeat(40)]) {
    const hero = document.createElement("div")
    hero.className = "hero group-hero"
    hero.style.width = "min(100%, 480px)"
    const media = document.createElement("div")
    media.className = "group-cover group-cover--hero"
    const content = document.createElement("div")
    content.className = "hero-content"
    const status = document.createElement("span")
    status.className = "eyebrow"
    status.textContent = "Group · Public"
    const title = document.createElement("h1")
    title.textContent = "Community ".repeat(10).trim()
    const meta = document.createElement("div")
    meta.className = "meta group-hero-meta"
    const place = document.createElement("span")
    place.className = "group-hero-location"
    place.textContent = location
    meta.append(place)
    content.append(status, title, meta)
    hero.append(media, content)
    document.querySelector("#fixtures").append(hero)
    const frame = hero.getBoundingClientRect()
    const text = content.getBoundingClientRect()
    assert(text.top >= frame.top && text.bottom <= frame.bottom,
      "Long group metadata stays inside the hero frame")
    assert(place.scrollWidth <= place.clientWidth,
      "Long locations wrap within the available width")
  }
  results.dataset.status = "passed"
} catch (error) {
  results.textContent = [...checks, `FAIL ${error.message}`].join("\n")
  results.dataset.status = "failed"
  throw error
}
