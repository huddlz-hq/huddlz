// Crop on upload.
//
// A picture chosen for a cover (16:9) or an avatar (square) opens the crop
// sheet before any bytes move. The picture starts fit and centred in the
// window, which is exactly the crop the server would make on its own, so
// "Use photo" is one click in the common case. Drag moves it, the wheel, a
// pinch or the slider zoom it, and "Use photo" draws the window onto a
// canvas and hands the JPEG to the LiveView upload named by the element.
// The server pipeline is untouched; the original file is not kept.
//
// The hook element carries `data-upload-name`, `data-shape` (wide | square)
// and `data-output-width`, and contains the `live_file_input` of that
// upload, an optional drop area (`[data-crop-drop]`) and the
// `<dialog class="crop-sheet">`. A file the person picks in that input is
// taken before LiveView sees it (LiveView listens on `window`, so stopping
// the trusted change event here is enough); the crop goes back in through
// `this.upload`, whose own events are synthetic and pass straight through.

export const MIN_ZOOM = 1
export const MAX_ZOOM = 3
export const JPEG_QUALITY = 0.9

const clamp = (value, low, high) => Math.min(Math.max(value, low), high)

// The scale at which the picture just covers the window.
export function fitScale(picture, window) {
  return Math.max(window.width / picture.width, window.height / picture.height)
}

export function clampZoom(zoom) {
  return clamp(zoom, MIN_ZOOM, MAX_ZOOM)
}

// Where the picture sits for a view (zoom and the picture point at the
// window's centre), keeping the window covered. Returns the offset of the
// picture's top-left from the window's top-left, the scale, and the view
// as it ended up after clamping.
export function layout(picture, window, view) {
  const scale = fitScale(picture, window) * clampZoom(view.zoom)
  const width = picture.width * scale
  const height = picture.height * scale
  const x = clamp(window.width / 2 - view.cx * scale, window.width - width, 0)
  const y = clamp(window.height / 2 - view.cy * scale, window.height - height, 0)

  return {
    x,
    y,
    width,
    height,
    scale,
    view: {
      zoom: clampZoom(view.zoom),
      cx: (window.width / 2 - x) / scale,
      cy: (window.height / 2 - y) / scale
    }
  }
}

export function centredView(picture) {
  return {zoom: 1, cx: picture.width / 2, cy: picture.height / 2}
}

// Move the picture by a screen distance.
export function pan(picture, window, view, dx, dy) {
  const {scale} = layout(picture, window, view)
  return layout(picture, window, {...view, cx: view.cx - dx / scale, cy: view.cy - dy / scale}).view
}

// Zoom so the picture point under the window point (px, py) stays put.
export function zoomAt(picture, window, view, zoom, px, py) {
  const before = layout(picture, window, view)
  const after = fitScale(picture, window) * clampZoom(zoom)
  const ix = (px - before.x) / before.scale
  const iy = (py - before.y) / before.scale
  const x = px - ix * after
  const y = py - iy * after

  return layout(picture, window, {
    zoom,
    cx: (window.width / 2 - x) / after,
    cy: (window.height / 2 - y) / after
  }).view
}

// The part of the picture inside the window, in picture pixels.
export function cropRect(picture, window, view) {
  const {x, y, scale} = layout(picture, window, view)
  return {
    sx: -x / scale + 0,
    sy: -y / scale + 0,
    sw: window.width / scale,
    sh: window.height / scale
  }
}

// The output never upscales, and keeps the window's exact aspect.
export function outputSize(crop, maxWidth, aspect) {
  const width = Math.max(1, Math.round(Math.min(crop.sw, maxWidth)))
  return {width, height: Math.max(1, Math.round(width / aspect))}
}

export function outputName(name) {
  const base = (name || "picture").replace(/\.[^.]+$/, "")
  return `${base || "picture"}.jpg`
}

