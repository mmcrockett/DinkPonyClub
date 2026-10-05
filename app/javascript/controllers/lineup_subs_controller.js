import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["picker", "button", "seat", "list", "item"]

  open() {
    this.pickerTarget.hidden = false
    this.pickerTarget.focus()
  }

  add() {
    const option = this.pickerTarget.selectedOptions[0]
    if (!option || !option.value) return

    this.seatTargets.forEach((select) => select.add(new Option(option.text, option.value)))
    this.listTarget.append(this.buildItem(option.text))

    option.remove()
    this.pickerTarget.value = ""
    this.pickerTarget.hidden = true
    if (this.pickerTarget.options.length <= 1) this.buttonTarget.hidden = true
  }

  buildItem(name) {
    const item = this.itemTarget.content.firstElementChild.cloneNode(true)
    item.querySelector("[data-name]").textContent = name
    return item
  }
}
