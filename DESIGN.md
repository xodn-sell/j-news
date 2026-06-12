---
name: J-news (지음뉴스)
version: 1.2.0
description: MZ세대를 위한 AI 뉴스 큐레이션 앱. Editorial base + Gamified rewards 하이브리드 톤.
platform: [android, ios, web]
framework: flutter
material: m3
revision: 2026-05-08 — 톤 전략 섹션 추가 (Editorial 정보소비 + Gamified 보상 분리).

brand:
  tone: [신뢰감, 명료, 속도감, 젊음]
  voice: 간결하고 단호한 정보 전달. 과한 수식어 배제.
  personality: 아침 브리핑을 대신해주는 똑똑한 친구.

# ── 컬러 토큰 ──────────────────────────────────────────────
# 실제 192개 하드코딩을 5계층으로 통합. 빈도 표기는 grep 결과(2026-04-25 기준).

colors:
  light:
    # Brand — 두 개의 primary 시스템 공존
    primary: "#1B2838"            # Material ThemeData primary (네이비). FilledButton·AppBar 등 m3 컴포넌트 기본.
    accent: "#0052CC"             # 브랜드 accent (브라이트 블루). CTA·링크·로그인·강조 — 실제 최다 사용 (48회).
    accentLight: "#4D9EFF"        # 그라데이션·배경 장식.
    accentSoft: "#7EB3FF"         # 보조 강조.
    accentDeep: "#0D2060"         # 대비 강조 (다크 텍스트 위 강조용).

    # Text — 실측 기반
    textPrimary: "#0D1117"        # 본문 메인 — 44회 사용. 거의 검정이지만 살짝 블루톤.
    textBody: "#2D2D2D"           # 일반 본문.
    textMuted: "#424242"          # 보조 텍스트.
    textInverse: "#FFFFFF"        # 어두운 배경 위 텍스트.

    # Surface
    surfaceBase: "#FBFBFE"        # 메인 배경 (쿨톤 1% 화이트).
    surfaceElevated: "#FFFFFF"    # 카드 본체.
    surfaceCard: "#FFFFFF"        # 카드 메인 — ThemeExtension `surfaceCard` (dark: #1C2128) 대응 라이트 값.
    surfaceAlt: "#F5F6FA"         # 리스트·서브 배경 — 10회 사용.
    surfaceTint: "#EEF4FF"        # 로그인 그라데이션 중간.
    surfaceTintDeep: "#E8F0FF"    # 로그인 그라데이션 하단.

    # Border
    borderSoft: "rgba(0, 82, 204, 0.10)"   # accent 10% — 카드 경계.
    borderHair: "rgba(0, 51, 102, 0.06)"   # 거의 안 보이는 헤어라인.

    # State
    success: "#34C759"            # iOS green — 7회 사용.
    warning: "#FFC107"            # 앰버 — 포인트·뱃지.
    error: "#FF3B30"              # iOS red.
    errorAlt: "#E53935"           # Material red — 일부 화면.

  dark:
    # Brand
    primary: "#8AB4F8"            # 다크용 라이트 블루 (Material M3 권장 패턴).
    accent: "#4A90D9"             # 다크 accent.
    accentLight: "#7EB3FF"

    # Text
    textPrimary: "#FFFFFF"        # 헤드라인.
    textBody: "#E5E7EB"           # 본문.
    textMuted: "#9CA3AF"          # 보조.

    # Surface
    surfaceBase: "#0F1115"        # 메인 배경 (순수 검정 금지).
    surfaceCard: "#1C2128"        # 카드 메인 — 실측값.
    surfaceElevated: "#252830"    # 더 떠 있는 카드.
    surfaceCardAlt: "#1C1F26"     # ThemeData darkTheme surfaceContainerHighest.

    # Border
    borderSoft: "rgba(255, 255, 255, 0.10)"
    borderHair: "rgba(255, 255, 255, 0.06)"

    # State
    success: "#34C759"
    warning: "#FFC107"
    error: "#FF3B30"

