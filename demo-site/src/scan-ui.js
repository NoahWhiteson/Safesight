/** Live Safesight scan UI — mirrors app overlays (boxes, tabs, score, chrome). */

export const SEVERITY = {
  high: '#eb4740',
  medium: '#f29e1f',
  low: '#33ad73',
}

export const SCANS = [
  {
    id: 'kitchen',
    label: 'Kitchen',
    photo: '/rooms/kitchen.jpg',
    score: 78,
    scansLeft: 2,
    hazards: [
      {
        id: 'k1',
        title: "Exposed Chef's Knife",
        detail: 'Move it into a secured drawer or knife block.',
        severity: 'high',
        confidence: 95,
        box: { x: 0.42, y: 0.4, w: 0.22, h: 0.12 },
      },
      {
        id: 'k2',
        title: 'Obstacle Near Exit Door',
        detail: 'Clear the path so the exit stays usable.',
        severity: 'medium',
        confidence: 92,
        box: { x: 0.62, y: 0.58, w: 0.24, h: 0.2 },
      },
      {
        id: 'k3',
        title: 'Loose Runner Rug',
        detail: 'Add a non-slip pad or secure the edges.',
        severity: 'low',
        confidence: 75,
        box: { x: 0.18, y: 0.72, w: 0.36, h: 0.14 },
      },
    ],
  },
  {
    id: 'hallway',
    label: 'Hallway',
    photo: '/rooms/hallway.jpg',
    score: 68,
    scansLeft: 2,
    hazards: [
      {
        id: 'h1',
        title: 'Dim hallway lighting',
        detail: 'Swap in a brighter bulb or add a motion light.',
        severity: 'medium',
        confidence: 88,
        box: { x: 0.35, y: 0.08, w: 0.28, h: 0.16 },
      },
      {
        id: 'h2',
        title: 'Trip clutter on path',
        detail: 'Keep a clear walkway edge-to-edge.',
        severity: 'high',
        confidence: 91,
        box: { x: 0.22, y: 0.62, w: 0.4, h: 0.18 },
      },
      {
        id: 'h3',
        title: 'Blocked secondary exit',
        detail: 'Move storage at least 36" off the exit path.',
        severity: 'medium',
        confidence: 84,
        box: { x: 0.58, y: 0.28, w: 0.28, h: 0.36 },
      },
    ],
  },
  {
    id: 'bathroom',
    label: 'Bathroom',
    photo: '/rooms/bathroom.jpg',
    score: 82,
    scansLeft: 1,
    hazards: [
      {
        id: 'b1',
        title: 'Medications accessible',
        detail: 'Store meds in a secured cabinet.',
        severity: 'high',
        confidence: 90,
        box: { x: 0.12, y: 0.28, w: 0.3, h: 0.22 },
      },
      {
        id: 'b2',
        title: 'Wet floor risk',
        detail: 'Add a bath mat with grip backing.',
        severity: 'medium',
        confidence: 79,
        box: { x: 0.4, y: 0.7, w: 0.38, h: 0.16 },
      },
    ],
  },
  {
    id: 'desk',
    label: 'Desk',
    photo: '/rooms/desk.jpg',
    score: 88,
    scansLeft: 2,
    hazards: [
      {
        id: 'd1',
        title: 'Overloaded outlet',
        detail: 'Consolidate onto one surge-protected strip.',
        severity: 'medium',
        confidence: 86,
        box: { x: 0.55, y: 0.58, w: 0.3, h: 0.2 },
      },
      {
        id: 'd2',
        title: 'Cable trip risk',
        detail: 'Route cables with clips along the desk edge.',
        severity: 'low',
        confidence: 72,
        box: { x: 0.18, y: 0.7, w: 0.34, h: 0.14 },
      },
    ],
  },
]

function scoreColor(score) {
  if (score >= 85) return SEVERITY.low
  if (score >= 65) return SEVERITY.medium
  return SEVERITY.high
}

function circumference(r) {
  return 2 * Math.PI * r
}

