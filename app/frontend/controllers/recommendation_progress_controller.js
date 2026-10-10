import { Controller } from "@hotwired/stimulus"

// Shows a live "agent is working" activity log while the recommendation
// request is in flight. The real work happens synchronously on the server
// (~1-2 min), so this walks through the agent's actual plan — price check,
// one offer scan per bank in the wallet, news, then compare — so the wait
// never looks frozen. Turbo replaces this with the real result when it lands.
export default class extends Controller {
  static values = {
    banks: Array,
    frame: { type: String, default: "recommendation_result" }
  }

  // Keep the progress visible for at least this long, so even an instant
  // (cached) response still shows the agent working instead of flashing.
  static MIN_VISIBLE_MS = 2200

  connect() {
    this.onStart = this.start.bind(this)
    this.onBeforeStream = this.holdResult.bind(this)
    this.element.addEventListener("turbo:submit-start", this.onStart)
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-start", this.onStart)
    document.removeEventListener("turbo:before-stream-render", this.onBeforeStream)
    this.clearTimers()
  }

  start() {
    const frame = document.getElementById(this.frameValue)
    if (!frame) return

    this.startedAt = Date.now()
    document.addEventListener("turbo:before-stream-render", this.onBeforeStream)

    this.steps = this.buildSteps()
    frame.innerHTML = this.template(this.steps)

    this.current = 0
    this.renderState()

    // Estimated pace: the per-bank live searches are the slow part.
    const durations = this.steps.map((label, i) => {
      if (i === 0) return 1800                      // reading wallet
      if (/Comparing/.test(label)) return 999999    // last step pulses until result
      return 11000                                   // each live search
    })

    this.advance(durations)
    this.fillBar()
  }

  // Delay the incoming result render until the progress has been visible for
  // MIN_VISIBLE_MS, so a fast/cached response doesn't erase the animation.
  holdResult(event) {
    document.removeEventListener("turbo:before-stream-render", this.onBeforeStream)
    const elapsed = Date.now() - (this.startedAt || 0)
    const wait = this.constructor.MIN_VISIBLE_MS - elapsed
    if (wait <= 0) return

    const originalRender = event.detail.render
    event.detail.render = (streamElement) =>
      new Promise((resolve) => {
        setTimeout(async () => {
          await originalRender(streamElement)
          resolve()
        }, wait)
      })
  }

  advance(durations) {
    const next = () => {
      if (this.current >= this.steps.length - 1) return
      this.timer = setTimeout(() => {
        this.current += 1
        this.renderState()
        next()
      }, durations[this.current])
    }
    next()
  }

  fillBar() {
    const bar = document.getElementById("cc-progress-bar")
    if (!bar) return
    // Ease asymptotically toward 92% so it keeps moving but never "finishes"
    // before the real result arrives.
    let pct = 6
    this.barTimer = setInterval(() => {
      pct += (92 - pct) * 0.06
      bar.style.width = `${pct}%`
    }, 900)
  }

  renderState() {
    this.steps.forEach((_, i) => {
      const dot = document.getElementById(`cc-step-dot-${i}`)
      const row = document.getElementById(`cc-step-${i}`)
      if (!dot || !row) return
      if (i < this.current) {
        dot.innerHTML = this.check()
        row.className = this.rowClass(true)
      } else if (i === this.current) {
        dot.innerHTML = this.spinner()
        row.className = this.rowClass(true)
      } else {
        dot.innerHTML = this.pendingDot()
        row.className = this.rowClass(false)
      }
    })
  }

  buildSteps() {
    const banks = Array.isArray(this.banksValue) && this.banksValue.length
      ? this.banksValue
      : ["your bank"]
    const steps = ["Reading your wallet", "Checking live price on Google Shopping"]
    banks.forEach((b) => steps.push(`Scanning ${b} offers (live)`))
    steps.push("Checking current sale-event news")
    steps.push("Comparing cards & computing best value")
    return steps
  }

  template(steps) {
    const rows = steps.map((label, i) => `
      <li id="cc-step-${i}" class="${this.rowClass(false)}">
        <span id="cc-step-dot-${i}" class="shrink-0 w-4 h-4 flex items-center justify-center">${this.pendingDot()}</span>
        <span>${label}</span>
      </li>`).join("")

    return `
      <div class="bg-white shadow rounded-lg p-6 animate-fade-in-up">
        <div class="flex items-center gap-2 mb-1">
          <span class="text-lg">🤖</span>
          <h2 class="text-lg font-semibold text-gray-900">CredCheck agent is working…</h2>
        </div>
        <p class="text-xs text-gray-500 mb-4">Pulling live prices and today's offers from SerpApi — this takes a moment.</p>
        <div class="w-full h-2 bg-gray-100 rounded-full overflow-hidden mb-5">
          <div id="cc-progress-bar" class="h-full bg-gradient-to-r from-indigo-500 to-orange-400 rounded-full" style="width:6%; transition: width 0.9s ease-out;"></div>
        </div>
        <ul class="space-y-2">${rows}</ul>
      </div>`
  }

  rowClass(active) {
    return `flex items-center gap-3 text-sm ${active ? "text-gray-800 font-medium" : "text-gray-400"}`
  }

  spinner() {
    return `<svg class="animate-spin h-4 w-4 text-indigo-600" viewBox="0 0 24 24" fill="none">
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"></path></svg>`
  }

  check() {
    return `<svg class="h-4 w-4 text-green-500" viewBox="0 0 20 20" fill="currentColor">
      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/></svg>`
  }

  pendingDot() {
    return `<span class="w-1.5 h-1.5 rounded-full bg-gray-300 block"></span>`
  }

  clearTimers() {
    if (this.timer) clearTimeout(this.timer)
    if (this.barTimer) clearInterval(this.barTimer)
  }
}
