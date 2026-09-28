import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "status", "slots"]

  connect() {
    if (this.hasToggleTarget) this.applyState()
  }

  toggled() {
    this.applyState()
  }

  submit() {
    this.element.requestSubmit()
  }

  applyState() {
    const playing = this.toggleTarget.checked

    this.toggleTarget.setAttribute("aria-checked", playing)
    this.statusTarget.textContent = playing ? "In" : "Out"
    this.slotsTarget.classList.toggle("opacity-40", !playing)
    this.slotsTarget.classList.toggle("pointer-events-none", !playing)

    this.slotsTarget.querySelectorAll("input[type=radio]").forEach((radio) => {
      radio.disabled = !playing
    })
  }
}
