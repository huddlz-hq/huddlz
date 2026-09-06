import assert from "node:assert/strict"
import test from "node:test"
import {mountImageFallbacks, preserveImageFallback} from "./image_fallback.mjs"

function setup(images = []) {
  const handlers = new Map()
  mountImageFallbacks({
    querySelectorAll: () => images,
    addEventListener(name, handler, capture) {
      assert.equal(capture, true, "Image load/error notifications do not bubble")
      handlers.set(name, handler)
    }
  })
  return (name, target) => handlers.get(name)({target})
}

function image({complete = false, naturalWidth = 0, hidden = false} = {}) {
  return {complete, naturalWidth, hidden, matches: selector => selector === "img[data-image-fallback]"}
}

test("initialization hides only completed failures", () => {
  const failed = image({complete: true})
  const loaded = image({complete: true, naturalWidth: 16, hidden: true})
  const pending = image()
  setup([failed, loaded, pending])
  assert.equal(failed.hidden, true)
  assert.equal(loaded.hidden, false)
  assert.equal(pending.hidden, false)
})

test("images added later recover from failure and hide on a subsequent failure", () => {
  const dispatch = setup()
  const cover = image()
  dispatch("error", cover)
  assert.equal(cover.hidden, true)
  dispatch("load", cover)
  assert.equal(cover.hidden, false)
  dispatch("error", cover)
  assert.equal(cover.hidden, true)
})

test("unrelated images and window errors remain untouched", () => {
  const dispatch = setup()
  const ordinaryImage = {hidden: false, matches: () => false}
  dispatch("error", ordinaryImage)
  assert.equal(ordinaryImage.hidden, false)
  assert.doesNotThrow(() => dispatch("error", {}))
})

test("LiveView patches retain the failed cover state", () => {
  const failed = image({hidden: true})
  const replacement = image()
  preserveImageFallback(failed, replacement)
  assert.equal(replacement.hidden, true)

  const loaded = image({complete: true, naturalWidth: 16})
  const untouched = image()
  preserveImageFallback(loaded, untouched)
  assert.equal(untouched.hidden, false)
})
