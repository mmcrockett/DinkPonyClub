import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["file", "submit"]

  connect() {
    this.submitTarget.hidden = true
  }

  upload() {
    if (this.fileTarget.files.length > 0) this.element.requestSubmit()
  }
}
