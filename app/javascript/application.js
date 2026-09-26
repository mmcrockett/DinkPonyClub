// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker")
  })
}

// beforeinstallprompt fires once, early in the page's life, and never again
// for that load. Captured here (rather than in the Stimulus controller) so it
// survives every Turbo visit -- the sidebar's install_controller connects and
// disconnects on each navigation, but application.js runs only once per real
// page load.
window.addEventListener("beforeinstallprompt", (event) => {
  event.preventDefault()
  window.dpcInstallPrompt = event
  window.dispatchEvent(new Event("dpc:install-available"))
})
