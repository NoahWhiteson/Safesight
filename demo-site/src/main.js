import './style.css'
import gsap from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'
import { SCANS, mountScanPhone } from './scan-ui.js'

gsap.registerPlugin(ScrollTrigger)

const GH = 'https://github.com/NoahWhiteson/Safesight'
const API = 'https://github.com/NoahWhiteson/Safesight_API'

const root = document.querySelector('#app')

root.innerHTML = `
  <div class="site">
    <header class="topbar">
      <a class="logo" href="#top">
        <img src="/logo.png" alt="" width="28" height="28" />
        <span>Safesight</span>
      </a>
      <a class="btn ink" href="${GH}" target="_blank" rel="noreferrer">Get the app</a>
    </header>

    <main id="top">
      <section class="hero">
        <div class="hero-copy">
          <p class="eyebrow">iOS · Visible home safety</p>
          <h1 class="headline" data-rise>See what you’ve been missing.</h1>
          <p class="sub" data-rise>
            Point your camera at a room. Safesight finds visible risks, scores the space, and tells you what to fix.
          </p>
          <div class="cta-row">
            <a class="btn ink" href="${GH}" target="_blank" rel="noreferrer">Scan a room</a>
            <a class="btn soft" href="#proof">See the UI</a>
          </div>
          <p class="built">Built by Noah Whiteson, age 14 · Shipaton Next Gen</p>
        </div>
        <div class="hero-stage">
          <div id="heroMount"></div>
        </div>
      </section>

      <section class="score-band">
        <div class="score-band-inner">
          <div class="score-hero">
            <span class="score-big" id="bandScore">78</span>
            <div>
              <p class="score-label">House score</p>
              <p class="score-cap">Needs attention — fix the high-severity items first.</p>
            </div>
          </div>
          <div class="metric-row">
            <div class="metric-card">
              <span class="metric-k">Open</span>
              <strong id="bandOpen">3</strong>
            </div>
            <div class="metric-card">
              <span class="metric-k">Fixed</span>
              <strong>0</strong>
            </div>
            <div class="metric-card">
              <span class="metric-k">Confidence</span>
              <strong>95%</strong>
            </div>
          </div>
        </div>
      </section>

      <section class="missions" id="proof">
        <div class="section-head">
          <p class="eyebrow">Live UI</p>
          <h2 class="block-title" data-rise>Same overlays as the app.</h2>
          <p class="block-sub">Boxes, confidence tabs, House Score. Tap a hazard to open the fix drawer.</p>
        </div>

        <div class="segment" id="tabs" role="tablist">
          ${SCANS.map(
            (s, i) => `
            <button type="button" class="seg ${i === 0 ? 'on' : ''}" data-i="${i}" role="tab">${s.label}</button>`,
          ).join('')}
        </div>

        <div class="mission-stage">
          <div id="proofMount"></div>
          <p class="mission-cap" id="proofCap">${SCANS[0].label} · score ${SCANS[0].score}</p>
        </div>
      </section>

      <section class="features">
        <div class="section-head left">
          <p class="eyebrow">What you get</p>
          <h2 class="block-title" data-rise>Show, don’t just tell.</h2>
        </div>
        <div class="feature-grid">
          <article class="feature-card">
            <h3 data-rise>Labeled on the photo</h3>
            <p>Bounding boxes and fused tabs with severity color and confidence — exactly where the risk is.</p>
          </article>
          <article class="feature-card">
            <h3 data-rise>House Score</h3>
            <p>A clear readout for the frame. Mark Fixed or Dismiss; open issues stay on Hazards.</p>
          </article>
          <article class="feature-card">
            <h3 data-rise>Focus areas</h3>
            <p>Child-proofing, trips, exits, electric, and more — gated to what you actually care about.</p>
          </article>
          <article class="feature-card">
            <h3 data-rise>Premium</h3>
            <p>Unlimited scans and premium focus areas via RevenueCat. Monetization with a real job.</p>
          </article>
        </div>
      </section>

      <section class="rail">
        <div class="section-head">
          <p class="eyebrow">Rooms</p>
          <h2 class="block-title" data-rise>Scan. Understand. Fix.</h2>
        </div>
        <div class="rail-track" id="railMount"></div>
      </section>

      <section class="finale">
        <div class="finale-card">
          <h2 class="finale-title" data-rise>Start with a room scan.</h2>
          <p>Open source. Student-built. Visible hazards only — not a licensed inspection.</p>
          <div class="cta-row">
            <a class="btn ink" href="${GH}" target="_blank" rel="noreferrer">Get Safesight</a>
            <a class="btn soft" href="${API}" target="_blank" rel="noreferrer">API repo</a>
          </div>
        </div>
      </section>
    </main>

    <footer class="foot">
      <div class="logo sm">
        <img src="/logo.png" alt="" width="22" height="22" />
        <span>Safesight</span>
      </div>
      <p>Built by Noah Whiteson, age 14.</p>
      <p class="tiny">Visible hazards only.</p>
    </footer>
  </div>
`

