import assert from "node:assert/strict"
import test from "node:test"

import {
  MAX_ZOOM,
  centredView,
  cropRect,
  fitScale,
  layout,
  outputName,
  outputSize,
  pan,
  zoomAt
} from "./cover_crop.mjs"

const tall = {width: 600, height: 1200}
const wide = {width: 1600, height: 900}
const window = {width: 640, height: 360}

test("a tall picture fits by width and a wide one by height", () => {
  assert.equal(fitScale(tall, window), 640 / 600)
  assert.equal(fitScale(wide, window), 360 / 900)
})

test("the centred view is the crop the server would make on its own", () => {
  const crop = cropRect(tall, window, centredView(tall))
  assert.equal(crop.sx, 0)
  assert.equal(crop.sw, 600)
  assert.ok(Math.abs(crop.sh - 337.5) < 0.01)
  assert.ok(Math.abs(crop.sy - (1200 - 337.5) / 2) < 0.01)
})

test("a picture that already matches the window is not cropped at all", () => {
  const crop = cropRect(wide, window, centredView(wide))
  assert.deepEqual(crop, {sx: 0, sy: 0, sw: 1600, sh: 900})
})

test("panning stops at the picture's edges", () => {
  const view = pan(tall, window, centredView(tall), 0, -5000)
  const placed = layout(tall, window, view)
  assert.ok(Math.abs(placed.y + placed.height - window.height) < 0.01)
  const crop = cropRect(tall, window, view)
  assert.ok(Math.abs(crop.sy + crop.sh - 1200) < 0.01)
})

test("zooming keeps the point under the pointer still and stays within limits", () => {
  const start = centredView(tall)
  const before = layout(tall, window, start)
  const px = 100
  const py = 200
  const under = {x: (px - before.x) / before.scale, y: (py - before.y) / before.scale}

  const zoomed = zoomAt(tall, window, start, 2, px, py)
  const after = layout(tall, window, zoomed)
  assert.equal(zoomed.zoom, 2)
  assert.ok(Math.abs(after.x + under.x * after.scale - px) < 0.01)
  assert.ok(Math.abs(after.y + under.y * after.scale - py) < 0.01)

  assert.equal(zoomAt(tall, window, start, 9, px, py).zoom, MAX_ZOOM)
  assert.equal(zoomAt(tall, window, start, 0.2, px, py).zoom, 1)
})

test("the output keeps the window's aspect and never upscales", () => {
  assert.deepEqual(outputSize({sw: 600, sh: 337.5}, 1920, 16 / 9), {width: 600, height: 338})
  assert.deepEqual(outputSize({sw: 4032, sh: 2268}, 1920, 16 / 9), {width: 1920, height: 1080})
  assert.deepEqual(outputSize({sw: 3000, sh: 3000}, 800, 1), {width: 800, height: 800})
})

test("the cropped file is a JPEG named after the original", () => {
  assert.equal(outputName("lighthouse.png"), "lighthouse.jpg")
  assert.equal(outputName("me.HEIC"), "me.jpg")
  assert.equal(outputName(".jpg"), "picture.jpg")
  assert.equal(outputName(undefined), "picture.jpg")
})
