# 지음뉴스 (J-news) — Claude Code 프로젝트 가이드

## 디자인 시스템
**UI/디자인 작업 시 `DESIGN.md`를 Single Source of Truth로 반드시 참조.**
색상·폰트·radius·spacing·컴포넌트 규칙은 DESIGN.md에 정의. 하드코딩 금지, `Theme.of(context)` 경유.
신규 컴포넌트 추가 시 DESIGN.md의 `components` 섹션 먼저 업데이트.

## 프로젝트 개요
"뉴스를 보고 싶지만 뭘 봐야 할지 모르는 사람들"을 위한 AI 뉴스 큐레이션 앱.
글로벌 뉴스를 AI 브리핑 (general 단일 카테고리, region: world 고정). Flutter 앱 + 토스 미니앱 + Python/Vercel 백엔드.

**제품 방향 (v2.x)**: 포인트/뽑기 게이미피케이션 **제거 완료** → 학습 루프(읽기·묻기·풀기)로 리텐션 엔진 전환 중.
단계별 계획·진척은 `LEARNING_PIVOT.md` 참조. 현재 "시사 배경지식 리터러시" 축 = 개념 추적 레이어 구축·배포됨.

## 기술 스택
- **Flutter 앱**: `lib/` — Android/iOS, 다크/라이트/시스템 테마, Firebase Auth, Google AdMob(네이티브 광고)
- **백엔드**: `backend/api/` — Python (Vercel 서버리스), PostgreSQL, Google Gemini AI
- **토스 미니앱**: `toss-miniapp/` — Vite + Vanilla JS
- **배포**: Vercel (`https://backend-ruby-chi-85.vercel.app`)

## 프로젝트 구조
```
lib/
  screens/
    home_screen.dart        # 메인 화면 (region: world 고정)
    news_tab.dart           # 뉴스 카드 스와이프 전용 (좌우/상하 스와이프, 스크롤 없음) + 완독화면 + A/B viz
    quiz_screen.dart        # 완독 후 오늘의 퀴즈 (O/X·4지선다, 해설)
    review_screen.dart      # SRS 복습 (Leitner 플래시카드)
    chat_sheet.dart         # AI 튜터 바텀시트
    audio_briefing_screen.dart # 오디오 브리핑 (2인 TTS 대화)
    settings_screen.dart    # 설정 (테마, 앱정보, 로그아웃)
    about_screen.dart       # 앱 정보
    login_screen.dart       # Firebase 로그인
    onboarding_screen.dart  # 최초 온보딩
    bookmark_screen.dart    # 북마크 목록 (로컬 저장, 홈 연결 미완료)
  services/
    api_service.dart        # 뉴스 API 호출
    concept_service.dart    # 개념 학습 — exposure/review/progress (서버 /api/concepts)
    ab_service.dart         # A/B 코호트 분배 (FNV-1a 결정적 50/50, viz on/off)
    quiz_service.dart       # 세션 퀴즈 구성 + 시도 로컬 기록
    review_service.dart     # SRS 복습 카드 (Leitner 5단계, 로컬 SharedPreferences)
    chat_service.dart       # AI 튜터 API 호출 (일일 한도)
    audio_briefing_service.dart # flutter_tts 디바이스 TTS
    auth_service.dart       # Firebase Auth 래퍼 (AuthService.uid)
    settings_service.dart   # 테마 (SharedPreferences)
    notification_service.dart
    cache_service.dart      # 뉴스 로컬 캐시
    read_service.dart       # 읽은 기사 ID 저장 (URL 전체 문자열, 최대 300개)
    streak_service.dart     # 완독 스트릭 로컬 기록 (보상 차등 없음, 표시용)
    bookmark_service.dart   # 북마크 로컬 저장
    native_ad_service.dart  # AdMob 네이티브 광고 프리로드 풀
    news_session.dart       # 세션 관련 헬퍼
  widgets/
    concept_progress_card.dart # 완독화면 개념 진척 viz (A군만 노출)
    achievement_summary.dart   # 퀴즈 결과 공용 위젯
    native_ad_card.dart        # 네이티브 광고 풀카드
  theme/
    jnews_colors.dart       # 컬러 토큰 (DESIGN.md Single Source 참조)
  models/
    news_result.dart        # NewsItem·QuizQuestion·Concept·InsightData·DialogueTurn 등
backend/api/
  news.py     # 뉴스 조회/캐시 (PostgreSQL). 페이로드에 concepts[] 동봉(fail-soft)
  cron.py     # 정기 뉴스 수집 (Gemini AI) — 개념 추출 포함
  concepts.py # 개념 학습 엔드포인트 (exposure/review/progress)
  chat.py     # AI 튜터 채팅 (Gemini Flash, 일일 한도)
  admin.py    # 어드민 통계 + 개념 백필 (backfill_concepts/concepts_stats)
  contact.py
backend/lib/
  db.py         # PostgreSQL 연결 (get_conn), news 저장/조회, chat_usage
  gemini.py     # Gemini 호출 (뉴스 생성 + dialogue + 개념 추출)
  concepts_db.py# 개념 학습 3테이블 + SRS 로직
```
> 참고: 포인트/뽑기/리뷰보상/기프티콘/친구초대 관련 코드(point_*, gacha_*, points_db, referral_*, rewarded_ad, in_app_review)는 **전부 제거됨**. `__pycache__`에 고아 .pyc만 잔존(무해).

