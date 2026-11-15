import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["file", "submit"]

  connect() {
    this.update()
  }

  update() {
    this.submitTarget.hidden = this.fileTarget.files.length === 0
  }
}
