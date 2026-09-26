import { Controller } from "@hotwired/stimulus"

// Below `lg` the sidebar is a temporary overlay drawer (`data-drawer` on
// <body>, never persisted). At `lg`+ it's a persistent push sidebar whose
// expand/collapse state (`data-sidebar` on <body>) is saved in a cookie so
// the server can render the right width on first paint.
const DESKTOP_QUERY = "(min-width: 64rem)"
const COOKIE_MAX_AGE = 60 * 60 * 24 * 365

export default class extends Controller {
  static targets = ["panel", "backdrop", "button"]

  connect() {
    this.mediaQuery = window.matchMedia(DESKTOP_QUERY)
    this.mediaQuery.addEventListener("change", this.handleBreakpointChange)
    this.syncAriaExpanded()
  }

  disconnect() {
    this.mediaQuery.removeEventListener("change", this.handleBreakpointChange)
  }

  get isDesktop() {
    return this.mediaQuery.matches
  }

  handleBreakpointChange = () => {
    if (this.isDesktop) this.closeDrawer()
    this.syncAriaExpanded()
  }

  toggle() {
    if (this.isDesktop) {
      this.setDesktopExpanded(document.body.dataset.sidebar !== "expanded")
    } else {
      this.toggleDrawer()
    }
  }

  // Backdrop click / Escape: only meaningful for the mobile drawer.
  close() {
    if (!this.isDesktop) this.closeDrawer()
  }

  // Nav link click: close the drawer immediately on mobile rather than
  // waiting on the Turbo navigation to replace the page.
  linkClicked() {
    if (!this.isDesktop) this.closeDrawer()
  }

  setDesktopExpanded(expanded) {
    document.body.dataset.sidebar = expanded ? "expanded" : "collapsed"
    document.cookie = `sidebar=${expanded ? "expanded" : "collapsed"}; path=/; max-age=${COOKIE_MAX_AGE}; SameSite=Lax`
    this.syncAriaExpanded()
  }

  toggleDrawer() {
    if (document.body.dataset.drawer === "open") {
      this.closeDrawer()
    } else {
      this.openDrawer()
    }
  }

  openDrawer() {
    document.body.dataset.drawer = "open"
    this.panelTarget.setAttribute("role", "dialog")
    this.panelTarget.setAttribute("aria-modal", "true")
    this.syncAriaExpanded()

    const firstLink = this.panelTarget.querySelector("a, button")
    firstLink?.focus()
  }

  closeDrawer() {
    document.body.dataset.drawer = "closed"
    this.panelTarget.removeAttribute("role")
    this.panelTarget.removeAttribute("aria-modal")
    this.syncAriaExpanded()
  }

  syncAriaExpanded() {
    const expanded = this.isDesktop
      ? document.body.dataset.sidebar === "expanded"
      : document.body.dataset.drawer === "open"

    this.buttonTarget.setAttribute("aria-expanded", String(expanded))
  }
}
