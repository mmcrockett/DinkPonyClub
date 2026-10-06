import { Controller } from "@hotwired/stimulus"

const ROTATION = [[0, 1], [0, 2], [1, 2]]
const DEBOUNCE_MS = 600
const WINNING_SCORE = 11

export default class extends Controller {
  static targets = ["score", "row", "player", "fingerprint", "status"]
  static values = { url: String }

  connect() {
    this.dirty = false
    this.saving = false
    this.stopped = false
    this.rowTargets.forEach((row) => this.highlight(row))
    this.beforeUnload = (event) => {
      if (this.dirty) event.preventDefault()
    }
    window.addEventListener("beforeunload", this.beforeUnload)
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.beforeUnload)
    clearTimeout(this.timer)
  }

  scoreChanged(event) {
    const input = event.target
    input.value = input.value.replace(/\D/g, "")
    this.highlight(input.closest("[data-line]"))
    if (input.value.length >= 2) this.focusNext(input)
    this.queueSave()
  }

  scoreKeydown(event) {
    if (event.key !== "Enter") return
    const next = this.scoreTargets[this.scoreTargets.indexOf(event.target) + 1]
    if (!next) return
    event.preventDefault()
    next.focus()
  }

  playersChanged(event) {
    this.relabel(event.target.dataset.line)
    this.queueSave()
  }

  focusNext(input) {
    const next = this.scoreTargets[this.scoreTargets.indexOf(input) + 1]
    if (next) next.focus()
  }

  rowScores(row) {
    return Array.from(row.querySelectorAll("[data-scorecard-target='score']")).map((input) => input.value)
  }

  highlight(row) {
    const inputs = Array.from(row.querySelectorAll("[data-scorecard-target='score']"))
    const [home, away] = inputs.map((input) => input.value)
    inputs.forEach((input) => input.classList.remove("font-extrabold", "ring-2", "ring-red-500"))
    if (home === "" || away === "") return
    if (Number(home) === Number(away)) {
      inputs.forEach((input) => input.classList.add("ring-2", "ring-red-500"))
    } else {
      const winner = inputs[Number(home) > Number(away) ? 0 : 1]
      if (Number(winner.value) >= WINNING_SCORE) winner.classList.add("font-extrabold")
    }
  }

  relabel(line) {
    const names = { home: this.names(line, "home"), away: this.names(line, "away") }
    this.rowTargets.filter((row) => row.dataset.line === line).forEach((row) => {
      const game = Number(row.dataset.game) - 1
      row.querySelectorAll("[data-pair]").forEach((cell) => {
        cell.textContent = this.pair(names[cell.dataset.pair], game)
      })
    })
  }

  names(line, side) {
    return this.playerTargets
      .filter((select) => select.dataset.line === line && select.dataset.side === side)
      .map((select) => (select.value ? select.selectedOptions[0].dataset.short : null))
      .filter(Boolean)
  }

  pair(names, game) {
    if (names.length === 2) return names.join(" & ")
    return ROTATION[game].map((index) => names[index]).filter(Boolean).join(" & ")
  }

  halfFilledRow() {
    return this.rowTargets.find((row) => {
      const filled = this.rowScores(row).filter((value) => value !== "").length
      return filled === 1
    })
  }

  queueSave() {
    if (this.stopped) return
    this.dirty = true
    clearTimeout(this.timer)
    const half = this.halfFilledRow()
    if (half) {
      this.status(`Not saved - finish Line ${half.dataset.line} Game ${half.dataset.game}`, true)
      return
    }
    this.status("Saving...")
    this.timer = setTimeout(() => this.save(), DEBOUNCE_MS)
  }

  async save() {
    if (this.saving) {
      this.again = true
      return
    }
    this.saving = true
    this.again = false
    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        body: new FormData(this.element),
        headers: { Accept: "application/json" }
      })
      await this.handle(response)
    } catch (error) {
      this.status("Not saved: network error", true)
    } finally {
      this.saving = false
      if (this.again && !this.stopped) this.queueSave()
    }
  }

  async handle(response) {
    const data = await response.json()
    if (response.ok) {
      this.fingerprintTarget.value = data.fingerprint
      this.dirty = this.again === true
      const time = new Date(data.saved_at).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })
      this.status(`Saved ${time}`)
    } else if (response.status === 409) {
      this.stopped = true
      this.dirty = false
      this.status(`${data.errors.join(" ")} `, true, true)
    } else {
      this.status(`Not saved: ${data.errors.join(", ")}`, true)
    }
  }

  status(message, error = false, reload = false) {
    const bar = this.statusTarget
    bar.textContent = message
    bar.classList.toggle("text-red-700", error)
    bar.classList.toggle("text-gray-600", !error)
    if (!reload) return
    const button = document.createElement("button")
    button.type = "button"
    button.className = "ml-2 underline"
    button.textContent = "Reload"
    button.addEventListener("click", () => window.location.reload())
    bar.append(button)
  }
}
