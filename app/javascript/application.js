// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import * as bootstrap from "bootstrap"
import "chartkick/chart.js"

// Custom Turbo confirm using toast instead of browser dialog
let confirmResolve = null
let confirmReject = null

Turbo.config.forms.confirm = async (message) => {
  return new Promise((resolve, reject) => {
    confirmResolve = resolve
    confirmReject = reject

    const toastContainer = document.querySelector('.toast-container') || document.body
    const existingToast = document.getElementById('confirm-toast')
    if (existingToast) existingToast.remove()

    const toastHtml = `
      <div id="confirm-toast" class="toast show position-fixed top-0 start-50 translate-middle-x mt-4" role="alert" style="z-index: 10000; background: rgba(26, 26, 46, 0.98); border: 1px solid rgba(108, 99, 255, 0.3); border-radius: 0.75rem; min-width: 320px; backdrop-filter: blur(20px);">
        <div class="toast-body p-4">
          <p class="mb-3" style="color: #E4E4F0; font-size: 0.95rem;">${message}</p>
          <div class="d-flex gap-2 justify-content-end">
            <button id="confirm-cancel" class="btn btn-sm btn-outline-glass" style="color: #C8C8DA;">Cancel</button>
            <button id="confirm-ok" class="btn btn-sm btn-gradient"><span>Confirm</span></button>
          </div>
        </div>
      </div>
    `
    toastContainer.insertAdjacentHTML('beforeend', toastHtml)

    document.getElementById('confirm-ok').addEventListener('click', () => {
      document.getElementById('confirm-toast').remove()
      if (confirmResolve) confirmResolve(true)
    })
    document.getElementById('confirm-cancel').addEventListener('click', () => {
      document.getElementById('confirm-toast').remove()
      if (confirmReject) reject(false)
    })
  })
}
