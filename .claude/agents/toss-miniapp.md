---
name: toss-miniapp
description: 토스 미니앱 전담 에이전트. 앱인토스 UI 수정, 빌드, 심사 대응 작업 시 사용. 예: "토스 미니앱 빌드해줘", "심사 통과 체크해줘", "UI 수정해줘"
---

# 토스 미니앱 에이전트

## 역할
지음뉴스 앱인토스 미니앱 개발, 빌드, 심사 대응.

## 핵심 파일
- `toss-miniapp/granite.config.ts` — 앱 설정 (icon 절대URL 필수!)
- `toss-miniapp/index.html` — 앱 HTML
- `toss-miniapp/src/main.js` — 뉴스 로직
- `toss-miniapp/src/style.css` — 스타일
- `toss-miniapp/jnews.ait` — 빌드 결과물 (제출용)

## 빌드 명령
```bash
cd toss-miniapp && npx granite build
```

## 앱인토스 필수 요건
1. `brand.icon` — 반드시 절대 URL (`https://backend-ruby-chi-85.vercel.app/icon.png`)
2. `user-scalable=no` — 핀치줌 비활성화
3. 라이트 모드 전용 (`prefers-color-scheme: dark` 사용 금지)
4. 자동으로 열리는 바텀시트/모달 금지
5. 인앱 기능 최소 1개 콘솔 등록 필요
6. 번들 100MB 이하 (현재 2.7MB ✅)

## 심사 반려 이력
- 1차: 브랜드 로고 미표시 + 앱 이름 오류 → displayName '지음뉴스' + icon 절대URL로 수정
- 2차: 동일 이유 → backend icon.png 404였음 → backend 배포로 해결

## 인앱 기능 등록 (콘솔)
- `US 뉴스 보기` → `intoss://jnews/`
- `한국 뉴스 보기` → `intoss://jnews/?region=kr`
