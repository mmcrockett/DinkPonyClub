// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker")
  })
}

// Captured here, not in the Stimulus controller, so it survives Turbo
// tearing the sidebar down and rebuilding it on every navigation.
window.addEventListener("beforeinstallprompt", (event) => {
  event.preventDefault()
  window.dpcInstallPrompt = event
  window.dispatchEvent(new Event("dpc:install-available"))
})