# ── 타이포그래피 ──────────────────────────────────────────
typography:
  fontFamily:
    primary: "Noto Sans KR"
    fallback: ["Noto Sans", "system-ui", "sans-serif"]
  source: "GoogleFonts.notoSansTextTheme (google_fonts package)"
  weights: [400, 500, 700, 800, 900]    # 실사용. 100/300/600 미사용.

  sizes:
    micro: 10           # 약관 태그·버전 숫자
    caption: 11         # 서브 라벨·CTA 보조
    small: 12           # 메타·부가 설명
    body: 13            # 일반 본문
    bodyLarge: 14       # 본문 메인
    button: 16          # 버튼 텍스트 (filledButton 표준)
    cta: 17             # 메인 CTA 강조 텍스트
    title: 22           # 화면 타이틀
    display: 34         # 브랜드 노출·완독 화면

  scales:
    headlineLarge:
      weight: 900
      letterSpacing: -1.8
      usage: "메인 타이틀, 완독 축하, 브랜드 노출 (display 사이즈에 적용)"
    headlineMedium:
      weight: 900
      letterSpacing: -1.2
      usage: "화면 주요 헤더"
    titleLarge:
      weight: 800
      letterSpacing: -0.8
      usage: "카드 제목, 섹션 헤더"
    bodyLarge:
      height: 1.75
      letterSpacing: -0.3
      usage: "뉴스 본문 요약, 핵심 문장"
    bodyMedium:
      height: 1.65
      letterSpacing: -0.2
      usage: "부가 설명, 메타 텍스트"
    cta:
      weight: 900
      size: 17
      letterSpacing: -0.5
      usage: "메인 CTA 버튼 텍스트 (예: '100P 받고 시작하기')"
    ctaSub:
      weight: 500
      size: 11
      letterSpacing: -0.2
      usage: "메인 CTA 하단 보조 텍스트"

# ── 간격·라운드·고도 ────────────────────────────────────
spacing:
  base: 4
  scale: [0, 4, 6, 8, 10, 12, 14, 16, 20, 24, 28, 32, 40, 48, 64]

radius:
  none: 0
  xs: 4         # 태그·뱃지
  sm: 8         # 작은 칩
  md: 16        # 일반 카드·필드
  lg: 18        # 메인 버튼
  xl: 24        # 큰 카드
  xxl: 26       # 로고 컨테이너
  full: 9999

elevation:
  none: 0
  card: 0       # 플랫 — border로 구분
  cardSoft: 12  # 로그인 피처 카드 그림자 (accent 6% blur 12)
  dialog: 8

