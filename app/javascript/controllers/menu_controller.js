import { Controller } from "@hotwired/stimulus"

// Progressive enhancement for the narrow-screen header menu. The nav ships
// visible so it still works without JS; this controller marks the header as
// enhanced, which is what the stylesheet keys the collapsed menu off.
export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.element.classList.add("js-menu")
    this.buttonTarget.hidden = false
    // Turbo snapshots the body before disconnect() runs, so a menu left open on
    // navigation comes back open on Back. Reset rather than trusting the markup.
    this.#setOpen(false)
  }

  disconnect() {
    this.element.classList.remove("js-menu", "menu-open")
  }

  toggle() {
    this.#setOpen(!this.#open)
  }

  close(event) {
    if (event && this.element.contains(event.target)) return
    this.#setOpen(false)
  }

  closeOnEscape(event) {
    if (event.key !== "Escape" || !this.#open) return
    this.#setOpen(false)
    this.buttonTarget.focus()
  }

  get #open() {
    return this.element.classList.contains("menu-open")
  }

  #setOpen(open) {
    this.element.classList.toggle("menu-open", open)
    this.buttonTarget.setAttribute("aria-expanded", String(open))
  }
}
