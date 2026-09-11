import assert from "node:assert/strict"
import test from "node:test"

import {placeMenu} from "./popover_menu.mjs"

const viewport = {width: 1000, height: 800}
const menu = {width: 232, height: 130}

test("opens below the trigger, right-aligned to it", () => {
  const trigger = {top: 300, bottom: 336, right: 900}
  assert.deepEqual(placeMenu({trigger, menu, viewport}), {top: 342, left: 668})
})

test("flips above the trigger when there is no room below", () => {
  const trigger = {top: 720, bottom: 756, right: 900}
  assert.deepEqual(placeMenu({trigger, menu, viewport}), {top: 584, left: 668})
})

test("stays inside a narrow viewport", () => {
  const trigger = {top: 100, bottom: 136, right: 200}
  const phone = {width: 320, height: 720}
  assert.deepEqual(placeMenu({trigger, menu, viewport: phone}), {top: 142, left: 8})
})