# ── 컴포넌트 ──────────────────────────────────────────
components:
  # 카드
  card:
    radius: 24
    elevation: 0
    padding: 24
    borderLight: "1px solid rgba(0, 82, 204, 0.06)"
    borderDark: "none"
    bgLight: "#FFFFFF"
    bgDark: "#1C2128"

  # 로그인 피처 행 (login_screen `_FeatureRow`)
  featureRow:
    radius: 16
    paddingX: 16
    paddingY: 14
    bg: "rgba(255, 255, 255, 0.75)"
    border: "1px solid rgba(0, 82, 204, 0.10)"
    shadow: "0 3px 12px rgba(0, 82, 204, 0.06)"
    titleSize: 13
    titleWeight: 700
    subSize: 12
    subColor: "rgba(13, 17, 23, 0.45)"

  # 메인 CTA (login_screen 베네핏 강조)
  ctaPrimary:
    height: 64
    radius: 18
    bgLight: "#FFFFFF"
    fgLight: "#0D1117"
    layout: "Column(Row(icon + cta), ctaSub)"
    titleSize: 17
    titleWeight: 900
    titleLetterSpacing: -0.5
    subSize: 11
    subWeight: 500
    subColor: "rgba(13, 17, 23, 0.48)"
    disabledOpacity: 0.55

  # 보조 CTA (outlined)
  ctaSecondary:
    height: 52
    radius: 18
    bgLight: "#FFFFFF"
    border: "1px solid rgba(0, 82, 204, 0.12)"
    titleSize: 14
    titleWeight: 700

  # FilledButton (Theme 기본)
  filledButton:
    radius: 16
    paddingX: 24
    paddingY: 16
    fontSize: 16
    fontWeight: 800
    bgLight: "#1B2838"
    fgLight: "#FFFFFF"

  # 약관 동의 행 (login_screen `_ConsentRow`)
  consentRow:
    paddingX: 4
    paddingY: 6
    radius: 10
    checkboxSize: 20
    checkboxRadius: 6
    checkboxBorder: "1.6px solid rgba(13, 17, 23, 0.30)"
    tagBg: "rgba(0, 82, 204, 0.10)"      # 필수: accent 10%, 선택: gray 10%
    tagSize: 10
    tagWeight: 800
    labelSize: 12
    labelWeight: 500

  # AppBar
  appBar:
    elevation: 0
    scrolledUnderElevation: 0
    centerTitle: false
    surfaceTint: transparent

  # SnackBar
  snackBar:
    radius: 16
    behavior: floating

  # 에러 배너 (login_screen 인라인 에러)
  errorBanner:
    radius: 12
    bg: "rgba(255, 0, 0, 0.08)"
    border: "1px solid rgba(255, 0, 0, 0.25)"
    textColor: "#CC0000"
    fontSize: 13

  # 다이얼로그 (gacha 등)
  dialog:
    radius: 16
    titleWeight: 800
    contentSize: 13
    contentLineHeight: 1.6

  # 포인트 뱃지 (warning 톤)
  pointBadge:
    bg: "#FFC107"
    fg: "#0D1117"
    radius: full
    paddingX: 8
    paddingY: 2
    weight: 800

  # SRS 복습 플래시카드 (review_screen) — Editorial 톤
  reviewFlashCard:
    radius: 24                  # radius.xl
    padding: 24
    bgLight: surfaceElevated    # #FFFFFF
    bgDark: surfaceContainerHighest
    borderLight: "1px solid rgba(0, 82, 204, 0.08)"
    borderDark: "none"
    frontQuestionSize: 18       # w800, height 1.5, ls -0.4, 중앙 정렬
    frontHint: "탭해서 정답 확인 — 12px w500 textPrimary 35%"
    backAnswerSize: 17          # w800 + success 체크 아이콘 (state 컬러 예외)
    backExplanationSize: 14     # w500, height 1.65, textPrimary 70%
    flip: "200ms easeInOut fade (3D 회전·elasticOut 금지)"
    actions: "다시 볼래요(outlined 52h) / 기억났어요(filled accent 52h)"

  # 출처 기사 칩 (review_screen 카드 상단)
  dueDateChip:
    radius: 8                   # radius.sm
    paddingX: 8
    paddingY: 3
    bg: "rgba(0, 82, 204, 0.08)"   # accent 8%
    fg: accent
    fontSize: 11
    fontWeight: 800
    maxLines: 1                 # ellipsis

  # 헤더 due 배지 (home_screen _HeaderIconButton)
  dueBadge:
    bg: error                   # #FF3B30 — state 컬러 (재방문 트리거)
    fg: "#FFFFFF"
    radius: full
    minWidth: 14
    fontSize: 9
    fontWeight: 800
    maxLabel: "9+"

  # SRS 복습 배너 (home_screen `_ReviewBanner`) — due>0일 때만 노출
  reviewBanner:
    height: 48
    radius: 16
    bg: surfaceTint             # #EEF4FF — editorial 톤 절제
    layout: "Row(카드 아이콘 + '오늘 복습할 카드 N개' + chevron)"
    fontSize: 14
    fontWeight: 800
    fg: accent
    tap: "review_screen 라우팅 (헤더 아이콘과 동일)"
    semantics: "label 필수 (due 카운트 포함)"

  # 완료/결과 요약 (review_screen 완료 + quiz_screen 결과 공용 — widgets/achievement_summary.dart)
  achievementSummary:
    layout: "display 타이포 타이틀 + 통계 카드(statRows) + subtitle + 닫기"
    titleScale: headlineLarge   # display 34, w900
    statRows: "List<(label, value)> — 라벨 w500 textMuted / 값 w800"
    actions: "닫기(filled) + secondaryAction?(outlined — 예: 공유)"
    tone: Editorial             # 컨페티/elasticOut 금지, 200ms fade

