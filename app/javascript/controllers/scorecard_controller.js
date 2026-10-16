import { Controller } from "@hotwired/stimulus"

const ROTATION = [[0, 1], [0, 2], [1, 2]]
const DEBOUNCE_MS = 600
const WINNING_SCORE = 11

export default class extends Controller {
  static targets = ["score", "row", "player", "fingerprint", "status", "summary", "editor", "scores"]
  static values = { url: String, doneUrl: String, persisted: Boolean }

  connect() {
    this.dirty = false
    this.saved = this.persistedValue
    this.lastSaveFailed = false
    this.fullSave = false
    this.dirtyRows = new Set()
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
    const row = input.closest("[data-line]")
    this.highlight(row)
    this.dirtyRows.add(row)
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

  editLineup() {
    this.summaryTarget.hidden = true
    this.editorTarget.hidden = false
  }

  async setLineup() {
    if (!this.lineupReady()) {
      this.status("Every line needs at least two players per team", true)
      return
    }
    await this.settled()
    if (!this.clean()) {
      this.fullSave = true
      await this.save()
    }
    if (this.dirty) return
    this.renderSummary()
    this.editorTarget.hidden = true
    this.summaryTarget.hidden = false
    this.scoresTarget.hidden = false
  }

  addThirdPlayer(event) {
    const button = event.currentTarget
    const select = button.parentElement.querySelector("select[hidden]")
    select.hidden = false
    select.focus()
    button.remove()
  }

  lineupReady() {
    const lines = new Set(this.playerTargets.map((select) => select.dataset.line))
    return Array.from(lines).every((line) => ["home", "away"].every((side) => this.names(line, side).length >= 2))
  }

  renderSummary() {
    this.summaryTarget.querySelectorAll("[data-summary-line]").forEach((item) => {
      const line = item.dataset.summaryLine
      item.querySelectorAll("[data-summary-side]").forEach((cell) => {
        cell.textContent = this.names(line, cell.dataset.summarySide).join(" & ")
      })
    })
  }

  playersChanged(event) {
    this.relabel(event.target.dataset.line)
    this.fullSave = true
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
    if (!this.saved) this.fullSave = true
    clearTimeout(this.timer)
    if (!this.lineupReady()) {
      this.status("Not saved - every line needs at least two players per team", true)
      return
    }
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
    this.inFlight = this.request()
    await this.inFlight
  }

  async finish(event) {
    event.preventDefault()
    if (this.submitting) return
    this.submitting = true
    await this.settled()
    if (this.clean()) {
      window.Turbo.visit(this.doneUrlValue)
      return
    }
    this.dirty = false
    this.element.submit()
  }

  clean() {
    return this.saved && !this.dirty && !this.lastSaveFailed
  }

  async settled() {
    clearTimeout(this.timer)
    if (this.inFlight) await this.inFlight
    clearTimeout(this.timer)
  }

  rowData(row) {
    const data = new FormData()
    const [home, away] = this.rowScores(row)
    data.append("game[home_score]", home)
    data.append("game[away_score]", away)
    this.playerTargets
      .filter((select) => select.dataset.line === row.dataset.line && select.value)
      .forEach((select) => data.append(`game[${select.dataset.side}_player_ids][]`, select.value))
    return data
  }

  async patch(url, body) {
    return fetch(url, {
      method: "PATCH",
      body,
      headers: { Accept: "application/json", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content ?? "" }
    })
  }

  async request() {
    try {
      const full = this.fullSave
      const rows = Array.from(this.dirtyRows)
      this.fullSave = false
      this.dirtyRows.clear()
      if (full) {
        await this.handle(await this.patch(this.urlValue, new FormData(this.element)), true)
      } else {
        for (const row of rows) await this.handle(await this.patch(row.dataset.url, this.rowData(row)), false)
      }
    } catch (error) {
      this.lastSaveFailed = true
      this.status("Not saved: network error", true)
    } finally {
      this.saving = false
      if (this.again && !this.stopped) this.queueSave()
    }
  }

  async handle(response, full) {
    const data = await response.json().catch(() => ({}))
    const errors = data.errors || [`server error (${response.status})`]
    if (!response.ok) this.lastSaveFailed = true
    if (response.ok && full) this.lastSaveFailed = false
    if (response.ok) {
      this.saved = true
      this.fingerprintTarget.value = data.fingerprint
      this.dirty = this.again === true
      const time = new Date(data.saved_at).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })
      this.status(`Saved ${time}`)
    } else if (response.status === 409) {
      this.stopped = true
      this.dirty = false
      this.status(`${errors.join(" ")} `, true, true)
    } else {
      this.status(`Not saved: ${errors.join(", ")}`, true)
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