export function createCoverCropHook({
  createObjectURL = blob => URL.createObjectURL(blob),
  revokeObjectURL = url => URL.revokeObjectURL(url)
} = {}) {
  return {
    mounted() {
      this.name = this.el.dataset.uploadName
      this.shape = this.el.dataset.shape || "wide"
      this.aspect = this.shape === "square" ? 1 : 16 / 9
      this.maxWidth = parseInt(this.el.dataset.outputWidth || "1920", 10)

      this.dialog = this.el.querySelector("dialog.crop-sheet")
      this.pic = this.dialog.querySelector(".crop-pic")
      this.stage = this.dialog.querySelector("[data-crop-stage]")
      this.window = this.dialog.querySelector(".crop-window")
      this.range = this.dialog.querySelector("[data-crop-zoom]")
      this.zoomValue = this.dialog.querySelector("[data-crop-zoom-value]")
      this.resetButton = this.dialog.querySelector("[data-crop-reset]")
      this.meta = this.dialog.querySelector("[data-crop-meta]")
      this.pointers = new Map()

      for (const type of ["input", "change"]) {
        this.el.addEventListener(type, e => {
          if (!e.isTrusted || !e.target.matches("input[type=file][data-phx-upload-ref]")) return
          e.stopPropagation()
          if (type !== "change") return
          const file = e.target.files && e.target.files[0]
          e.target.value = ""
          if (file) this.open(file)
        })
      }

      this.el.addEventListener("dragover", e => {
        const zone = e.target.closest && e.target.closest("[data-crop-drop]")
        if (!zone) return
        e.preventDefault()
        zone.classList.add("is-dragover")
      })
      this.el.addEventListener("dragleave", e => {
        const zone = e.target.closest && e.target.closest("[data-crop-drop]")
        if (zone && !zone.contains(e.relatedTarget)) zone.classList.remove("is-dragover")
      })
      this.el.addEventListener("drop", e => {
        const zone = e.target.closest && e.target.closest("[data-crop-drop]")
        if (!zone) return
        e.preventDefault()
        zone.classList.remove("is-dragover")
        const file = e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files[0]
        if (file) this.open(file)
      })

      this.dialog.addEventListener("close", () => this.release())
      this.dialog.querySelectorAll("[data-crop-cancel], [data-crop-close]").forEach(button => {
        button.addEventListener("click", () => this.dialog.close())
      })
      this.dialog.querySelector("[data-crop-use]").addEventListener("click", () => this.use())
      this.resetButton.addEventListener("click", () => this.setView(centredView(this.picture)))
      this.range.addEventListener("input", () => {
        const {width, height} = this.windowSize()
        this.setView(zoomAt(this.picture, this.windowSize(), this.view, parseFloat(this.range.value), width / 2, height / 2))
      })

      this.stage.addEventListener("pointerdown", e => this.pointerDown(e))
      this.stage.addEventListener("pointermove", e => this.pointerMove(e))
      this.stage.addEventListener("pointerup", e => this.pointerUp(e))
      this.stage.addEventListener("pointercancel", e => this.pointerUp(e))
      this.stage.addEventListener("wheel", e => this.wheel(e), {passive: false})
      this.stage.addEventListener("keydown", e => this.keydown(e))
      this.pic.addEventListener("load", () => this.loaded())
      this.pic.addEventListener("error", () => this.unreadable())
      this.onResize = () => this.dialog.open && this.render()
      window.addEventListener("resize", this.onResize)
    },

    destroyed() {
      window.removeEventListener("resize", this.onResize)
      this.release()
    },

    open(file) {
      if (!/^image\//.test(file.type)) {
        // Let the upload rules refuse it with their own message.
        this.upload(this.name, [file])
        return
      }

      this.release()
      this.file = file
      this.url = createObjectURL(file)
      this.pic.src = this.url
    },

    loaded() {
      if (!this.file) return
      this.picture = {width: this.pic.naturalWidth, height: this.pic.naturalHeight}
      this.meta.textContent = `${this.file.name} · ${this.picture.width} × ${this.picture.height}`
      if (!this.dialog.open) this.dialog.showModal()
      this.sizeStage()
      this.setView(centredView(this.picture))
    },

    unreadable() {
      const file = this.file
      this.release()
      if (file) this.upload(this.name, [file])
    },

    release() {
      if (this.url) revokeObjectURL(this.url)
      this.url = null
      this.file = null
      this.picture = null
      this.pointers.clear()
      this.pic.removeAttribute("src")
      this.stage.classList.remove("is-dragging")
    },

    // The stage is as tall as the fitted picture needs, within limits, so a
    // landscape picture gets no dimmed band; phones size it by CSS instead.
    sizeStage() {
      const wide = window.matchMedia("(min-width: 761px)").matches
      if (!wide) {
        this.stage.style.removeProperty("--crop-stage-h")
        return
      }
      const stageWidth = this.stage.getBoundingClientRect().width
      const windowWidth = this.shape === "square" ? Math.min(288, stageWidth) : stageWidth
      const windowHeight = windowWidth / this.aspect
      const fitted = this.picture.height * fitScale(this.picture, {width: windowWidth, height: windowHeight})
      const height = clamp(fitted + 32, windowHeight, 480)
      this.stage.style.setProperty("--crop-stage-h", `${Math.round(height)}px`)
    },

    windowSize() {
      const rect = this.window.getBoundingClientRect()
      return {width: rect.width, height: rect.height}
    },

    setView(view) {
      this.view = layout(this.picture, this.windowSize(), view).view
      this.render()
    },

    render() {
      if (!this.picture) return
      const size = this.windowSize()
      const placed = layout(this.picture, size, this.view)
      this.view = placed.view
      const stage = this.stage.getBoundingClientRect()
      const win = this.window.getBoundingClientRect()
      this.pic.style.width = `${placed.width}px`
      this.pic.style.height = `${placed.height}px`
      this.pic.style.transform = `translate3d(${win.left - stage.left + placed.x}px, ${win.top - stage.top + placed.y}px, 0)`
      this.range.value = String(this.view.zoom)
      this.zoomValue.textContent = `${this.view.zoom.toFixed(1)}×`
      const centred = centredView(this.picture)
      const moved =
        Math.abs(this.view.zoom - 1) > 0.001 ||
        Math.abs(this.view.cx - centred.cx) > 0.5 ||
        Math.abs(this.view.cy - centred.cy) > 0.5
      this.resetButton.hidden = !moved
    },

    pointerDown(e) {
      if (!this.picture) return
      this.stage.setPointerCapture(e.pointerId)
      this.pointers.set(e.pointerId, {x: e.clientX, y: e.clientY})
      this.stage.classList.add("is-dragging")
      e.preventDefault()
    },

    pointerMove(e) {
      const previous = this.pointers.get(e.pointerId)
      if (!previous) return
      const size = this.windowSize()

      if (this.pointers.size === 2) {
        const [a, b] = [...this.pointers.values()]
        const other = a === previous ? b : a
        const before = Math.hypot(a.x - b.x, a.y - b.y)
        const after = Math.hypot(e.clientX - other.x, e.clientY - other.y)
        const win = this.window.getBoundingClientRect()
        const midX = (e.clientX + other.x) / 2 - win.left
        const midY = (e.clientY + other.y) / 2 - win.top
        if (before > 0) {
          this.view = zoomAt(this.picture, size, this.view, this.view.zoom * (after / before), midX, midY)
        }
      } else {
        this.view = pan(this.picture, size, this.view, e.clientX - previous.x, e.clientY - previous.y)
      }

      this.pointers.set(e.pointerId, {x: e.clientX, y: e.clientY})
      this.render()
    },

    pointerUp(e) {
      this.pointers.delete(e.pointerId)
      if (this.stage.hasPointerCapture && this.stage.hasPointerCapture(e.pointerId)) {
        this.stage.releasePointerCapture(e.pointerId)
      }
      if (this.pointers.size === 0) this.stage.classList.remove("is-dragging")
    },

    wheel(e) {
      if (!this.picture) return
      e.preventDefault()
      const win = this.window.getBoundingClientRect()
      const factor = Math.exp(-e.deltaY * 0.002)
      this.setView(zoomAt(this.picture, this.windowSize(), this.view, this.view.zoom * factor, e.clientX - win.left, e.clientY - win.top))
    },

    keydown(e) {
      if (!this.picture) return
      const step = e.shiftKey ? 40 : 10
      const moves = {ArrowLeft: [step, 0], ArrowRight: [-step, 0], ArrowUp: [0, step], ArrowDown: [0, -step]}
      if (moves[e.key]) {
        e.preventDefault()
        const [dx, dy] = moves[e.key]
        this.setView(pan(this.picture, this.windowSize(), this.view, dx, dy))
      } else if (e.key === "+" || e.key === "=" || e.key === "-") {
        e.preventDefault()
        const {width, height} = this.windowSize()
        const zoom = this.view.zoom * (e.key === "-" ? 1 / 1.1 : 1.1)
        this.setView(zoomAt(this.picture, this.windowSize(), this.view, zoom, width / 2, height / 2))
      }
    },

    use() {
      if (!this.picture) return
      const crop = cropRect(this.picture, this.windowSize(), this.view)
      const {width, height} = outputSize(crop, this.maxWidth, this.aspect)
      const canvas = document.createElement("canvas")
      canvas.width = width
      canvas.height = height
      const context = canvas.getContext("2d")
      context.fillStyle = "#fff"
      context.fillRect(0, 0, width, height)
      context.drawImage(this.pic, crop.sx, crop.sy, crop.sw, crop.sh, 0, 0, width, height)
      const name = outputName(this.file.name)

      canvas.toBlob(blob => {
        if (!blob) return
        const cropped = new File([blob], name, {type: "image/jpeg", lastModified: Date.now()})
        this.dialog.close()
        this.upload(this.name, [cropped])
      }, "image/jpeg", JPEG_QUALITY)
    }
  }
}