const heroPhone = mountScanPhone({ scan: SCANS[0], size: 'hero', id: 'heroPhone' })
document.querySelector('#heroMount').appendChild(heroPhone)

let proofPhone = mountScanPhone({ scan: SCANS[0], size: 'lg', id: 'proofPhone' })
document.querySelector('#proofMount').appendChild(proofPhone)

const rail = document.querySelector('#railMount')
SCANS.forEach((scan) => {
  const wrap = document.createElement('figure')
  wrap.className = 'rail-card'
  wrap.appendChild(mountScanPhone({ scan, size: 'sm', interactive: false }))
  const cap = document.createElement('figcaption')
  cap.textContent = `${scan.label} · ${scan.score}`
  wrap.appendChild(cap)
  rail.appendChild(wrap)
})

function syncBand(scan) {
  document.querySelector('#bandScore').textContent = String(scan.score)
  document.querySelector('#bandOpen').textContent = String(scan.hazards.length)
  document.querySelector('#proofCap').textContent = `${scan.label} · score ${scan.score}`
}

const tabs = document.querySelector('#tabs')
tabs.addEventListener('click', (e) => {
  const btn = e.target.closest('.seg')
  if (!btn) return
  const i = Number(btn.dataset.i)
  tabs.querySelectorAll('.seg').forEach((t) => t.classList.toggle('on', t === btn))
  const scan = SCANS[i]
  syncBand(scan)

  const next = mountScanPhone({ scan, size: 'lg', id: 'proofPhone' })
  proofPhone.replaceWith(next)
  proofPhone = next
  gsap.from(next, { opacity: 0.4, y: 12, duration: 0.3, ease: 'power2.out' })

  const heroNext = mountScanPhone({ scan, size: 'hero', id: 'heroPhone' })
  document.querySelector('#heroPhone')?.replaceWith(heroNext)
})

function applyRise(el) {
  if (!el || el.dataset.risen === '1') return
  const text = el.textContent.trim()
  el.textContent = ''
  el.classList.add('rise-ready')
  text.split(/\s+/).filter(Boolean).forEach((w, i, arr) => {
    const outer = document.createElement('span')
    outer.className = 'cw'
    const inner = document.createElement('span')
    inner.className = 'ci'
    inner.style.setProperty('--i', String(i))
    inner.textContent = w
    outer.appendChild(inner)
    el.appendChild(outer)
    if (i < arr.length - 1) el.appendChild(document.createTextNode(' '))
  })
  el.dataset.risen = '1'
}

function showRise(el) {
  applyRise(el)
  void el.offsetWidth
  el.classList.add('show')
}

document.querySelectorAll('[data-rise]').forEach(applyRise)
document.querySelectorAll('.hero [data-rise]').forEach((el, i) => {
  setTimeout(() => el.classList.add('show'), 80 + i * 140)
})
document.querySelectorAll('[data-rise]').forEach((el) => {
  if (el.closest('.hero')) return
  ScrollTrigger.create({
    trigger: el,
    start: 'top 85%',
    once: true,
    onEnter: () => showRise(el),
  })
})

gsap.from('#heroPhone', { y: 36, opacity: 0, duration: 0.9, ease: 'power3.out', delay: 0.15 })
gsap.to('#heroPhone', { y: -8, duration: 3.6, ease: 'sine.inOut', yoyo: true, repeat: -1, delay: 1 })

gsap.from('.ss-hz', {
  scale: 0.75,
  opacity: 0,
  duration: 0.4,
  stagger: 0.1,
  ease: 'back.out(1.5)',
  delay: 0.55,
})

gsap.from('.feature-card', {
  scrollTrigger: { trigger: '.features', start: 'top 80%', once: true },
  y: 28,
  opacity: 0,
  duration: 0.55,
  stagger: 0.08,
  ease: 'power3.out',
})

gsap.from('.rail-card', {
  scrollTrigger: { trigger: '.rail', start: 'top 85%', once: true },
  y: 28,
  opacity: 0,
  duration: 0.55,
  stagger: 0.07,
  ease: 'power3.out',
})
