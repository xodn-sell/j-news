# 지음뉴스 — 에이전트 오케스트레이션 가이드

## 어떤 에이전트를 언제 쓸까?

| 요청 유형 | 에이전트 |
|-----------|---------|
| Flutter UI 수정, 화면 추가, 애니메이션 | `flutter-dev` |
| API 수정, DB, 뉴스 수집 로직, Vercel 배포 | `backend-dev` |
| 토스 미니앱 빌드/수정/심사 대응 | `toss-miniapp` |
| 사업계획서, 공모 신청, 기획, 시장조사 | `product` |

## 자주 쓰는 조합

### 새 카테고리 추가
1. `backend-dev` — `cron.py` + `news.py` 에 카테고리 추가
2. `flutter-dev` — `SettingsService.allCategories` + `_categoryMeta` 업데이트
3. `toss-miniapp` — `index.html` 칩 추가 후 재빌드

### 토스 미니앱 심사 재제출
1. `backend-dev` — 필요 시 백엔드 수정 + `vercel --prod`
2. `toss-miniapp` — `npx granite build` → `.ait` 제출

### KPF 신청서 작성
1. `product` — 문서 초안
2. `flutter-dev` — 스크린샷/시연 준비

## 병렬 실행 가능한 작업
- Flutter UI 수정 ↔ 백엔드 API 수정 (독립적)
- 토스 미니앱 빌드 ↔ KPF 문서 작성 (독립적)