/**
 * @param {object} opts
 * @param {typeof SCANS[0]} opts.scan
 * @param {'hero'|'lg'|'sm'} [opts.size]
 * @param {boolean} [opts.interactive]
 * @param {string} [opts.id]
 */
export function mountScanPhone(opts) {
  const { scan, size = 'lg', interactive = true, id } = opts
  const root = document.createElement('div')
  root.className = `ss-phone ss-${size}`
  if (id) root.id = id
  root.dataset.scanId = scan.id

  const r = 42
  const c = circumference(r)
  const offset = c * (1 - Math.min(100, Math.max(0, scan.score)) / 100)
  const color = scoreColor(scan.score)

  root.innerHTML = `
    <div class="ss-bezel">
      <div class="ss-island"></div>
      <div class="ss-screen">
        <img class="ss-photo" src="${scan.photo}" alt="${scan.label} room" />
        <div class="ss-wash ss-wash-top"></div>
        <div class="ss-wash ss-wash-bot"></div>

        <div class="ss-chrome">
          <img class="ss-logo" src="/logo.png" alt="" />
          <span class="ss-left">${scan.scansLeft} left</span>
        </div>

        <div class="ss-hazards">
          ${scan.hazards
            .map((h) => {
              const col = SEVERITY[h.severity]
              const { x, y, w, h: bh } = h.box
              return `
              <button type="button" class="ss-hz" data-id="${h.id}"
                style="--x:${x * 100}%;--y:${y * 100}%;--w:${w * 100}%;--h:${bh * 100}%;--c:${col}">
                <span class="ss-tab">
                  <span class="ss-tab-title">${h.title}</span>
                  <span class="ss-tab-pct">${h.confidence}%</span>
                </span>
                <span class="ss-box"></span>
              </button>`
            })
            .join('')}
        </div>

        <div class="ss-score" style="--sc:${color}">
          <svg viewBox="0 0 100 100" aria-hidden="true">
            <circle class="ss-track" cx="50" cy="50" r="${r}" />
            <circle class="ss-prog" cx="50" cy="50" r="${r}"
              stroke-dasharray="${c.toFixed(2)}"
              stroke-dashoffset="${offset.toFixed(2)}" />
          </svg>
          <div class="ss-score-num">
            <b>${scan.score}</b>
            <small>/ 100</small>
          </div>
        </div>

        <div class="ss-drawer" hidden>
          <div class="ss-handle"></div>
          <p class="ss-drawer-title"></p>
          <p class="ss-drawer-body"></p>
          <div class="ss-actions">
            <span class="ss-fixed">Fixed</span>
            <span class="ss-dismiss">Dismiss</span>
          </div>
        </div>
      </div>
    </div>
  `

  if (interactive) {
    const drawer = root.querySelector('.ss-drawer')
    const title = root.querySelector('.ss-drawer-title')
    const body = root.querySelector('.ss-drawer-body')

    root.querySelectorAll('.ss-hz').forEach((btn) => {
      btn.addEventListener('click', () => {
        const hz = scan.hazards.find((h) => h.id === btn.dataset.id)
        if (!hz) return
        root.querySelectorAll('.ss-hz').forEach((b) => b.classList.toggle('on', b === btn))
        title.textContent = hz.title
        body.textContent = hz.detail
        drawer.hidden = false
        drawer.classList.add('open')
      })
    })

    root.querySelector('.ss-screen').addEventListener('click', (e) => {
      if (e.target.closest('.ss-hz') || e.target.closest('.ss-drawer')) return
      drawer.hidden = true
      drawer.classList.remove('open')
      root.querySelectorAll('.ss-hz').forEach((b) => b.classList.remove('on'))
    })
  }

  return root
}

export function updateScanPhone(root, scan) {
  const next = mountScanPhone({
    scan,
    size: [...root.classList].find((c) => c.startsWith('ss-') && c !== 'ss-phone')?.replace('ss-', '') || 'lg',
    interactive: true,
    id: root.id || undefined,
  })
  root.replaceWith(next)
  return next
}
