# 지음뉴스 v2.0 — "뉴스로 배우는 학습 앱" 전환 계획

> 포인트/뽑기 게이미피케이션 제거 → 학습 루프(읽기·묻기·풀기)로 리텐션 엔진 교체.
> 광고 수익화 보류. 가역적·단계적 전환(대체 먼저, 제거 마지막).

## 제품 재정의
- AS-IS: 뉴스 소비 + 포인트/뽑기 외재적 보상 루프
- TO-BE: 뉴스 학습 + 내재적 가치 루프 (읽기 → 이해 → 질문 → 검증 → 복습 → 성장 실감)
- 핵심 루프: **읽기(맥락 깊게) → 묻기(AI 튜터) → 풀기(퀴즈/복습)**
- "왜 매일 오나?" 답: 간격 반복(SRS) — "오늘 복습할 카드 N개". FOMO(벌) 아닌 positive pull(기회).

## 3대 기능

### A. 맥락/배경 (Context Layer)
- Gemini가 뉴스마다 생성: `why_matters`(왜 중요, 2~3문장), `glossary`(용어+뜻+예시, 현재 빈배열→채움), `background`(배경 3~5문장). v2: why_matters+glossary 먼저, background는 hallucination 검수 후.
- UI: 카드에 "📖 맥락·용어 더 알아보기" 단일 진입 행 → **별도 바텀시트**(인라인 펼침 X, 스와이프 제스처 충돌 회피). glossary 칩은 시트로 흡수.

### B. AI 튜터 (ChatSheet 강화)
- "토론" → "튜터" 카피 통일. 무료 무제한 유지.
- 추천 질문 칩 항상 노출(쉽게 설명 / 왜 중요 / 찬반 / 과거 사례). cron에서 뉴스별 생성 or 고정 세트.
- 답변 하단 **후속 칩**(더 자세히 / 예시 / 결론은?) — 대화 깊이 차별점.
- 소크라테스식 시스템 프롬프트(답변 후 후속 질문 1개, 3턴 후 요약 마무리).

### C. 퀴즈/복습 (SRS) — 리텐션 핵심
- cron에서 뉴스 본문 기반 퀴즈 생성. 기사당 2문제, 세션당 3~4문항. 유형: O/X, 4지선다, 용어매칭.
- 완독 화면의 **뽑기 자동실행 → "오늘의 퀴즈"로 교체**. 정답/오답 피드백 + 해설.
- 간격 반복: Leitner 5단계(1→3→7→14→30일). 정답=다음단계, 오답=1단계 리셋. 최대 30일(뉴스 시의성). 로컬 계산(`review_service.dart`).
- 복습 탭 신설: "오늘 복습할 카드" + 플래시카드(앞=회상, 뒤=확인, "기억났어요/다시 볼래요" 좌우 스와이프 재활용).
- 성취 표현(포인트 없이): 정답률 display 타이포, "오늘 배운 것" 누적 카드(읽음/맞힘/용어/연속일), 학습 스트릭(🔥, 보상 차등 없음), 학습 캘린더 히트맵, 마스터 카운트.

## 네비게이션 재구성
- 홈 상단 포인트칩/뱃지 제거 → "오늘의 학습 현황" 미니지표(📰7 🧠3 🔥12일째).
- 하단 3탭 신설: **브리핑 / 복습 / 나**. 복습 탭 due 도트 = 재방문 트리거(포인트 알림 대체).
- "나" 탭 = 설정 + 학습 통계 (point_screen 자리 대체).

## 디자인 톤
- DESIGN.md 섹션8 "Gamified Rewards" 폐기 → **Editorial 단일 톤**. 컨페티/큰숫자폭발/elasticOut 금지. 성취 피드백 200ms fade 이내.
- 신규 컴포넌트 7종 DESIGN.md 등록: contextEntryRow, quizChoice, srsProgressBar, dueDateChip, tutorChip, achievementCard, reviewFlashCard.
- accent #0052CC 단일. 정답=success #34C759, 오답=error #FF3B30(state만 예외).

## 단계별 실행 (대체 먼저 → 제거 마지막)

| Phase | 내용 | 포인트 상태 | 의존성 |
|---|---|---|---|
| **0. 데이터** | gemini.py 프롬프트 확장(context+퀴즈), DB 스키마(news 컬럼 or news_context + quiz_items), cron 검증 | 유지 | 없음 |
| **1. Context+퀴즈** | 카드 "더 알아보기" 시트, 완독→퀴즈 교체, 로컬 quiz_attempts, SRS 로직, 온보딩 카피 | 공존 | P0 |
| **2. 복습+튜터+대시보드** | 복습 탭, 홈 학습 헤더, 캘린더, 튜터 칩+후속칩, 푸시 카피("복습 N개") | 홈에서 숨김, 설정에만 | P1 배포+3일 |
| **3. 포인트 제거** | point_screen/point_service/gacha_dialog/rewarded_ad 제거, /api/points·gacha_db·points_db 비활성, 광고 슬롯 제거, referral 비활성(데이터 보존) | **완전 제거** | P2 배포+2주 데이터 Go/No-Go |
| **4. 심화** | background/related_events 품질검수 후 추가, perspective, 소셜 퀴즈 대결(바이럴 재설계), 수익화 재설계(프리미엄 구독) | - | - |

## 포인트 제거 영향 (빈 구멍 점검)
| 포인트 역할 | 대체 | 리스크 |
|---|---|---|
| 완독 동기(+3pt) | 퀴즈 연결 → 주의깊게 읽기 | 낮음 |
| 매일 복귀(뽑기 FOMO) | SRS 복습 알림 | 중간(Day1~2 복습 0개) → Day1 의도적 어려운 1문제로 Day2 훅 |
| 성취감(잔액) | 스트릭+마스터+캘린더 | 낮음(잔액 사용처 이미 없음) |
| 초대 인센티브(+50pt) | **대체 없음** | 높음 → P3에서 소셜 퀴즈로 재설계 |

## 성공 지표
- Primary: D7 리텐션(포인트 시절 동등+), 일 복습 완료율 60%+, 완독률 70%+
- Secondary: context 열람율 30%+, 튜터 대화율 15%+, 퀴즈 정답률 상승추세, 스트릭 중앙값 5일+
- Guardrail: DAU 2주 -20%면 P3 보류, 세션시간 -30%면 context UX 개선, 완독률 -20%면 퀴즈 옵셔널화
- 신규 이벤트: context_viewed, quiz_attempted, quiz_session_complete, review_completed, tutor_chip_tapped, master_achieved

## 신규/제거 파일
- 신규: `lib/screens/review_screen.dart`, `lib/screens/quiz_screen.dart`, `lib/services/review_service.dart`, `lib/services/quiz_service.dart`
- 수정: `news_tab.dart`(더알아보기 행+퀴즈 교체), `chat_sheet.dart`(튜터칩), `home_screen.dart`(포인트바 제거+학습헤더+하단탭), `news_result.dart`(whyMatters/background/quiz), `backend/lib/gemini.py`, `backend/api/cron.py`, `backend/api/news.py`, `DESIGN.md`
- 제거(P3): `point_service.dart`, `gacha_dialog.dart`, `rewarded_ad_service.dart`, `point_screen.dart`, `backend/api/points.py`, `backend/lib/gacha_db.py`, `backend/lib/points_db.py`

## 작업 운용
- 구현 작업 = **sonnet 에이전트**(flutter-dev / backend-dev) 분담.
- 총괄·계획·통합·리뷰 = **opus**(메인).
