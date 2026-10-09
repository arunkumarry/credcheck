import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  update(event) {
    const bankId = event.target.value
    const frame = document.getElementById("cards_dropdown")
    if (bankId && frame) {
      frame.src = `/user_cards/new?bank_id=${bankId}`
    } else if (frame) {
      frame.src = ""
      frame.innerHTML = `
        <div>
          <label for="card_id" class="block text-sm font-medium leading-6 text-slate-900">Select Card</label>
          <div class="mt-2">
            <select name="card_id" id="card_id" disabled="disabled" class="block w-full rounded-md border-0 py-2.5 pl-3 pr-10 text-slate-900 ring-1 ring-inset ring-slate-300 focus:ring-2 focus:ring-orange-500 sm:text-sm sm:leading-6 disabled:bg-slate-50 disabled:text-slate-500">
              <option value="">Choose a bank first...</option>
            </select>
          </div>
        </div>
      `
    }
  }
}
