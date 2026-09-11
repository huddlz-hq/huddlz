// Places a native popover menu beside the button that opened it.
//
// Popovers render in the top layer, so without CSS anchor positioning a
// stylesheet cannot pin one to its trigger. This hook does the same
// arithmetic on `beforetoggle`, measuring in the next animation frame so
// the menu is placed before its first paint. The browser still owns
// opening, light dismiss, Escape and focus return.
const GAP = 6
const EDGE = 8

// Where a menu of `menu` size goes for a `trigger` rectangle inside
// `viewport`: below the trigger and right-aligned to it, flipped above when
// there is no room below, never past the viewport's edges.
export function placeMenu({trigger, menu, viewport}) {
  const rightAligned = trigger.right - menu.width
  const left = Math.max(EDGE, Math.min(rightAligned, viewport.width - menu.width - EDGE))

  const below = trigger.bottom + GAP
  const fitsBelow = below + menu.height <= viewport.height - EDGE
  const top = fitsBelow ? below : Math.max(EDGE, trigger.top - GAP - menu.height)

  return {top, left}
}

export function createPopoverMenuHook({windowRef = window, requestFrame = requestAnimationFrame} = {}) {
  return {
    mounted() {
      this.onBeforeToggle = event => {
        if (event.newState === "open") requestFrame(() => this.place())
      }
      this.onViewportChange = () => {
        if (this.el.matches(":popover-open")) this.el.hidePopover()
      }

      this.el.addEventListener("beforetoggle", this.onBeforeToggle)
      windowRef.addEventListener("scroll", this.onViewportChange, {capture: true, passive: true})
      windowRef.addEventListener("resize", this.onViewportChange)
    },

    destroyed() {
      this.el.removeEventListener("beforetoggle", this.onBeforeToggle)
      windowRef.removeEventListener("scroll", this.onViewportChange, {capture: true})
      windowRef.removeEventListener("resize", this.onViewportChange)
    },

    place() {
      const trigger = document.querySelector(`[popovertarget="${this.el.id}"]`)
      if (!trigger) return

      const {top, left} = placeMenu({
        trigger: trigger.getBoundingClientRect(),
        menu: {width: this.el.offsetWidth, height: this.el.offsetHeight},
        viewport: {width: windowRef.innerWidth, height: windowRef.innerHeight}
      })

      this.el.style.top = `${top}px`
      this.el.style.left = `${left}px`
    }
  }
}