## 핵심 규칙

### Flutter — 뉴스 화면
- 뉴스는 **카드 스와이프 전용** (`_currentIndex`, `_goNext`, `_goPrev`). 스크롤 없음.
- **좌우 스와이프**: 이전/다음 카드. **상하 스와이프**: 위=다음, 아래=이전.
- 카드를 전부 넘기면 **완독 화면** (`_showComplete = true`) 진입
- 완독 화면: 개념 진척 viz(A군) → 오늘의 퀴즈 CTA → 공유 → 오디오 브리핑(dialogue 있을 때)
- AI 인사이트(마지막 카드)는 자유 노출
- 카테고리: `general` 하드코딩. 카테고리 선택 UI 없음.
- 지역: `region: 'world'` 고정. 지역 탭 UI 없음.
- Firebase Analytics: 카드 이탈 시 `article_view`, 완독 시 `news_complete`(ab_cohort 포함) 이벤트 전송

### Flutter — 학습 루프 (개념 리터러시)
- **학습 단위 = 정규화 개념** (인물·기관·사건·지명·용어). cron이 뉴스에서 추출, news 페이로드 `concepts[]`로 공급.
- **노출(패시브)**: 카드 보면 `ConceptService.recordExposure` (세션 dedupe, UI 비차단). "만난 개념" 카운트.
- **퀴즈(액티브)**: 완독 후 `quiz_screen`. 정답확인 시 `ConceptService.recordReview(conceptId, correct)` → 서버 Leitner 승급(정답)/리셋(오답).
- **로컬 SRS**: `review_service.dart` Leitner 5단계(1→3→7→14→30일), 퀴즈 문항 기반, SharedPreferences. 서버 개념 mastery와 별개로 유지.
- **진척 viz**: `concept_progress_card.dart` — 만난 개념/습득/학습중 + 도메인 mastery bar. 완독화면 노출.
- 완독 시 `StreakService.recordCompletion()` 로컬 스트릭 기록 (표시용, 보상 차등 없음).

### Flutter — A/B 검증 (viz on/off)
- **목적**: 개념 진척 viz가 리텐션을 올리나. A=viz ON(처치), B=viz OFF(대조=viz 추가 전 동작).
- `AbService.cohort(uid)` = FNV-1a 32bit 해시 % 2 → 'A'/'B'. **uid 기반 결정적 50/50**. Python 서버와 동일 알고리즘.
- viz 게이트: `AbService.vizEnabled(AuthService.uid)` true(A군)일 때만 진척 카드 노출. **데이터(exposure/review)는 양 군 모두 기록** — 표시만 차등.
- Firebase user property `ab_cohort` 1회 설정(`news_tab` initState) + `news_complete` 이벤트에 cohort 태깅 → 리텐션 세그먼트.
- **게이트 지표**: D7/D14 세션 복귀율, 2주 코호트. 가드레일: B 대비 완독률 -20%면 롤백.

### Flutter — 인증/앱 시작
- Firebase Auth (`AuthService.init()`) → 로그인 안 됐으면 `LoginScreen`. `AuthService.uid`로 식별.
- 최초 실행: `onboarding_done` SharedPreferences 키로 `OnboardingScreen` 표시
- 테마: `themeModeNotifier` (ValueNotifier\<ThemeMode\>, main.dart 전역). **기본값 `light`** (시스템 추종 기본 금지 — 다크 첫인상 별로라는 사용자 결정). 설정 화면 테마 타일 → `SettingsService.saveThemeMode()`

### Flutter — AI 튜터
- 각 뉴스 카드 하단 "AI 튜터에게 물어보기" → `ChatSheet` 바텀시트 (헤더 "AI 튜터")
- `chat_service.dart` → `POST /api/chat` (Gemini Flash). 뉴스 title/body context + history 전달. 일일 한도(서버 `chat_usage`).

### Flutter — 오디오 브리핑
- 인사이트 카드 + 완독 화면에 "오디오로 듣기" 진입
- `audio_briefing_service.dart` → `flutter_tts` 디바이스 내장 TTS. 진행자 A(지음)/B(소나) 2인 대화.
- 대화 스크립트는 cron에서 Gemini로 생성, `news.dialogue` 컬럼 저장. 재생/일시정지/스킵/속도(0.75~1.5x).

