import assert from "node:assert/strict"
import test from "node:test"

import {mountPageLoading} from "./page_loading.mjs"

function setup() {
  const listeners = new Map()
  const windowRef = {
    addEventListener: (name, handler) => listeners.set(name, handler),
    removeEventListener: name => listeners.delete(name)
  }

  const region = {stale: false, classList: {toggle(name, force) { region.stale = force }}}
  const documentRef = {querySelectorAll: () => [region]}

  const calls = []
  const topbar = {
    config: options => calls.push(["config", options]),
    show: delay => calls.push(["show", delay]),
    hide: () => calls.push(["hide"])
  }

  const unmount = mountPageLoading({topbar, windowRef, documentRef, accentColor: () => "#123456"})
  const fire = (name, kind) => listeners.get(name)({detail: {kind}})

  return {fire, calls, region, listeners, unmount}
}

test("shows the accent progress bar on every page load and hides it after", () => {
  const {fire, calls} = setup()

  fire("phx:page-loading-start", "redirect")
  assert.deepEqual(calls[0], ["config", {barColors: {0: "#123456"}, barThickness: 2, shadowBlur: 0, shadowColor: "transparent"}])
  assert.deepEqual(calls[1], ["show", 300])

  fire("phx:page-loading-stop", "redirect")
  assert.deepEqual(calls[2], ["hide"])
})

test("marks stale regions only for patches and clears them when the patch lands", () => {
  const {fire, region} = setup()

  fire("phx:page-loading-start", "redirect")
  assert.equal(region.stale, false)

  fire("phx:page-loading-start", "patch")
  assert.equal(region.stale, true)

  fire("phx:page-loading-stop", "patch")
  assert.equal(region.stale, false)
})

test("unmounting removes both listeners", () => {
  const {listeners, unmount} = setup()

  unmount()

  assert.equal(listeners.size, 0)
})
