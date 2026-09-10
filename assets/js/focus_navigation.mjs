// Focus page context only after navigation, never while someone is typing or
// filtering the current page. Live redirects can finish before the new join.
export function mountFocusNavigation() {
  let previousMain = document.querySelector("#main-content")
  let previousPath = location.pathname
  let navigation = false
  let leavingDialog = false
  watchSubmissions()
  watchModalRemoval()

  document.addEventListener("input", () => { navigation = false })
  document.addEventListener("submit", () => { navigation = false }, true)

  document.addEventListener("click", event => {
    if (!event.target.closest(".skip-link")) return
    event.preventDefault()
    document.querySelector("#main-content")?.focus()
  })

  window.addEventListener("phx:page-loading-start", ({detail}) => {
    if (detail.kind === "redirect" ||
        (detail.kind === "patch" && new URL(detail.to, location.href).pathname !== previousPath)) {
      leavingDialog = !!visibleDialog()
      navigation = true
    }
  })
  window.addEventListener("phx:page-loading-stop", () => {
    requestAnimationFrame(() => {
      const main = document.querySelector("#main-content")
      if (!main || (main === previousMain && location.pathname === previousPath)) return
      previousPath = location.pathname
      previousMain = main
      if (!navigation) return
      navigation = false
      if (!leavingDialog && !visibleDialog()) focusPage(main)
    })
  })
}

function focusPage(main) {
  const heading = main.querySelector("h1")
  const target = heading || main
  target.setAttribute("tabindex", "-1")
  target.focus({preventScroll: true})
  const status = document.querySelector("#page-context")
  if (status) status.textContent = heading?.textContent.trim() || document.title
}

// LiveView locks submitted forms until their reply has patched the DOM. Watch
// that public loading class rather than guessing a timeout or reacting to validation.
function watchSubmissions() {
  document.addEventListener("submit", event => {
    const form = event.target
    if (!form.matches("form[phx-submit]")) return
    form.querySelector(".error-summary")?.remove()
    const previousInfo = document.querySelector("#flash-info")?.textContent
    const observer = new MutationObserver(records => {
      const completed = records.some(record =>
        record.target === form && record.attributeName === "class" &&
        record.oldValue?.includes("phx-submit-loading"))
      if (!form.isConnected) {
        observer.disconnect()
        restoreLostFocus()
      } else if (completed && !form.classList.contains("phx-submit-loading")) {
        observer.disconnect()
        requestAnimationFrame(() => submissionFinished(form, previousInfo))
      }
    })
    observer.observe(document.body, {subtree: true, childList: true, attributes: true, attributeFilter: ["class"], attributeOldValue: true})
  }, true)

  document.addEventListener("input", event => {
    event.target.closest("form")?.querySelector(".error-summary")?.remove()
  })
  document.addEventListener("click", event => {
    const link = event.target.closest(".error-summary a")
    if (!link) return
    const field = document.getElementById(link.hash.slice(1))
    if (!field) return
    event.preventDefault()
    field.focus()
  })
}

function submissionFinished(form, previousInfo) {
  if (!form.isConnected || form.hasAttribute("phx-trigger-action")) return
  const dialog = visibleDialog()
  if (dialog && !dialog.contains(form)) return
  const fields = [...form.querySelectorAll('[aria-invalid="true"]')]
    .filter(field => field.id && !field.disabled && field.getClientRects().length)
  if (fields.length) {
    const summary = document.createElement("section")
    summary.className = "error-summary"
    summary.tabIndex = -1
    summary.setAttribute("aria-label", "Please correct the following errors")
    const title = document.createElement("h2")
    title.textContent = "Please correct the following errors"
    const list = document.createElement("ul")
    for (const field of fields) {
      const label = field.labels?.[0]?.textContent.trim() || field.getAttribute("aria-label") || "Field"
      const errors = (field.getAttribute("aria-describedby") || "").split(/\s+/)
        .map(id => document.getElementById(id))
        .filter(element => element?.classList.contains("form-error"))
        .map(element => element.textContent.trim())
      const item = document.createElement("li")
      const link = document.createElement("a")
      link.href = `#${field.id}`
      link.textContent = `${label}: ${errors.join("; ") || "Check this field"}`
      item.append(link)
      list.append(item)
    }
    summary.append(title, list)
    form.prepend(summary)
    summary.focus()
    return
  }
  const error = document.querySelector("#flash-error")
  const info = document.querySelector("#flash-info")?.textContent
  const newSuccess = info && info !== previousInfo
  if (error && !newSuccess) {
    error.tabIndex = -1
    error.focus({preventScroll: true})
    return
  }
  const heading = form.querySelector("h2")
  if (heading) {
    heading.tabIndex = -1
    heading.focus({preventScroll: true})
  }
}

function visibleDialog() {
  return [...document.querySelectorAll('[role="dialog"]')]
    .find(dialog => dialog.getClientRects().length && getComputedStyle(dialog).visibility !== "hidden")
}

// A successful destructive action may remove the button that opened a dialog.
// Let its normal restoration finish first; only recover focus left on the body.
function watchModalRemoval() {
  new MutationObserver(records => {
    const removedDialog = records.some(record => [...record.removedNodes].some(node =>
      node.nodeType === Node.ELEMENT_NODE &&
      (node.matches("[data-cc-modal]") || node.querySelector("[data-cc-modal]"))))
    if (!removedDialog) return
    restoreLostFocus()
  }).observe(document.body, {childList: true, subtree: true})
}

function restoreLostFocus() {
  requestAnimationFrame(() => {
    if (document.activeElement === document.body && !visibleDialog()) {
      document.querySelector("#main-content")?.focus({preventScroll: true})
    }
  })
}