### 백엔드
- 뉴스는 **PostgreSQL**에 캐시. 캐시 히트 시 Gemini 호출 안 함.
- 지원 region: `us`, `kr`, `world` (news.py). 앱은 `world`만 사용.
- Vercel 배포: `cd backend && vercel --prod`
- 어드민: `https://backend-ruby-chi-85.vercel.app/admin`. `ADMIN_SECRET_KEY` 환경변수 필수 — 없으면 RuntimeError (기본값 없음). 인증: `X-Admin-Key` 헤더 또는 `?key=` (시크릿은 헤더 권장 — URL 쿼리 로그 노출 회피).
- `news.py`의 `_safe_json()` / `_parse_summary_value()`: sources/summary 파싱 실패 안전 처리.
- **Gemini 프롬프트**: `gemini.py`의 `PROMPT` + `FORMAT_INSTRUCTION`. body 2~3문장, glossary/quiz/why_matters/suggested_questions 포함. `SYSTEM_INSTRUCTION` 별도.
- **개념 추출**: cron `fetch_and_store` 끝에서 `extract_and_store_concepts` 호출 (별도 Gemini 콜 1회, `{concepts, quiz_links}` 반환). slug UNIQUE dedup, quiz 문항에 `concept_ids` 위치기반 주입 후 summary 재저장. 실패해도 뉴스 저장 무영향(fail-soft).
- **개념 DB** (`concepts_db.py`): `concepts`(slug UNIQUE) / `concept_occurrences`((concept_id,news_id,title) UNIQUE) / `user_concept_mastery`(PK user_id+concept_id, Leitner stage 0~5). 전부 `init_concepts_db()` 멱등 생성.
- **소급 태깅**: `GET /api/admin?action=backfill_concepts&limit=N` (멱등, news_id NOT IN occurrences). `action=concepts_stats`로 현황. **주의**: 뉴스당 Gemini 1콜 비용 — 앱은 최신 world/general만 노출하므로 전량 백필 불필요, cron이 신규 자동 태깅.

### 토스 미니앱
- `brand.icon`은 반드시 절대 URL (`https://backend-ruby-chi-85.vercel.app/icon.png`)
- 빌드: `cd toss-miniapp && npx ait build` → `jnews.ait` 생성 (granite은 deprecated)
- 라이트 모드 전용, 핀치줌 비활성화 (`user-scalable=no`) 유지

## 현재 버전
- Flutter 앱: `1.7.0+25` — **pubspec.yaml 1곳만 수정** (앱 내 버전 표기는 `package_info_plus` 런타임 조회)

## 광고 구성
- **네이티브 광고 풀카드** (Android 커스텀 `NativeAdFactory`)
  - `android/app/src/main/res/layout/native_ad_full.xml`, `NativeAdFactoryFull.kt`, `MainActivity.kt`에서 `"fullCard"` factoryId 등록
  - Flutter `NativeAd(factoryId: 'fullCard')` → `SizedBox.expand(AdWidget)` 풀스크린
- **광고 슬롯** (`news_tab.dart` `_adSlotIndices()`): 뉴스 N≥7 → {2,5,8}, N≥5 → {2,5}, N=4 → {2}, N<4 → 없음
- **프리로드 풀** (`native_ad_service.dart`): 최대 3개. `main.dart` `MobileAds.initialize()` 직후 `preload()`. `take()` → pop + 다음 1개 로드.

## 주의사항
- `pubspec.yaml` 수정 후 반드시 `flutter pub get`
- 백엔드 배포 전 `icon.png`가 `backend/` 루트에 있는지 확인
- 토스 미니앱 재제출 시 항상 `.ait` 새로 빌드 후 제출
- 빌드/배포는 사용자가 명시적으로 요청할 때만 실행 (`flutter build`, `vercel --prod`)
- 릴리즈 빌드: `flutter build apk` (디버그 빌드 사용 안 함 — Firebase SHA-1 불일치로 로그인 실패)
- 네이티브 광고 팩토리 변경 시 Android 네이티브 코드 수정 → hot reload 불가, 반드시 `flutter build apk` 재빌드
- **로그아웃**: `settings_screen.dart` → `AuthService.signOut()` → `LoginScreen` (pushAndRemoveUntil)
- **온보딩 SafeArea**: `SafeArea` 대신 `MediaQuery.viewPadding` 직접 사용 (Stack 내부 SafeArea 미적용 이슈)
- `notification_service.dart`: `FlutterTimezone.getLocalTimezone()`은 `TimezoneInfo` 반환 — `.identifier`로 추출 (flutter_timezone 5.x). 배터리 최적화 예외 요청 제거됨.
- `read_service.dart`: 읽은 기사 ID는 URL 전체 문자열 사용 (hashCode 32비트 충돌 위험으로 제거됨)
- `admin.py`: `ADMIN_SECRET_KEY` 기본값 절대 추가 금지 — env var 없으면 서버 시작 시 RuntimeError
- `bookmark_screen.dart`는 존재하지만 홈 네비게이션 연결 미완료 (추후 추가 필요)
- 한글 파일 PowerShell 텍스트 치환 금지 (인코딩 파괴). Edit/Write 도구 사용.
