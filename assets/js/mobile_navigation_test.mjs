import assert from "node:assert/strict"
import test from "node:test"

import {MobileNavigation} from "./mobile_navigation.mjs"

class FakeClassList {
  constructor() {
    this.values = new Set()
  }

  add(value) {
    this.values.add(value)
  }

  remove(value) {
    this.values.delete(value)
  }

  contains(value) {
    return this.values.has(value)
  }
}

class FakeElement {
  constructor(documentRef) {
    this.document = documentRef
    this.attributes = new Map()
    this.classList = new FakeClassList()
    this.dataset = {}
    this.focusable = []
    this.closestMatches = new Set()
  }

  setAttribute(name, value) {
    this.attributes.set(name, value)
  }

  removeAttribute(name) {
    this.attributes.delete(name)
  }

  hasAttribute(name) {
    return this.attributes.has(name)
  }

  getAttribute(name) {
    return this.attributes.get(name) ?? null
  }

  focus() {
    this.document.activeElement = this
  }

  contains(element) {
    return element === this || this.focusable.includes(element)
  }

  querySelectorAll() {
    return this.focusable
  }

  getClientRects() {
    return [{}]
  }

  closest(selector) {
    return this.closestMatches.has(selector) ? this : null
  }
}

class FakeEventTarget {
  constructor() {
    this.listeners = new Map()
  }

  addEventListener(name, handler) {
    this.listeners.set(name, handler)
  }

  removeEventListener(name) {
    this.listeners.delete(name)
  }
}

function setup({mobile = true} = {}) {
  const documentRef = new FakeEventTarget()
  documentRef.body = new FakeElement(documentRef)
  documentRef.activeElement = null

  const trigger = new FakeElement(documentRef)
  const drawer = new FakeElement(documentRef)
  const scrim = new FakeElement(documentRef)
  const background = new FakeElement(documentRef)
  const closeButton = new FakeElement(documentRef)
  const brandLink = new FakeElement(documentRef)
  const firstLink = new FakeElement(documentRef)
  const lastLink = new FakeElement(documentRef)
  drawer.focusable = [brandLink, closeButton, firstLink, lastLink]

  trigger.closestMatches.add("[data-mobile-nav-trigger]")
  scrim.closestMatches.add("[data-mobile-nav-scrim]")
  closeButton.closestMatches.add("[data-mobile-nav-close]")
  firstLink.closestMatches.add("#mobile-navigation-drawer a[href]")

  const elements = new Map([
    ["[data-mobile-nav-trigger]", trigger],
    ["#mobile-navigation-drawer", drawer],
    ["[data-mobile-nav-scrim]", scrim],
    ["[data-mobile-nav-background]", background],
    ["[data-mobile-nav-close]", closeButton]
  ])
  documentRef.querySelector = selector => elements.get(selector)

  const mediaQuery = new FakeEventTarget()
  mediaQuery.matches = mobile
  const windowRef = {matchMedia: () => mediaQuery}

  const navigation = new MobileNavigation(documentRef, windowRef)
  assert.equal(navigation.mount(), true)

  return {
    navigation,
    documentRef,
    mediaQuery,
    trigger,
    drawer,
    scrim,
    background,
    closeButton,
    brandLink,
    firstLink,
    lastLink
  }
}

function keyEvent(key, {shiftKey = false} = {}) {
  return {
    key,
    shiftKey,
    defaultPrevented: false,
    preventDefault() {
      this.defaultPrevented = true
    }
  }
}

test("opens with focus in the drawer and makes the background inert", () => {
  const {navigation, documentRef, trigger, drawer, background, closeButton} = setup()

  assert.equal(drawer.hasAttribute("inert"), true)
  navigation.open()

  assert.equal(drawer.dataset.mobileNavState, "open")
  assert.equal(drawer.hasAttribute("inert"), false)
  assert.equal(background.hasAttribute("inert"), true)
  assert.equal(trigger.attributes.get("aria-expanded"), "true")
  assert.equal(documentRef.activeElement, closeButton)
})

test("Escape closes the drawer and restores focus to the hamburger", () => {
  const {navigation, documentRef, trigger, drawer, background} = setup()
  navigation.open()
  const event = keyEvent("Escape")

  navigation.handleKeydown(event)

  assert.equal(event.defaultPrevented, true)
  assert.equal(drawer.dataset.mobileNavState, "closed")
  assert.equal(background.hasAttribute("inert"), false)
  assert.equal(trigger.attributes.get("aria-expanded"), "false")
  assert.equal(documentRef.activeElement, trigger)
})

test("Tab and Shift+Tab wrap within the drawer", () => {
  const {navigation, documentRef, brandLink, lastLink} = setup()
  navigation.open()

  documentRef.activeElement = lastLink
  const tab = keyEvent("Tab")
  navigation.handleKeydown(tab)
  assert.equal(tab.defaultPrevented, true)
  assert.equal(documentRef.activeElement, brandLink)

  documentRef.activeElement = brandLink
  const shiftTab = keyEvent("Tab", {shiftKey: true})
  navigation.handleKeydown(shiftTab)
  assert.equal(shiftTab.defaultPrevented, true)
  assert.equal(documentRef.activeElement, lastLink)
})

test("the trigger, close control, and backdrop all update drawer state", () => {
  const {navigation, documentRef, trigger, scrim, closeButton} = setup()

  navigation.handleClick({target: trigger})
  assert.equal(navigation.opened, true)
  assert.equal(documentRef.activeElement, closeButton)

  navigation.handleClick({target: closeButton})
  assert.equal(navigation.opened, false)
  assert.equal(documentRef.activeElement, trigger)

  navigation.handleClick({target: trigger})
  navigation.handleClick({target: scrim})
  assert.equal(navigation.opened, false)
  assert.equal(documentRef.activeElement, trigger)
})

test("following a drawer link closes without stealing navigation focus", () => {
  const {navigation, documentRef, firstLink, closeButton} = setup()
  navigation.open()
  firstLink.focus()

  navigation.handleClick({target: firstLink})

  assert.equal(navigation.opened, false)
  assert.equal(documentRef.activeElement, firstLink)
  assert.notEqual(documentRef.activeElement, closeButton)
})

test("switching to desktop removes drawer and background restrictions", () => {
  const {navigation, mediaQuery, drawer, background, trigger} = setup()
  navigation.open()

  mediaQuery.matches = false
  navigation.handleBreakpointChange()

  assert.equal(drawer.dataset.mobileNavState, "desktop")
  assert.equal(drawer.hasAttribute("inert"), false)
  assert.equal(background.hasAttribute("inert"), false)
  assert.equal(trigger.attributes.get("aria-expanded"), "false")
})
