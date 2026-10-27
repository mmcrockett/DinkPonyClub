import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.schedule = () => {
      cancelAnimationFrame(this.frame)
      this.frame = requestAnimationFrame(() => this.align())
    }
    this.observer = new MutationObserver(this.schedule)
    this.observer.observe(this.element, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ["hidden"] })
    window.addEventListener("resize", this.schedule)
    document.fonts?.ready.then(this.schedule)
    this.schedule()
  }

  disconnect() {
    this.observer.disconnect()
    window.removeEventListener("resize", this.schedule)
    cancelAnimationFrame(this.frame)
  }

  align() {
    const groups = {}
    this.element.querySelectorAll("[data-line-group]").forEach((group) => {
      this.visibleRows(group).forEach((row) => (row.style.height = ""))
      ;(groups[group.dataset.lineGroup] ||= []).push(group)
    })
    Object.values(groups).forEach((sides) => {
      const tallest = Math.max(...sides.map((side) => side.getBoundingClientRect().height))
      sides.forEach((side) => this.stretch(side, tallest))
    })
  }

  stretch(group, height) {
    const gap = height - group.getBoundingClientRect().height
    const last = this.visibleRows(group).at(-1)
    if (gap > 0.5 && last) last.style.height = `${last.getBoundingClientRect().height + gap}px`
  }

  visibleRows(group) {
    return Array.from(group.rows).filter((row) => !row.hidden)
  }
}