# ── 모션 ──────────────────────────────────────────
motion:
  fadeEntry:
    duration: 900ms
    curve: easeOut
    usage: "login_screen, onboarding 진입 페이드"
  slideEntry:
    from: "(0, 0.10)"
    to: "(0, 0)"
    duration: 900ms
    curve: easeOutCubic
    usage: "login·onboarding 슬라이드 인"
  cardSwipe:
    duration: 280ms
    curve: easeOutCubic
    usage: "news_tab 카드 스와이프"
  fade:
    duration: 200ms
    curve: easeInOut
  pulse:
    duration: 1400ms
    curve: easeInOut
    repeat: reverse
    usage: "onboarding CTA 강조"
  celebration:
    duration: 600ms
    curve: elasticOut
    usage: "완독 축하, 뽑기 결과"

# ── 아이콘 ──────────────────────────────────────────
iconography:
  library: "Material Icons (rounded 우선)"
  weight: 400
  sizes:
    sm: 14         # 체크박스 내부
    md: 18         # 보조 아이콘
    lg: 20         # CTA 아이콘
    xl: 24         # 일반
    xxl: 32

# ── 접근성 ──────────────────────────────────────────
accessibility:
  minTouchTarget: 48
  contrastRatio: "WCAG AA (4.5:1 본문, 3:1 large)"
  reducedMotion: 지원
---

# J-news 디자인 원칙

## 1. 두 개의 Primary 시스템 (의도)

지음뉴스는 **딥 네이비(`#1B2838`) + 브라이트 블루(`#0052CC`)** 두 개를 함께 쓴다. 우연이 아니라 역할 분리:

- **`#1B2838` 네이비** = Material ThemeData primary. FilledButton·AppBar·기본 m3 컴포넌트.
  - "신뢰와 무게감" — 뉴스가 가벼워 보이지 않도록.
- **`#0052CC` 브라이트 블루** = 브랜드 accent. CTA·링크·로그인 화면·강조 영역.
  - "1초 안에 눌러야 할 곳을 알리는 신호" — 실제 사용 압도적 1위 (48회).

같은 화면에서 둘 다 쓸 땐 **위계 차이를 분명히**: 네이비는 텍스트/배경 강조, 브라이트 블루는 클릭 가능성 신호.

## 2. 왜 이 색인가

- **Surface `#FBFBFE`**: 순백 대신 쿨톤 1% — 장시간 스크롤 피로 저감.
- **Text `#0D1117`**: 거의 검정이지만 살짝 블루톤. 브랜드 통일감 + 가독성.
- **Surface alt `#F5F6FA`**: 리스트 배경. 카드(`#FFFFFF`)와 명도차로 레이어 구분.
- **State 컬러는 iOS 톤**: `#34C759` `#FF3B30` — Android에서도 어색하지 않음. 한국 유저는 iOS 컬러에 익숙.

## 3. 타이포 철학

- **Noto Sans KR 단일 패밀리** — 한글 뉴스 메인. 가독성 > 개성.
- **Tight letter-spacing** — 뉴스 헤드라인 임팩트. 펼침 대신 응축.
- **Weight 800~900 남용 OK** — 카드 UI에서 헤드라인 임팩트가 핵심.
- **Line height 1.65~1.75** — 한 카드에서 끝까지 읽도록 여유.

## 4. 컴포넌트 원칙

