import { TossAds, GoogleAdMob } from '@apps-in-toss/web-bridge'

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   상수
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
const API_BASE             = 'https://backend-ruby-chi-85.vercel.app'
const BANNER_AD_GROUP_ID   = 'ait.v2.live.829324e7b3ea4adb'
const REWARDED_AD_GROUP_ID = 'ait.v2.live.3642e7e5de0446b6'

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   KST 유틸
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
function getKstDate() {
  return new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Seoul' }))
}

function kstDateStr(d) {
  return d.toISOString().slice(0, 10)
}

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   상태
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
let cards          = []
let currentIndex   = 0
let isLoading      = false
let insightUnlocked  = false
let tossAdsReady     = false
let rewardedAdLoaded = false

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   DOM refs
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
const $skeleton       = document.getElementById('skeleton')
const $errorView      = document.getElementById('error-view')
const $cardStack      = document.getElementById('card-stack')
const $completeScreen = document.getElementById('complete-screen')
const $progressDots   = document.getElementById('progress-dots')
const $counterCur     = document.getElementById('counter-cur')
const $counterTotal   = document.getElementById('counter-total')
const $retryBtn       = document.getElementById('retry-btn')
const $toast          = document.getElementById('toast')

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   캐시
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
function saveCache(data) {
  try { localStorage.setItem('jnews_general', JSON.stringify(data)) } catch {}
}

