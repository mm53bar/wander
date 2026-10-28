import { Controller } from "@hotwired/stimulus"

// Opens a segment's scan code on the days it's needed, by the device's own
// clock rather than the server's, so a page the installed app cached on an
// earlier day still opens on the right one. Pairs with the collapsible
// controller on the same element, whichever of the two connects first.
export default class extends Controller {
  static values = { dates: Array }

  connect() {
    if (!this.datesValue.includes(this.#today)) return

    this.element.dataset.collapsibleOpenValue = "true"
    const collapsible = this.application.getControllerForElementAndIdentifier(this.element, "collapsible")
    if (collapsible && !collapsible.isOpen) collapsible.toggle()
  }

  get #today() {
    const now = new Date()
    const pad = (n) => String(n).padStart(2, "0")
    return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`
  }
}