### 카드
- **Radius 24px** 기본. 작은 카드(피처 행 등)는 16.
- **Elevation 0 + 얇은 border** — 그림자 대신 경계선.
- **Padding 24** — 내부 spacing은 scale 사용.

### CTA
- **메인 CTA = 1개 원칙**. 화면당 가장 중요한 액션 1개에만 64h.
- **보조 = outlined 52h**.
- **베네핏 텍스트 + 보조 텍스트** 2단 구조 (예: `100P 받고 시작하기` / `Google 계정으로 3초만에`).

### 여백
- **4px base grid** 엄수. 모든 여백은 4의 배수.
- **카드 간격 16, 섹션 간격 32**.

## 5. 모션

- **빠르게** — 뉴스는 속도감. 280ms 이하 기본.
- **카드 스와이프는 손가락 추적** — physics 기반.
- **Celebration(완독·뽑기)만 600ms elastic** — 보상 순간만 과장.
- **진입 애니메이션 900ms** — 첫 화면만 천천히 펴짐.

## 6. 다크모드 전환 규칙

- **순수 #000 금지** — `#0F1115` 사용.
- **카드 bg `#1C2128`** — surface와 명도차 충분.
- **텍스트 pure white 금지** — `#E5E7EB` 본문, `#FFFFFF`는 헤드라인만.
- **border 거의 제거** — 명도차로 구분.

## 7. 금지 사항 (Anti-patterns)

- 화면당 메인 CTA 2개 이상
- 카드 radius 16/24 외 값 (예: 12, 20)
- Noto Sans KR 외 한글 폰트 혼용
- 그림자(shadow) — elevation 기반 디자인
- 채도 높은 보조색 (state 외 빨강/초록/보라 아이콘 금지)
- 한 화면에 weight 4종 이상 혼용 (400/700/900 정도만)
- Color 직접 인스턴스화 (`Color(0xFF...)`) — `Theme.of(context).colorScheme` 또는 ThemeExtension 경유

## 8. 톤 전략 — Editorial Base + Gamified Rewards (v1.4.x)

지음뉴스는 **두 톤이 명확히 분리되어 공존**한다. 토스 만보기 모델과 동일.

### Editorial (정보 소비 영역)
- 적용 화면: 홈, 뉴스카드, 인사이트, 온보딩, 설정, 채팅(AI 토론), 오디오 브리핑
- 톤: 차분, 신뢰, 절제. 잡지 느낌.
- 규칙:
  - 색은 텍스트 검정/딥네이비 위주, accent는 **포인트만 1색**
  - 타이포 weight 800~900 + tight letter-spacing (-1.2~-1.8)
  - 여백 크게 (32~48px 섹션 간격)
  - 애니메이션 절제 (200ms 이하 fade·slide만)
  - 그라디언트 사용 금지
  - 헤더에 세션 라벨 ("오전 브리핑") 큰 디스플레이 타이포로 강조

### Gamified (보상 영역)
- 적용 화면/컴포넌트: gacha_dialog, 완독 보상 토스트, point_screen 진척바, 광고형 뽑기 버튼
- 톤: 임팩트, 즐거움, 보상감. 게임 느낌.
- 규칙:
  - 그라디언트 OK (`#0052CC` → `#4D9EFF`)
  - 큰 숫자 (60~96pt)
  - elasticOut 600ms+ 애니메이션
  - 컨페티·코인 등 장식 요소
  - 색 팔레트 6색 (gacha_dialog `_ConfettiPainter` 참조)
  - bouncy spring 토스트

### 분리 원칙
- **정보 소비 중에 보상 톤이 침범하지 말 것** — 카드 위에 코인 띄우기 금지
- **보상 받을 때만 게임화 폭발** — 완독·뽑기 순간만 풀 게임화
- 헤더의 포인트 뱃지 등 항상 보이는 보상 표시는 editorial 톤에 맞춰 절제

## 9. AI 에이전트 사용 가이드