function loadCache() {
  try {
    const raw = localStorage.getItem('jnews_general')
    return raw ? JSON.parse(raw) : null
  } catch { return null }
}

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   HTML 이스케이프
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
function esc(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   토스트
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
let _toastTimer = null
function showToast(msg) {
  $toast.textContent = msg
  $toast.classList.add('show')
  clearTimeout(_toastTimer)
  _toastTimer = setTimeout(() => $toast.classList.remove('show'), 2200)
}

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   보상형 광고 (인사이트 카드 잠금 해제)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
function preloadRewardedAd() {
  rewardedAdLoaded = false
  try {
    if (!GoogleAdMob.loadAppsInTossAdMob?.isSupported?.()) return
    GoogleAdMob.loadAppsInTossAdMob({
      options: { adGroupId: REWARDED_AD_GROUP_ID },
      onEvent: (event) => {
        if (event.type === 'loaded') rewardedAdLoaded = true
      },
    })
  } catch {}
}

function handleWatchAd(insightCardEl) {
  const showAd = () => {
    GoogleAdMob.showAppsInTossAdMob({
      options: { adGroupId: REWARDED_AD_GROUP_ID },
      onEvent: (e) => {
        if (e.type === 'userEarnedReward' || e.type === 'rewarded' || e.type === 'rewardEarned') {
          unlockInsight(insightCardEl)
        }
        if (e.type === 'dismissed' && !insightUnlocked) showToast('광고를 끝까지 봐야 열 수 있어요')
      },
      onError: () => unlockInsight(insightCardEl),
    })
  }

  try {
    if (!GoogleAdMob.loadAppsInTossAdMob?.isSupported?.()) throw new Error('not supported')

    if (rewardedAdLoaded) {
      rewardedAdLoaded = false
      showAd()
    } else {
      GoogleAdMob.loadAppsInTossAdMob({
        options: { adGroupId: REWARDED_AD_GROUP_ID },
        onEvent: (event) => {
          if (event.type === 'loaded') showAd()
          if (event.type === 'failed') {
            showToast('광고를 불러오지 못했어요')
            unlockInsight(insightCardEl)
          }
        },
      })
    }
    return
  } catch {}
  unlockInsight(insightCardEl)
}

function unlockInsight(insightCardEl) {
  insightUnlocked = true
  const overlay = insightCardEl.querySelector('#insight-lock-overlay')
  if (overlay) overlay.classList.add('unlocked')
  showToast('인사이트가 열렸어요!')
}

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   카드 HTML 생성
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
function buildNewsCard(card, index) {
  const num = index + 1
  const safeUrl = card.sourceUrl && /^https?:\/\//.test(card.sourceUrl) ? card.sourceUrl : ''
  const sourceHtml = safeUrl ? `
    <a class="card-source" href="${esc(safeUrl)}" target="_blank">
      <div class="source-icon">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>
          <polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/>
        </svg>
      </div>
      <div class="source-info">
        <div class="source-label">원문 출처</div>
        <div class="source-name">${esc(card.sourceLabel || '기사 원문 보기')}</div>
      </div>
      <svg class="source-chevron" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round">
        <polyline points="9 18 15 12 9 6"/>
      </svg>
    </a>` : ''

  const glossary = Array.isArray(card.glossary) ? card.glossary : []
  const glossaryHtml = glossary.length ? `
    <div class="glossary-wrap">
      ${glossary.map(g => `
        <div class="glossary-item">
          <span class="glossary-term">${esc(g.term || '')}</span>
          <span class="glossary-def">${esc(g.definition || '')}</span>
        </div>
      `).join('')}
    </div>` : ''

  const el = document.createElement('div')
  el.className = 'news-card'
  el.dataset.index = index
  el.innerHTML = `
    <div class="card-inner">
      <div class="card-header">
        <div class="card-header-left">
          <div class="card-num">#${num}</div>
        </div>
        <button class="share-btn" data-index="${index}" aria-label="공유">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/>
            <line x1="8.59" y1="13.51" x2="15.42" y2="17.49"/><line x1="15.41" y1="6.51" x2="8.59" y2="10.49"/>
          </svg>
        </button>
      </div>
      <h2 class="card-title">${esc(card.title)}</h2>
      <p class="card-body-text">${esc(card.body)}</p>
    </div>
    ${glossaryHtml}
    ${sourceHtml}
  `

  el.querySelector('.share-btn').addEventListener('click', (e) => {
    e.stopPropagation()
    handleShare(card)
  })

  return el
}

function buildInsightCard(insightData, totalCards) {
  // 구버전 문자열 / 신버전 객체 모두 처리
  let headline = '', summary = '', points = [], outlook = '', mood = ''
  if (typeof insightData === 'string') {
    summary = insightData
  } else if (insightData && typeof insightData === 'object') {
    headline = insightData.headline || ''
    summary  = insightData.summary  || ''
    points   = Array.isArray(insightData.points) ? insightData.points : []
    outlook  = insightData.outlook  || ''
    mood     = insightData.mood     || ''
  }

  const moodEmoji = { optimistic: '📈', cautious: '⚠️', alarming: '🔴', neutral: '📊' }[mood] || ''

  const shareText = [headline, summary, ...points, outlook].filter(Boolean).join('\n')

  const headlineHtml = headline
    ? `<p class="insight-headline">${esc(headline)}</p>`
    : `<h2 class="insight-title">AI가 분석한<br>오늘의 핵심</h2>`
  const pointsHtml = points.length
    ? `<ul class="insight-points">${points.map(p => `<li>${esc(p)}</li>`).join('')}</ul>`
    : ''
  const outlookHtml = outlook
    ? `<p class="insight-outlook">▸ ${esc(outlook)}</p>`
    : ''

  const el = document.createElement('div')
  el.className = 'news-card insight-card'
  el.dataset.index = totalCards - 1

  el.innerHTML = `
    <div class="insight-lock-overlay" id="insight-lock-overlay">
      <div class="lock-icon-wrap">
        <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
          <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
        </svg>
      </div>
      <p class="lock-title">오늘의 핵심 인사이트</p>
      <p class="lock-sub">짧은 광고를 보면<br>AI가 정리한 핵심 관점을 열 수 있어요</p>
      <button class="watch-ad-btn" id="watch-ad-btn">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
          <polygon points="5 3 19 12 5 21 5 3"/>
        </svg>
        광고 보고 열기
      </button>
    </div>

    <div class="insight-inner">
      <div class="insight-badge-row">
        <div class="insight-badge">
          <svg width="11" height="11" viewBox="0 0 24 24" fill="white">
            <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/>
          </svg>
          오늘의 핵심 인사이트
        </div>
        ${moodEmoji ? `<span class="insight-mood-emoji">${moodEmoji}</span>` : ''}
      </div>
      ${headlineHtml}
      ${summary ? `<p class="insight-text" id="insight-text-content">${esc(summary)}</p>` : ''}
      ${pointsHtml}
      ${outlookHtml}
    </div>

    <div class="insight-footer">
      <span class="insight-complete-badge done" id="insight-complete-label">
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round">
          <polyline points="20 6 9 17 4 12"/>
        </svg>
        오늘 브리핑 완료
      </span>
      <button class="insight-share-btn" id="insight-share-btn">
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/>
          <line x1="8.59" y1="13.51" x2="15.42" y2="17.49"/><line x1="15.41" y1="6.51" x2="8.59" y2="10.49"/>
        </svg>
        공유
      </button>
    </div>
  `

  el.querySelector('#watch-ad-btn').addEventListener('click', () => {
    handleWatchAd(el)
  })

  el.querySelector('#insight-share-btn').addEventListener('click', () => {
    handleShare({ title: '오늘의 핵심 인사이트', body: shareText })
  })

  return el
}

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   공유
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
async function handleShare(card) {
  const text = `${card.title}\n\n${card.body}\n\n— 지음뉴스`
  try {
    if (navigator.share) {
      await navigator.share({ title: card.title, text })
    } else {
      await navigator.clipboard.writeText(text)
      showToast('클립보드에 복사했어요')
    }
  } catch {
    showToast('공유에 실패했어요')
  }
}

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   렌더링
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
function buildCards(data) {
  const { items = [] } = data
  const rawInsight = data.insight

  const newsItems = items.slice(0, 5)
  cards = newsItems.map((item) => ({
    title:       item.title || '',
    body:        item.summary || item.body || '',
    sourceLabel: item.source_label || item.sourceLabel || item.source || '원문 보기',
    sourceUrl:   item.source_url || item.sourceUrl || item.url || '',
    glossary:    item.glossary || [],
    isInsight:   false,
  }))

  // insight: 문자열(구버전) 또는 객체(신버전) 모두 처리
  if (rawInsight && (typeof rawInsight === 'string' ? rawInsight.trim() : true)) {
    cards.push({
      title:       '오늘의 핵심 인사이트',
      body:        typeof rawInsight === 'string' ? rawInsight : (rawInsight.summary || rawInsight.headline || ''),
      isInsight:   true,
      insightData: rawInsight,
    })
  }

  return cards
}

function renderCardStack() {
  $cardStack.innerHTML = ''
  const total = cards.length

  $progressDots.innerHTML = ''
  cards.forEach((_, i) => {
    const dot = document.createElement('div')
    dot.className = 'progress-dot'
    dot.id = `dot-${i}`
    $progressDots.appendChild(dot)
  })

  $counterTotal.textContent = total

  cards.forEach((card, i) => {
    let el
    if (card.isInsight) {
      el = buildInsightCard(card.insightData, total)
    } else {
      el = buildNewsCard(card, i)
    }
    el.id = `card-${i}`
    $cardStack.appendChild(el)
  })

  currentIndex = 0
  updateCardPositions()
  updateUI()

  // 인사이트 카드가 있으면 미리 광고 로드
  if (cards.some(c => c.isInsight)) preloadRewardedAd()
}

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   카드 위치
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
function updateCardPositions() {
  cards.forEach((_, i) => {
    const el = document.getElementById(`card-${i}`)
    if (!el) return
    el.classList.remove('active', 'prev', 'next-peek')
    if (i < currentIndex)          el.classList.add('prev')
    else if (i === currentIndex)   el.classList.add('active')
    else if (i === currentIndex+1) el.classList.add('next-peek')
  })
}

function updateUI() {
  $counterCur.textContent = currentIndex + 1
  cards.forEach((_, i) => {
    const dot = document.getElementById(`dot-${i}`)
    if (dot) dot.classList.toggle('active', i === currentIndex)
  })
}

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   네비게이션
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
function goNext() {
  if (currentIndex >= cards.length - 1) {
    showComplete()
    return
  }
  currentIndex++
  updateCardPositions()
  updateUI()
}

function goPrev() {
  if (currentIndex <= 0) return
  currentIndex--
  updateCardPositions()
  updateUI()
}

function showComplete() {
  $completeScreen.classList.add('visible')
  $cardStack.style.pointerEvents = 'none'
}

function hideComplete() {
  $completeScreen.classList.remove('visible')
  $cardStack.style.pointerEvents = ''
  currentIndex = 0
  insightUnlocked = false
  const overlay = document.getElementById('insight-lock-overlay')
  if (overlay) overlay.classList.remove('unlocked')
  updateCardPositions()
  updateUI()
}

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   터치 스와이프
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
const stage = document.getElementById('card-stage')
let touchStartX = 0
let touchStartY = 0
let touchDeltaX = 0
let isSwiping   = false

stage.addEventListener('touchstart', (e) => {
  touchStartX = e.touches[0].clientX
  touchStartY = e.touches[0].clientY
  touchDeltaX = 0
  isSwiping   = false
}, { passive: true })

stage.addEventListener('touchmove', (e) => {
  const dx = e.touches[0].clientX - touchStartX
  const dy = e.touches[0].clientY - touchStartY

  if (!isSwiping && Math.abs(dy) > Math.abs(dx) + 8) return

  isSwiping   = true
  touchDeltaX = dx

  const activeCard = document.getElementById(`card-${currentIndex}`)
  if (activeCard) {
    activeCard.classList.add('dragging')
    const rotate = touchDeltaX * 0.04
    activeCard.style.transform = `translateX(${touchDeltaX}px) rotate(${rotate}deg)`
  }
}, { passive: true })

stage.addEventListener('touchend', () => {
  const activeCard = document.getElementById(`card-${currentIndex}`)
  if (activeCard) {
    activeCard.classList.remove('dragging')
    activeCard.style.transform = ''
  }

  if (!isSwiping) return

  const THRESHOLD = 60

  // 완독 화면이 떠 있으면 왼쪽 스와이프로 닫기
  if ($completeScreen.classList.contains('visible')) {
    if (touchDeltaX < -THRESHOLD) hideComplete()
  } else {
    if (touchDeltaX < -THRESHOLD)      goNext()
    else if (touchDeltaX > THRESHOLD)  goPrev()
  }

  touchDeltaX = 0
  isSwiping   = false
}, { passive: true })

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   버튼 이벤트
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
$retryBtn.addEventListener('click', loadNews)

const $restartBtn = document.getElementById('restart-btn')
if ($restartBtn) $restartBtn.addEventListener('click', hideComplete)

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   상태 전환 헬퍼
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
function showSkeleton() {
  $skeleton.classList.remove('hidden')
  $errorView.classList.add('hidden')
  $cardStack.classList.add('hidden')
  $completeScreen.classList.remove('visible')
}

function showError() {
  $skeleton.classList.add('hidden')
  $errorView.classList.remove('hidden')
  $cardStack.classList.add('hidden')
}

function showCards() {
  $skeleton.classList.add('hidden')
  $errorView.classList.add('hidden')
  $cardStack.classList.remove('hidden')
}

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   API 호출
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
async function loadNews() {
  if (isLoading) return
  isLoading = true
  showSkeleton()

  try {
    const res = await fetch(`${API_BASE}/api/news?region=world&category=general`)
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    const data = await res.json()
    saveCache(data)
    buildCards(data)
    renderCardStack()
    showCards()
  } catch {
    const cached = loadCache()
    if (cached) {
      buildCards(cached)
      renderCardStack()
      showCards()
      showToast('저장된 뉴스를 불러왔어요')
    } else {
      showError()
    }
  } finally {
    isLoading = false
  }
}

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   TossAds 초기화
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
function initAds() {
  try {
    TossAds.initialize({
      callbacks: {
        onInitialized: () => {
          tossAdsReady = true
          try {
            if (TossAds.attachBanner?.isSupported?.()) {
              TossAds.attachBanner(BANNER_AD_GROUP_ID, document.getElementById('banner-ad'))
            }
          } catch {}
        },
      },
    })
  } catch {}
}

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   진입
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
const todayEl = document.getElementById('today-date')
if (todayEl) {
  const kst = getKstDate()
  todayEl.textContent = `${kst.getMonth() + 1}월 ${kst.getDate()}일`
}

async function init() {
  initAds()
  loadNews()
}

init()

window.loadNews = loadNews
