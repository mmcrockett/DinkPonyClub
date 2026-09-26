import { Controller } from "@hotwired/stimulus"

// Reveals the sidebar "Install" button only when installing is actually
// possible: a native `beforeinstallprompt` on Chromium, or a manual
// Add to Home Screen / Add to Dock walkthrough on Safari. Everywhere else
// (Firefox, iOS Chrome, in-app webviews) the button stays hidden -- there's
// nowhere for it to lead.
export default class extends Controller {
  static targets = ["button", "dialog", "shareLocation", "destination"]

  connect() {
    if (this.alreadyInstalled) return

    this.handlePromptAvailable = () => this.revealPrompt()
    this.handleInstalled = () => this.hide()
    window.addEventListener("dpc:install-available", this.handlePromptAvailable)
    window.addEventListener("appinstalled", this.handleInstalled)

    if (window.dpcInstallPrompt) {
      this.revealPrompt()
    } else if (this.manualInstallAvailable) {
      this.revealManual()
    }
  }

  disconnect() {
    window.removeEventListener("dpc:install-available", this.handlePromptAvailable)
    window.removeEventListener("appinstalled", this.handleInstalled)
  }

  get alreadyInstalled() {
    return window.matchMedia("(display-mode: standalone)").matches ||
      navigator.standalone === true
  }

  // iPadOS 13+ reports a desktop Mac user agent, so touch points distinguish
  // an iPad from an actual Mac.
  get iosDevice() {
    return /iPad|iPhone|iPod/.test(navigator.userAgent) ||
      (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1)
  }

  get macSafari() {
    return navigator.maxTouchPoints === 0 &&
      /Safari/.test(navigator.userAgent) &&
      !/Chrome|Chromium|Edg/.test(navigator.userAgent)
  }

  // Browsers and in-app webviews on iOS with no "Add to Home Screen" menu
  // item at all. Not exhaustive -- best effort only.
  get blockedBrowser() {
    return /CriOS|FxiOS|EdgiOS|OPiOS|FBAN|FBAV|Instagram|Line|Twitter/.test(navigator.userAgent)
  }

  get manualInstallAvailable() {
    if (this.iosDevice) return !this.blockedBrowser
    return this.macSafari
  }

  revealPrompt() {
    this.mode = "prompt"
    this.show()
  }

  revealManual() {
    this.mode = "manual"

    const ipad = this.iosDevice && navigator.platform === "MacIntel"
    if (this.macSafari) {
      this.shareLocationTarget.textContent = "in the toolbar at the top of the window"
      this.destinationTarget.textContent = "Add to Dock"
    } else if (ipad) {
      this.shareLocationTarget.textContent = "in the toolbar at the top of the screen"
      this.destinationTarget.textContent = "Add to Home Screen"
    } else {
      this.shareLocationTarget.textContent = "in the toolbar at the bottom of the screen"
      this.destinationTarget.textContent = "Add to Home Screen"
    }

    this.show()
  }

  show() {
    this.buttonTargets.forEach((button) => button.classList.remove("hidden"))
  }

  hide() {
    this.buttonTargets.forEach((button) => button.classList.add("hidden"))
  }

  async install() {
    if (this.mode === "manual") {
      this.dialogTarget.showModal()
      return
    }

    const prompt = window.dpcInstallPrompt
    if (!prompt) return

    window.dpcInstallPrompt = null
    this.hide()

    try {
      await prompt.prompt()
    } catch {
      // User dismissed the browser's own dialog, or the prompt had already
      // been consumed -- nothing further to do.
    }
  }

  closeDialog() {
    this.dialogTarget.close()
  }
}
