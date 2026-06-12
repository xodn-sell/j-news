# 지음뉴스 (J-news) — Claude Code 프로젝트 가이드

## 디자인 시스템
**UI/디자인 작업 시 `DESIGN.md`를 Single Source of Truth로 반드시 참조.**
색상·폰트·radius·spacing·컴포넌트 규칙은 DESIGN.md에 정의. 하드코딩 금지, `Theme.of(context)` 경유.
신규 컴포넌트 추가 시 DESIGN.md의 `components` 섹션 먼저 업데이트.

## 프로젝트 개요
"뉴스를 보고 싶지만 뭘 봐야 할지 모르는 사람들"을 위한 AI 뉴스 큐레이션 앱.
글로벌 뉴스를 AI 브리핑 (general 단일 카테고리, region: world 고정). Flutter 앱 + 토스 미니앱 + Python/Vercel 백엔드.

## 기술 스택
- **Flutter 앱**: `lib/` — Android/iOS, 다크/라이트/시스템 테마, Firebase Auth, Google AdMob
- **백엔드**: `backend/api/` — Python (Vercel 서버리스), PostgreSQL, Google Gemini AI
- **토스 미니앱**: `toss-miniapp/` — Vite + Vanilla JS
- **배포**: Vercel (`https://backend-ruby-chi-85.vercel.app`)

## 프로젝트 구조
```
lib/
  screens/
    home_screen.dart        # 메인 화면 (상단 포인트/스트릭 + 진행바, region: world 고정)
    news_tab.dart           # 뉴스 카드 스와이프 전용 (좌우/상하 스와이프, 스크롤 없음)
    settings_screen.dart    # 설정 (포인트 화면 이동, 앱정보)
    about_screen.dart       # 앱 정보
    point_screen.dart       # 포인트 잔액/내역/초대/리뷰
    login_screen.dart       # Firebase 로그인
    onboarding_screen.dart  # 최초 온보딩
    bookmark_screen.dart    # 북마크 목록 (로컬 저장)
  services/
    api_service.dart        # 백엔드 API 호출
    settings_service.dart   # 테마·브리핑잠금 (SharedPreferences)
    auth_service.dart       # Firebase Auth 래퍼
    point_service.dart      # 포인트/뽑기/초대 API 호출
    notification_service.dart
    cache_service.dart      # 뉴스 로컬 캐시
    read_service.dart       # 읽은 기사 ID 저장 (최대 300개)
    streak_service.dart     # 완독 스트릭 로컬 기록
    rewarded_ad_service.dart# AdMob 보상형 광고
    bookmark_service.dart   # 북마크 로컬 저장 (SharedPreferences, 중복 방지)
    native_ad_service.dart  # AdMob 네이티브 광고 프리로드 풀
  widgets/
    gacha_dialog.dart       # 뽑기 결과 바텀시트 (폭죽 애니메이션)
    native_ad_card.dart     # 네이티브 광고 풀카드 위젯
  theme/
    jnews_colors.dart       # 컬러 토큰 (DESIGN.md Single Source 참조)
  models/
    news_result.dart
    point_balance.dart      # PointBalance, GachaResult, BadgeTier
    point_history.dart
    referral_info.dart
backend/api/
  news.py    # 뉴스 조회/캐시 (PostgreSQL). 지원 region: us, kr, world
  cron.py    # 정기 뉴스 수집 (Gemini AI)
  points.py  # 포인트/뽑기/초대/리뷰 API
  chat.py    # AI 토론 채팅 (Gemini Flash)
  contact.py
  admin.py
backend/lib/
  db.py         # PostgreSQL 연결 (get_conn)
  gemini.py     # Gemini 호출
  gacha_db.py   # 뽑기 로직 (record_gacha, 친구초대 7일 보너스)
  points_db.py  # 잔액/스트릭/초대 DB
  referral_db.py
toss-miniapp/
  src/main.js   # 뉴스 로직
  index.html
```

## 핵심 규칙

### Flutter — 뉴스 화면
- 뉴스는 **카드 스와이프 전용** (`_currentIndex`, `_goNext`, `_goPrev`). 스크롤 없음.
- **좌우 스와이프**: 이전/다음 카드. **상하 스와이프**: 위=다음, 아래=이전.
- 카드를 전부 넘기면 **완독 화면** (`_showComplete = true`) 진입
- 완독 화면에서 기본 뽑기 자동 실행 (`_onGachaTap`)
- AI 인사이트(마지막 카드)는 **자유 노출** (광고 잠금 제거됨, v1.3.x)
- 카테고리: `general` 하드코딩. 카테고리 선택 UI 없음.
- 지역: `region: 'world'` 고정. 지역 탭 UI 없음.
- Firebase Analytics: 카드 이탈 시 `article_view` (title, region, index, duration_seconds), 완독 시 `news_complete` 이벤트 전송

### Flutter — 포인트/뽑기 (v1.4.x 개편)
- 세션키: `PointBalance.currentSessionKey()` = `{YYYY-MM-DD}_{morning|noon|evening}` (KST 시간 기반)
  - 07:00~11:59 → morning
  - 12:00~17:59 → noon
  - 18:00~23:59 → evening
  - 00:00~06:59 → 전일_evening (새벽은 전날 저녁세션 연장)
