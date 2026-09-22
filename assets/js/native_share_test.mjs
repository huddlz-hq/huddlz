import assert from "node:assert/strict"
import test from "node:test"

import {createNativeShareHook, sharePayload} from "./native_share.mjs"

function button(dataset) {
  const listeners = {}
  return {
    hidden: true,
    dataset,
    addEventListener: (name, fn) => (listeners[name] = fn),
    removeEventListener: name => delete listeners[name],
    click: () => listeners.click?.()
  }
}

function mount(hook, el) {
  const instance = Object.create(hook)
  instance.el = el
  instance.mounted()
  return instance
}

test("stays hidden where the browser has no share sheet", () => {
  const el = button({title: "Hack night", url: "https://huddlz.com/h/1"})
  mount(createNativeShareHook({navigatorRef: {}}), el)
  assert.equal(el.hidden, true)
})

test("shows and opens the sheet with the title, words and link", async () => {
  const shared = []
  const navigatorRef = {share: payload => (shared.push(payload), Promise.resolve())}
  const el = button({
    title: "Hack night",
    text: "Hack night · Thu, Sep 24, 2026 · 6:00 PM CDT",
    url: "https://huddlz.com/h/1"
  })

  mount(createNativeShareHook({navigatorRef}), el)
  assert.equal(el.hidden, false)

  el.click()
  assert.deepEqual(shared, [
    {
      title: "Hack night",
      text: "Hack night · Thu, Sep 24, 2026 · 6:00 PM CDT",
      url: "https://huddlz.com/h/1"
    }
  ])
})

test("a dismissed sheet is not an error", async () => {
  const navigatorRef = {share: () => Promise.reject(new DOMException("dismissed", "AbortError"))}
  const el = button({title: "Hack night", url: "https://huddlz.com/h/1"})
  mount(createNativeShareHook({navigatorRef}), el)
  assert.doesNotThrow(() => el.click())
})

test("leaves out words that only repeat the title", () => {
  assert.deepEqual(sharePayload({title: "Saturday Cyclists", text: "Saturday Cyclists", url: "u"}), {
    title: "Saturday Cyclists",
    url: "u"
  })
})
