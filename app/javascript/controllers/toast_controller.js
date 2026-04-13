import { Controller } from "@hotwired/stimulus"
import { Toast } from "bootstrap"

export default class extends Controller {
  static values = {
    delay: { type: Number, default: 4000 }
  }

  connect() {
    const toastEl = this.element
    const toast = new Toast(toastEl, {
      delay: this.delayValue,
      autohide: true
    })
    toastEl.classList.remove('show')
    toast.show()
  }
}