- 뉴스 갱신: cron 3회/일 (07/12/18 KST). 각 세션마다 새 7편 + 새 인사이트 1개
- **완독 보너스 (자동)**: 7편 다 보면 +3pt 자동 지급 (세션당 1회). `gacha_db.record_read_bonus()`, `session_key=read_bonus_{YYYY-MM-DD}_{morning|noon|evening}`. UNIQUE 제약으로 중복 방지. 광고 게이트 없음.
- **뽑기 (광고 시청형 추가 보상)**: 완독 화면에 "🎁 광고 보고 뽑기 +4~8pt" 버튼. 사용자가 누르면 `RewardedAdService.show()` → 광고 끝까지 봐야 `doGacha` 호출. 세션당 1회. 4~8pt 랜덤 (티어 무관).
- 출석 스트릭: `StreakService.recordCompletion()` → 완독 시 로컬 기록 (뱃지 emoji/label 표시용으로만 유지, 보상 차등 없음)
- 주간 만근 보너스: **제거됨**. 친구 초대 7일 연속 보너스(50pt)만 유지.
- **포인트 획득 경로**: 완독 보너스(+3pt × 3세션 = 최대 9pt/일), 뽑기(광고 시청 시 4~8pt × 3세션 = 최대 24pt/일), 친구초대 초대받은사람(+50pt), 초대한사람(+50pt, 월2회 한도), 7일출석보너스 초대자(+50pt), 앱리뷰(+50pt, 1회)
- **잭팟 시스템 제거됨** (v1.4.x — 광고 매출 vs 포인트 비용 unit economics 개선 위해 뽑기에 광고 게이트로 흡수).
- **비활성 소멸**: 30일 미접속 시 포인트 전체 삭제 (`check_and_reset_inactive`)
- **인사이트 잠금형 광고**: 제거됨 (v1.3.x — 자유 노출).
- **데일리미션**: 제거됨.
- **기프티콘**: 제거됨 (v1.5.x). 신규 신청 차단. admin.py에 pending 처리 코드만 잔존, 데이터 정리 후 완전 삭제 예정.

### Flutter — 인증/앱 시작
- Firebase Auth (`AuthService.init()`) → 로그인 안 됐으면 `LoginScreen`
- 최초 실행: `onboarding_done` SharedPreferences 키로 `OnboardingScreen` 표시
- 기능 안내: `feature_tour_done` 키로 `FeatureTourScreen` 최초 1회 표시
- 테마: `themeModeNotifier` (ValueNotifier\<ThemeMode\>, main.dart 전역). **기본값 `light`** (시스템 추종 기본 금지 — 다크 첫인상 별로라는 사용자 결정). 설정 화면 테마 타일 (라이트/다크/시스템 다이얼로그) → `SettingsService.saveThemeMode()` (v1.6.x 토글 복구)

### Flutter — AI 튜터 (v1.5.x 신규, 구 "AI 토론")
- 각 뉴스 카드 하단에 "AI 튜터에게 물어보기" 버튼 → `ChatSheet` 바텀시트 (헤더 "AI 튜터" — 카피 통일 v1.6.x)
- `chat_service.dart` → `POST /api/chat` (Gemini Flash). 뉴스 title/body context + history 전달
- 무료/무제한 (광고 게이트 없음). 추후 일 N회 제한 + 보상형 광고 검토

### Flutter — 오디오 브리핑 (v1.5.x 신규)
- 인사이트 카드 + 완독 화면에 "오디오로 듣기" 진입
- `audio_briefing_service.dart` → `flutter_tts` 디바이스 내장 TTS
- 진행자 A(지음, pitch 낮음) / B(소나, pitch 높음) 2인 대화
- 대화 스크립트는 cron에서 미리 Gemini로 생성, `news.dialogue` 컬럼에 저장
- 재생/일시정지/스킵/속도(0.75~1.5x) 컨트롤

### Flutter — 리뷰
- `in_app_review` 패키지로 Google Play 인앱 리뷰 다이얼로그 표시
- 리뷰 완료 여부 확인 불가 → 다이얼로그 노출 시점에 +50pt 지급 (honor system)
- 계정당 1회, `app_reviews` DB 테이블에 기록

### 백엔드
- 뉴스는 **PostgreSQL**에 캐시. 캐시 히트 시 Gemini 호출 안 함.
- 지원 region: `us`, `kr`, `world` (news.py). 앱은 `world`만 사용.
- Vercel 배포: `cd backend && vercel --prod`
- 정적 파일 서빙은 `vercel.json`의 `builds`에 `@vercel/static` 명시 필요
- 어드민: `https://backend-ruby-chi-85.vercel.app/admin`
- `ADMIN_SECRET_KEY` 환경변수 필수 — 없으면 RuntimeError (기본값 없음, 하드코딩 금지)
- `news.py`의 `_safe_json()` 헬퍼: sources 파싱 실패 시 `[]` 반환 (null/malformed JSON 안전 처리)
- **뽑기 race condition 방어**: `point_transactions(user_id, session_key)` UNIQUE 제약 `uq_pt_user_session` — 동시 요청 시 DB 레벨에서 중복 INSERT 거부. `gacha_db.py`에서 `UniqueViolation` catch → ValueError 변환
- **Gemini 프롬프트**: `gemini.py`의 단일 `PROMPT` 문자열 + `FORMAT_INSTRUCTION` 포맷. region/category dict 분기 없음. `SYSTEM_INSTRUCTION` 별도 정의. body 2~3문장, glossary 빈 배열 허용.

