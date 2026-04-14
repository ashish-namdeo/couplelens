import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "input", "form", "sendBtn", "emojiBtn", "pickerContainer", "picker"]

  connect() {
    this.scrollToBottom()
    this._onSubmitEnd = this.onSubmitEnd.bind(this)
    document.addEventListener('turbo:submit-end', this._onSubmitEnd)
  }

  disconnect() {
    document.removeEventListener('turbo:submit-end', this._onSubmitEnd)
  }

  onSubmitEnd(e) {
    if (e.detail.formSubmission.formElement === this.formTarget) {
      this.inputTarget.value = ''
      this.inputTarget.style.height = 'auto'
      this.inputTarget.readOnly = false
      this.inputTarget.style.opacity = '1'
      this.inputTarget.focus()
      this.sendBtnTarget.innerHTML = '<svg viewBox="0 0 24 24" width="22" height="22" fill="white" style="transform: translateX(2px);"><path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"></path></svg>'
      this.sendBtnTarget.style.pointerEvents = 'auto'
    }
  }

  scrollToBottom() {
    if (this.hasMessagesTarget) {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    }
  }

  resizeInput() {
    this.inputTarget.style.height = 'auto'
    this.inputTarget.style.height = this.inputTarget.scrollHeight + 'px'
  }

  handleKeydown(e) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      if (this.inputTarget.value.trim() !== '') {
        const submitBtn = this.formTarget.querySelector('button[type="submit"]')
        if (submitBtn) {
          submitBtn.click()
        }
      }
    }
  }

  handleSubmit() {
    if (this.inputTarget.value.trim() !== '') {
      this.sendBtnTarget.innerHTML = '<div class="spinner-border spinner-border-sm text-light" role="status"></div>'
      this.sendBtnTarget.style.pointerEvents = 'none'
      this.inputTarget.readOnly = true
      this.inputTarget.style.opacity = '0.7'
    }
  }

  toggleEmojiPicker(e) {
    e.preventDefault()
    e.stopPropagation()
    const container = this.pickerContainerTarget
    container.style.display = container.style.display === 'none' ? 'block' : 'none'
  }

  handleEmojiClick(e) {
    const input = this.inputTarget
    const cursorPosition = input.selectionStart
    const textBefore = input.value.substring(0, cursorPosition)
    const textAfter = input.value.substring(cursorPosition)
    input.value = textBefore + e.detail.unicode + textAfter
    
    // Re-focus and position cursor
    input.focus()
    input.selectionStart = cursorPosition + e.detail.unicode.length
    input.selectionEnd = cursorPosition + e.detail.unicode.length
    
    // Trigger resize
    this.resizeInput()
  }

  closeEmojiPicker(e) {
    if (this.hasPickerContainerTarget && this.hasEmojiBtnTarget) {
      if (!this.pickerContainerTarget.contains(e.target) && e.target !== this.emojiBtnTarget) {
        this.pickerContainerTarget.style.display = 'none'
      }
    }
  }
}
