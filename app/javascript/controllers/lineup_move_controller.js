import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["seat", "save", "subSources", "subPanel", "subList"]
  static values = {
    empty: String, move: String, cancel: String,
    subsUrl: String, oddsUrl: String, here: String, extraHere: String, loading: String, noSubs: String, failed: String
  }

  move(event) {
    const row = event.currentTarget.closest("tr")
    this.clearSource()
    this.source = this.source === row ? null : row
    if (this.source) this.source.dataset.source = ""
    this.refresh()
  }

  here(event) {
    const target = event.currentTarget.closest("tr")
    if (this.source && this.source !== target) this.swap(this.source, target)
    this.clearSource()
    this.source = null
    this.refresh()
    this.saveTarget.disabled = false
  }

  async openSubs() {
    this.subPanelTarget.showModal()
    if (!this.subsLoaded) await this.loadSubs()
    this.renderSubList()
  }

  closeSubs(event) {
    if (event.target === this.subPanelTarget || event.target.closest("[data-close]")) this.subPanelTarget.close()
  }

  async loadSubs() {
    this.subListTarget.replaceChildren(this.listNote(this.loadingValue))
    try {
      const response = await fetch(this.subsUrlValue, { headers: { Accept: "text/html" } })
      if (!response.ok) throw new Error(response.status)
      this.subSourcesTarget.insertAdjacentHTML("beforeend", await response.text())
      this.subsLoaded = true
    } catch {
      this.subListTarget.replaceChildren(this.listNote(this.failedValue))
    }
  }

  renderSubList() {
    if (!this.subsLoaded) return

    const onPage = new Set(this.seatTargets.map((row) => row.dataset.playerId))
    const items = [...this.element.querySelectorAll("tr[data-sub-source]")]
      .filter((row) => !onPage.has(row.dataset.subId))
      .map((row) => this.subItem(row))
    this.subListTarget.replaceChildren(...(items.length ? items : [this.listNote(this.noSubsValue)]))
  }

  subItem(source) {
    const item = document.createElement("li")
    item.className = "mb-2 last:mb-0"
    const button = document.createElement("button")
    button.type = "button"
    button.className = "grid w-full grid-cols-[1fr_4rem_4rem] items-center rounded-md border border-gray-300 bg-white px-3 py-3 text-left text-sm hover:bg-gray-50"
    button.dataset.subId = source.dataset.subId
    button.dataset.action = "lineup-move#addSub"
    const text = (slot) => source.querySelector(`[data-slot=${slot}]`).textContent.trim()
    const cells = [source.querySelector("[data-slot=name] span").textContent.trim(), text("pupr"), text("elo")]
    cells.forEach((value, index) => {
      const cell = document.createElement("span")
      cell.className = index === 0 ? "font-bold text-dpc-navy" : "text-right text-gray-600"
      cell.textContent = value
      button.append(cell)
    })
    item.append(button)
    return item
  }

  listNote(text) {
    const item = document.createElement("li")
    item.className = "px-2 py-3 text-sm text-gray-500"
    item.textContent = text
    return item
  }

  addSub(event) {
    const anchor = this.seatTargets.find((row) => "benchNew" in row.dataset)
    const row = anchor.cloneNode(true)
    delete row.dataset.benchNew
    this.write(row, this.subPayload(event.currentTarget.dataset.subId))
    anchor.after(row)
    this.subPanelTarget.close()
    this.refresh()
  }

  remove(event) {
    const row = event.currentTarget.closest("tr")
    if (row.dataset.position) {
      this.write(row, this.emptyPayload())
      this.saveTarget.disabled = false
    } else {
      row.remove()
    }
    this.refresh()
  }

  subPayload(id) {
    const source = this.element.querySelector(`tr[data-sub-source][data-sub-id="${id}"]`)
    return { ...this.read(source), id }
  }

  swap(source, target) {
    if ("benchNew" in target.dataset) {
      const fresh = target.cloneNode(true)
      this.write(target, this.read(source))
      delete target.dataset.benchNew
      target.dataset.position = ""
      target.before(fresh)
      this.write(source, this.emptyPayload())
    } else {
      const [a, b] = [this.read(source), this.read(target)]
      this.write(source, b)
      this.write(target, a)
    }
    this.dropEmptyBenchRows()
  }

  read(row) {
    const cell = (slot) => row.querySelector(`[data-slot=${slot}]`).innerHTML
    return { id: row.dataset.playerId, name: cell("name"), pupr: cell("pupr"), elo: cell("elo") }
  }

  write(row, payload) {
    row.dataset.playerId = payload.id
    row.querySelector("[data-slot=name]").innerHTML = payload.name
    row.querySelector("[data-slot=pupr]").innerHTML = payload.pupr
    row.querySelector("[data-slot=elo]").innerHTML = payload.elo
  }

  emptyPayload() {
    return { id: "", name: this.emptyValue, pupr: "-", elo: "-" }
  }

  dropEmptyBenchRows() {
    this.seatTargets
      .filter((row) => row.dataset.position === "" && !row.dataset.playerId && !("benchNew" in row.dataset))
      .forEach((row) => row.remove())
  }

  clearSource() {
    if (this.source) delete this.source.dataset.source
  }

  refresh() {
    this.seatTargets.forEach((row) => this.refreshRow(row))
    this.element.querySelectorAll("input[data-field]").forEach((field) => {
      const id = field.closest("tr").dataset.playerId
      field.value = id
      field.disabled = !id
    })
    this.refreshStates()
    this.refreshAverages()
    this.refreshOdds()
  }

  refreshAverages() {
    const mean = (rows, slot, digits) => {
      const numbers = rows.map((row) => parseFloat(row.querySelector(`[data-slot=${slot}]`).textContent)).filter((n) => !isNaN(n))
      return numbers.length ? (numbers.reduce((a, b) => a + b, 0) / numbers.length).toFixed(digits) : "-"
    }
    const filled = this.seatTargets.filter((row) => row.dataset.position && row.dataset.playerId)
    const pupr = document.querySelector("[data-score=pupr]")
    const elo = document.querySelector("[data-score=elo]")
    if (pupr) pupr.textContent = mean(filled, "pupr", 2)
    if (elo) elo.textContent = mean(filled, "elo", 0)
  }

  refreshOdds() {
    clearTimeout(this.oddsTimer)
    this.oddsTimer = setTimeout(() => this.loadOdds(), 300)
  }

  async loadOdds() {
    const params = new URLSearchParams()
    this.element.querySelectorAll("input[data-field]:not(:disabled)").forEach((field) => params.append(field.name, field.value))
    try {
      const response = await fetch(`${this.oddsUrlValue}?${params}`, { headers: { Accept: "application/json" } })
      if (!response.ok) return
      const odds = await response.json()
      document.querySelector("[data-odds=mine]").textContent = odds.mine || "-"
      document.querySelector("[data-odds=theirs]").textContent = odds.theirs || "-"
      document.querySelectorAll("[data-line-odds]").forEach((pill) => {
        const line = (odds.lines || {})[pill.dataset.position] || {}
        pill.textContent = line[pill.dataset.lineOdds] || "-"
      })
    } catch {
      // keep the previous odds on a failed request
    }
  }

  refreshStates() {
    const filled = {}
    this.seatTargets.forEach((row) => {
      const position = row.dataset.position
      if (position && row.dataset.playerId) filled[position] = (filled[position] || 0) + 1
    })
    this.seatTargets.forEach((row) => {
      const position = row.dataset.position
      row.dataset.state = !position ? "bench" : (filled[position] || 0) >= 2 ? "complete" : "incomplete"
    })
  }

  extraOpen(row) {
    if (!this.source) return false

    const filled = this.seatTargets.filter(
      (seat) => seat.dataset.position === row.dataset.position && seat.dataset.playerId && seat !== this.source
    )
    return filled.length >= 2
  }

  refreshRow(row) {
    const isSource = row === this.source
    if ("extra" in row.dataset) row.hidden = !row.dataset.playerId && !this.extraOpen(row)
    const benchToBench = this.source && this.source.dataset.position === "" && row.dataset.position === ""
    const moveButton = row.querySelector("[data-role=move]")
    moveButton.hidden = !row.dataset.playerId || (this.source && !isSource)
    moveButton.textContent = isSource ? this.cancelValue : this.moveValue
    row.querySelectorAll("[data-role=remove]").forEach((button) => (button.hidden = !!this.source))
    const hereButton = row.querySelector("[data-role=here]")
    hereButton.hidden = !this.source || isSource || benchToBench
    const addsExtra = "extra" in row.dataset && !row.dataset.playerId
    hereButton.textContent = addsExtra ? this.extraHereValue : this.hereValue
    hereButton.classList.toggle("here-extra", addsExtra)
  }
}
