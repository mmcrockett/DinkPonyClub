import { Controller } from "@hotwired/stimulus"

// The form re-renders inside its Turbo Frame on every submit, so the field being
// typed in is replaced mid-keystroke. Remember it across the swap and hand focus back.
let typing = null

export default class extends Controller {
  static values = { delay: { type: Number, default: 250 } }

  connect() {
    this.restoreTyping()
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  submit() {
    typing = null
    this.element.requestSubmit()
  }

  debouncedSubmit(event) {
    this.rememberTyping(event.target)
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }

  rememberTyping(field) {
    typing = { id: field.id, value: field.value, start: field.selectionStart, end: field.selectionEnd }
  }

  restoreTyping() {
    if (!typing) return

    const field = this.element.querySelector(`#${CSS.escape(typing.id)}`)
    if (!field) return

    const stale = field.value !== typing.value
    field.value = typing.value
    field.focus()
    field.setSelectionRange(typing.start, typing.end)
    if (stale) {
      this.debouncedSubmit({ target: field })
    } else {
      typing = null
    }
  }
}
