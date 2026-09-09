// Page-level loading feedback driven by LiveView's page-loading events.
//
// Every navigation and submit shows the progress bar in the accent colour.
// A patch additionally marks `[data-stale-on-patch]` regions stale; the
// stylesheet delays the dim so a patch that finishes quickly never dims.
export function mountPageLoading({
  topbar,
  windowRef = globalThis.window,
  documentRef = globalThis.document,
  accentColor = () => readAccent(documentRef)
}) {
  const start = event => {
    topbar.config({barColors: {0: accentColor()}, barThickness: 2, shadowBlur: 0, shadowColor: "transparent"})
    topbar.show(300)
    if (event.detail && event.detail.kind === "patch") setStale(documentRef, true)
  }

  const stop = () => {
    topbar.hide()
    setStale(documentRef, false)
  }

  windowRef.addEventListener("phx:page-loading-start", start)
  windowRef.addEventListener("phx:page-loading-stop", stop)

  return () => {
    windowRef.removeEventListener("phx:page-loading-start", start)
    windowRef.removeEventListener("phx:page-loading-stop", stop)
  }
}

function setStale(documentRef, stale) {
  for (const element of documentRef.querySelectorAll("[data-stale-on-patch]")) {
    element.classList.toggle("is-stale", stale)
  }
}

function readAccent(documentRef) {
  const value = getComputedStyle(documentRef.documentElement).getPropertyValue("--accent").trim()
  return value || "#18cbd4"
}
