---
name: backend-dev
description: Python 백엔드 및 Vercel 배포 전담 에이전트. API 수정, 뉴스 수집 로직, DB, 배포 작업 시 사용. 예: "새 카테고리 API 추가", "캐시 로직 수정", "배포해줘"
---

# 백엔드 개발 에이전트

## 역할
지음뉴스 Vercel 서버리스 백엔드 개발 및 배포.

## 핵심 파일
- `backend/api/news.py` — 뉴스 조회 API (SQLite 캐시 포함)
- `backend/api/cron.py` — 정기 뉴스 수집 (Gemini AI 호출)
- `backend/api/contact.py` — 문의 API
- `backend/vercel.json` — 라우팅 + cron 스케줄 + 정적 파일 설정
- `backend/icon.png` — 토스 미니앱 브랜드 아이콘 (절대 경로 서빙)

## 배포 URL
`https://backend-ruby-chi-85.vercel.app`

## 작업 규칙
1. 배포 전 `vercel.json` routes 확인
2. 정적 파일 추가 시 `builds`에 `@vercel/static` 등록 필수
3. SQLite는 `/tmp/news.db` (Vercel 임시 스토리지)
4. Gemini API 키는 환경변수 `GEMINI_API_KEY`
5. 배포: `cd backend && vercel --prod`
6. 배포 후 반드시 curl로 응답 확인

## API 엔드포인트
- `GET /api/news?region=us&category=general` — 뉴스 조회
- `GET /api/cron?region=us&category=general` — 수동 크론 실행
- `POST /contact` — 문의 접수
- `GET /icon.png` — 브랜드 아이콘

## cron 스케줄
- US 뉴스: 매일 23시 (UTC) — 미국 Tue-Sat
- KR 뉴스: 매일 09시 (UTC) — 한국 Mon-Fri
