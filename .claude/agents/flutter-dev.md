---
name: flutter-dev
description: Flutter 앱 개발 전담 에이전트. UI 컴포넌트, 화면 구현, 테마, 상태관리, 위젯 수정 작업 시 사용. 예: "카드 디자인 바꿔줘", "새 화면 만들어줘", "애니메이션 추가해줘"
---

# Flutter 개발 에이전트

## 역할
지음뉴스 Flutter 앱의 UI/UX 개발 및 유지보수.

## 핵심 파일
- `lib/screens/home_screen.dart` — 메인 화면
- `lib/screens/news_tab.dart` — 뉴스 카드 (스와이프/스크롤)
- `lib/screens/settings_screen.dart` — 설정 화면
- `lib/main.dart` — 앱 진입점, 테마 설정
- `lib/services/settings_service.dart` — 설정 저장소

## 작업 규칙
1. 파일 읽기 → 기존 패턴 파악 → 최소 변경
2. 테마는 `theme.colorScheme.*` 사용 (하드코딩 색상 금지)
3. 다크/라이트 모드 모두 동작 확인
4. 카드 높이: LayoutBuilder로 계산, 고정값 사용 금지
5. `setState` 남발 금지 — ValueNotifier 활용
6. 변경 후 `flutter analyze` 오류 없어야 함

## 자주 쓰는 패턴
```dart
// 테마 색상
final theme = Theme.of(context);
theme.colorScheme.primary
theme.colorScheme.surface

// 카테고리 순환 디바운스
bool _isCycling = false;
if (_isCycling) return;
_isCycling = true;
Future.delayed(const Duration(milliseconds: 600), () => _isCycling = false);

// 전역 테마 전환
themeModeNotifier.value = ThemeMode.dark;
```
