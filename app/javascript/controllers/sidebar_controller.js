import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "backdrop", "button"]

  connect() {
    this.close()
  }

  toggle() {
    if (this.panelTarget.classList.contains("invisible")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.cancelPendingHide()

    this.panelTarget.classList.remove("invisible", "-translate-x-full")
    this.backdropTarget.classList.remove("invisible", "opacity-0")
    this.backdropTarget.classList.add("opacity-100")
    this.buttonTarget.setAttribute("aria-expanded", "true")

    const firstLink = this.panelTarget.querySelector("a, button")
    firstLink?.focus()
  }

  close() {
    this.cancelPendingHide()

    this.panelTarget.classList.add("-translate-x-full")
    this.backdropTarget.classList.add("opacity-0")
    this.buttonTarget.setAttribute("aria-expanded", "false")

    this.hideTimeout = setTimeout(() => {
      this.panelTarget.classList.add("invisible")
      this.backdropTarget.classList.add("invisible")
    }, 200)
  }

  cancelPendingHide() {
    clearTimeout(this.hideTimeout)
  }
}
