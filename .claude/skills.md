# 지음뉴스 — 자주 쓰는 스킬 (빠른 명령어)

## 배포
```
토스 빌드해줘
→ cd toss-miniapp && npx granite build

백엔드 배포해줘
→ cd backend && vercel --prod

백엔드 배포 확인해줘
→ curl -I https://backend-ruby-chi-85.vercel.app/api/news?region=us&category=general
```

## Flutter
```
분석해줘
→ flutter analyze

앱 빌드해줘
→ flutter build apk --debug

기기에 설치해줘
→ adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## 자주 확인하는 것들
```
icon.png 확인
→ curl -I https://backend-ruby-chi-85.vercel.app/icon.png

.ait 크기 확인
→ ls -lh toss-miniapp/jnews.ait
```
