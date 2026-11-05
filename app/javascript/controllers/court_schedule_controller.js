import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "players", "unplaced", "unplacedItem", "allPlaced"]
  static values = { noLineup: String }

  connect() {
    this.refresh()
  }

  refresh() {
    const chosen = new Set(this.selectTargets.map((select) => select.value).filter(Boolean))

    this.selectTargets.forEach((select, index) => {
      Array.from(select.options).forEach((option) => {
        option.disabled = option.value !== "" && option.value !== select.value && chosen.has(option.value)
      })
      this.playersTargets[index].textContent = this.playersFor(select)
    })

    this.unplacedItemTargets.forEach((item) => {
      item.hidden = chosen.has(item.dataset.line)
    })
    const remaining = this.unplacedItemTargets.some((item) => !item.hidden)
    this.unplacedTarget.hidden = !remaining
    this.allPlacedTarget.hidden = remaining
  }

  playersFor(select) {
    if (!select.value) return ""

    return select.selectedOptions[0].dataset.players || this.noLineupValue
  }
}