### 토스 미니앱
- `brand.icon`은 반드시 절대 URL (`https://backend-ruby-chi-85.vercel.app/icon.png`)
- 빌드: `cd toss-miniapp && npx ait build` → `jnews.ait` 생성 (granite은 deprecated)
- 라이트 모드 전용, 핀치줌 비활성화 (`user-scalable=no`) 유지

## 현재 버전
- Flutter 앱: `1.7.0+25` — **pubspec.yaml 1곳만 수정** (앱 내 버전 표기는 `package_info_plus` 런타임 조회, 하드코딩 제거됨 v1.6.x)

## 광고 구성 (v1.3.0+)
- **네이티브 광고 풀카드** (Android 커스텀 `NativeAdFactory` 구현)
  - `android/app/src/main/res/layout/native_ad_full.xml` — MediaView 큰 영역 + 헤드라인 + 본문 + CTA
  - `android/app/src/main/kotlin/com/briefingnow/app/NativeAdFactoryFull.kt` — 팩토리 구현
  - `MainActivity.kt` 에서 `"fullCard"` factoryId 로 등록
  - Flutter `NativeAd(factoryId: 'fullCard', ...)` 로 생성 → `SizedBox.expand(AdWidget)` 풀스크린
- **광고 슬롯** (news_tab.dart `_adSlotIndices()`):
  - 뉴스 N≥7: 카드 인덱스 {2, 5, 8} → `[n1, n2, AD, n3, n4, AD, n5, n6, AD, n7, insight]` (n6→n7 사이 광고 추가)
  - 뉴스 N≥5: 카드 인덱스 {2, 5} → `[n1, n2, AD, n3, n4, AD, n5, insight]`
  - 뉴스 N=4: 카드 인덱스 {2} → `[n1, n2, AD, n3, n4, insight]`
  - N<4: 광고 없음
- **광고 프리로드 풀** (`native_ad_service.dart`):
  - `_pool` List 최대 3개 + `_loadingCount` 트래킹 (뉴스 7개 시 광고 3개)
  - `main.dart` `MobileAds.initialize()` 직후 `NativeAdService.preload()` 호출
  - `take()` → pop + 즉시 다음 1개 로드 재개

## 주의사항
- `pubspec.yaml` 수정 후 반드시 `flutter pub get`
- 백엔드 배포 전 `icon.png`가 `backend/` 루트에 있는지 확인
- 토스 미니앱 재제출 시 항상 `.ait` 새로 빌드 후 제출
- `SettingsService.allCategories` / `_isCycling` 등 구 카테고리 관련 코드는 이미 제거됨
- `bookmark_screen.dart`는 존재하지만 홈 네비게이션 연결 미완료 (추후 추가 필요)
- 빌드/배포는 사용자가 명시적으로 요청할 때만 실행 (`flutter build`, `vercel --prod`)
- 릴리즈 빌드: `flutter build apk` (디버그 빌드 사용 안 함 — Firebase SHA-1 불일치로 로그인 실패)
- 네이티브 광고 팩토리 변경 시 Android 네이티브 코드 수정 → hot reload 불가, 반드시 `flutter build apk` 재빌드
- **`feature_tour_screen.dart` 완전 제거됨** (v1.3.0) — 온보딩 2번 도는 이슈 수정
- **로그아웃**: `settings_screen.dart` 하단 타일 → `AuthService.signOut()` → `LoginScreen` 푸시 (pushAndRemoveUntil)
- **온보딩 SafeArea**: `SafeArea` 대신 `MediaQuery.viewPadding` 직접 사용 (Stack 내부 SafeArea 가 제대로 적용 안 되는 이슈)
- `notification_service.dart`: `FlutterTimezone.getLocalTimezone()`은 `TimezoneInfo` 반환 — `.identifier`로 문자열 추출 (flutter_timezone 5.x)
- `notification_service.dart`: 배터리 최적화 예외 요청 (`Permission.ignoreBatteryOptimizations`) 제거됨 — 유저에게 무서운 팝업 노출 차단
- `read_service.dart`: 읽은 기사 ID는 URL 전체 문자열 사용 (hashCode 32비트 충돌 위험으로 제거됨)
- `admin.py`: `ADMIN_SECRET_KEY` 기본값 절대 추가 금지 — env var 없으면 서버 시작 시 RuntimeError
- `login_screen.dart` 피처 카드: 흰 배경 + 파란 테마. 이모지 📰🎁🛍️ 3개.