이 파일은 **Claude Code · Cursor · Gemini CLI**가 UI 코드 생성 시 참조하는 단일 진실 원천.

- 새 화면 추가: 토큰 값을 **하드코딩 없이** `Theme.of(context).colorScheme` / `textTheme` / ThemeExtension 통해 참조
- 신규 컴포넌트: `components` 섹션에 추가 → AI가 재사용
- 컬러/폰트 변경: 여기 먼저 수정 → `lib/main.dart` ThemeData 동기화

## 10. Tech Debt — 하드코딩 인벤토리

**현황 (2026-04-25 기준)**: 192개 `Color(0xFF...)` 직접 사용 across 10 files.

| 파일 | 하드코딩 수 |
|---|---|
| `main.dart` | 21 |
| `screens/news_tab.dart` | 40 |
| `screens/onboarding_screen.dart` | 32 |
| `screens/login_screen.dart` | 31 |
| `screens/home_screen.dart` | 26 |
| `widgets/gacha_dialog.dart` | 13 |
| `screens/point_screen.dart` | 10 |
| `screens/settings_screen.dart` | 9 |
| `widgets/native_ad_card.dart` | 3 |

**최다 사용 색상 (재정의 필수)**:
1. `#0052CC` — 48회 → `accent`
2. `#0D1117` — 44회 → `textPrimary`
3. `#F5F6FA` — 10회 → `surfaceAlt`
4. `#34C759` — 7회 → `success`
5. `#1C2128` — 7회 → `surfaceCard` (dark)

**점진적 마이그레이션 전략**:
1. **Phase 1**: `ThemeExtension<JNewsColors>` 정의 → `main.dart` ThemeData에 등록. ✅
2. **Phase 2**: 화면별 변환 — `login_screen` → `home_screen` → `onboarding` → 기타. **대부분 완료 (2026-06-11)**: news_tab(`_onSurfaceAlpha` theme-aware화), onboarding, bookmark, quiz, audio_briefing, chat_sheet, native_ad_card, about 토큰 경유 전환. 위 인벤토리 표는 2026-04-25 실측 — 현재는 크게 감소.
3. **Phase 3**: lint 규칙 추가 — `Color(0xFF...)` 직접 사용 금지.

## 11. 변경 이력

- **2026-06-11 v1.3.0** — 전면 UI/UX 정비: ① 다크모드 토글 복구 (설정, 기본 system) + news_tab/native_ad_card/상태바 다크 깨짐 수리. ② 컴포넌트 2종 추가 (reviewBanner, achievementSummary). ③ 라이트 `surfaceCard` 토큰 명시. ④ 터치 타겟 48dp 일괄 (헤더/북마크/공유칩/용어칩/속도칩) + Semantics/tooltip. ⑤ 완독 CTA 위계 (퀴즈 filled 56h / 공유 outlined 48h). ⑥ 카피 통일 ("AI 튜터"), about 스테일 카피·배터리 행 제거, 버전 package_info_plus 단일화. ⑦ 토큰 위반 정리 (소나 핑크→accentDeep, amber→accent, radius 14/20→16, 비토큰 색 제거).
- **2026-06-10 v1.2.1** — 학습앱 전환 P2: SRS 복습 컴포넌트 3종 추가 (reviewFlashCard, dueDateChip, dueBadge). 복습 화면은 Editorial 단일 톤 (컨페티/elasticOut 금지, 200ms fade).
- **2026-05-08 v1.2.0** — 톤 전략 (Editorial Base + Gamified Rewards) 섹션 8 추가. 두 톤 명확 분리. 카드/홈/온보딩=editorial, gacha_dialog/완독토스트=gamified.
- **2026-04-25 v1.1.0** — 실측 기반 재작성. 192개 하드코딩 분석 → brand accent(`#0052CC`) 추가, text/surface 보정, state 컬러 정의, 컴포넌트 8종 추가, Tech Debt 인벤토리 추가.
- **2026-04-22 v1.0.0** — 초기 스펙. main.dart ThemeData 미러.
