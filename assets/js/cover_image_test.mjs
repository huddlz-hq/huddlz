import assert from "node:assert/strict"
import test from "node:test"

import {PENDING_DELAY_MS, createCoverImageHook} from "./cover_image.mjs"

function setup(url = "/uploads/cover.jpg") {
  const probes = []
  const timers = []

  class FakeImage {
    constructor() {
      probes.push(this)
    }
  }

  const hook = createCoverImageHook({
    ImageCtor: FakeImage,
    setTimeoutFn: (callback, delay) => {
      const timer = {callback, delay, cleared: false}
      timers.push(timer)
      return timer
    },
    clearTimeoutFn: timer => {
      timer.cleared = true
    }
  })

  const classes = new Set()
  hook.el = {
    dataset: {coverUrl: url},
    classList: {
      add: value => classes.add(value),
      remove: (...values) => values.forEach(value => classes.delete(value)),
      contains: value => classes.has(value)
    }
  }

  hook.mounted()

  return {hook, probes, timers, classes}
}

test("probes the picture and marks the element once it decodes", () => {
  const {hook, probes, timers, classes} = setup()

  assert.equal(probes.length, 1)
  assert.equal(probes[0].src, "/uploads/cover.jpg")
  assert.equal(classes.has("is-pending"), false)

  probes[0].onload()

  assert.equal(hook.el.dataset.coverState, "loaded")
  assert.equal(classes.has("is-pending"), false)
  assert.equal(timers[0].cleared, true)
})

test("shows the pending surface only after the delay, then clears it", () => {
  const {hook, probes, timers, classes} = setup()

  assert.equal(timers[0].delay, PENDING_DELAY_MS)
  timers[0].callback()
  assert.equal(classes.has("is-pending"), true)

  probes[0].onload()

  assert.equal(classes.has("is-pending"), false)
  assert.equal(hook.el.dataset.coverState, "loaded")
})

test("a picture that fails to load leaves the fallback visible", () => {
  const {hook, probes, timers, classes} = setup()
  timers[0].callback()

  probes[0].onerror()

  assert.equal(classes.has("is-pending"), false)
  assert.equal(hook.el.dataset.coverState, "failed")
})

test("a new picture URL starts over", () => {
  const {hook, probes, classes} = setup()
  probes[0].onload()

  hook.el.dataset.coverUrl = "/uploads/next.jpg"
  hook.updated()

  assert.equal(probes.length, 2)
  assert.equal(probes[1].src, "/uploads/next.jpg")
  assert.equal(hook.el.dataset.coverState, undefined)
  assert.equal(classes.has("is-pending"), false)
})

test("an unchanged update keeps the settled state", () => {
  const {hook, probes} = setup()
  probes[0].onload()

  hook.updated()

  assert.equal(probes.length, 1)
  assert.equal(hook.el.dataset.coverState, "loaded")
})

test("destroying the hook stops listening to the probe", () => {
  const {hook, probes, timers} = setup()
  const probe = probes[0]

  hook.destroyed()

  assert.equal(timers[0].cleared, true)
  assert.equal(probe.onload, null)
  assert.equal(probe.onerror, null)
})
