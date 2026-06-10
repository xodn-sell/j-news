import 'package:flutter/material.dart';

/// J-news 컬러 토큰 — DESIGN.md v1.1.0 기준.
///
/// 사용법:
/// ```dart
/// final c = Theme.of(context).extension<JNewsColors>()!;
/// Container(color: c.accent)
/// ```
///
/// 또는 확장 메서드 `context.jColors` 사용:
/// ```dart
/// Container(color: context.jColors.accent)
/// ```
@immutable
class JNewsColors extends ThemeExtension<JNewsColors> {
  // Brand
  final Color primary;        // #1B2838 — Material ThemeData primary (네이비)
  final Color accent;         // #0052CC — 브랜드 accent (CTA·링크·강조)
  final Color accentLight;    // #4D9EFF
  final Color accentSoft;     // #7EB3FF
  final Color accentDeep;     // #0D2060

  // Text
  final Color textPrimary;    // #0D1117
  final Color textBody;       // #2D2D2D
  final Color textMuted;      // #424242
  final Color textInverse;    // #FFFFFF

  // Surface
  final Color surfaceBase;        // #FBFBFE
  final Color surfaceElevated;    // #FFFFFF
  final Color surfaceAlt;         // #F5F6FA
  final Color surfaceTint;        // #EEF4FF
  final Color surfaceTintDeep;    // #E8F0FF

  // Border
  final Color borderSoft;     // accent 10%
  final Color borderHair;     // accent 6%

  // State
  final Color success;        // #34C759
  final Color warning;        // #FFC107
  final Color error;          // #FF3B30
  final Color errorAlt;       // #E53935

  const JNewsColors({
    required this.primary,
    required this.accent,
    required this.accentLight,
    required this.accentSoft,
    required this.accentDeep,
    required this.textPrimary,
    required this.textBody,
    required this.textMuted,
    required this.textInverse,
    required this.surfaceBase,
    required this.surfaceElevated,
    required this.surfaceAlt,
    required this.surfaceTint,
    required this.surfaceTintDeep,
    required this.borderSoft,
    required this.borderHair,
    required this.success,
    required this.warning,
    required this.error,
    required this.errorAlt,
  });

  /// Light 테마 토큰 (DESIGN.md v1.1.0 light 섹션 미러).
  static const JNewsColors light = JNewsColors(
    primary: Color(0xFF1B2838),
    accent: Color(0xFF0052CC),
    accentLight: Color(0xFF4D9EFF),
    accentSoft: Color(0xFF7EB3FF),
    accentDeep: Color(0xFF0D2060),
    textPrimary: Color(0xFF0D1117),
    textBody: Color(0xFF2D2D2D),
    textMuted: Color(0xFF424242),
    textInverse: Color(0xFFFFFFFF),
    surfaceBase: Color(0xFFFBFBFE),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF5F6FA),
    surfaceTint: Color(0xFFEEF4FF),
    surfaceTintDeep: Color(0xFFE8F0FF),
    borderSoft: Color(0x1A0052CC),     // accent 10%
    borderHair: Color(0x0F0052CC),     // accent 6%
    success: Color(0xFF34C759),
    warning: Color(0xFFFFC107),
    error: Color(0xFFFF3B30),
    errorAlt: Color(0xFFE53935),
  );

  /// Dark 테마 토큰 (DESIGN.md v1.1.0 dark 섹션 미러).
  static const JNewsColors dark = JNewsColors(
    primary: Color(0xFF8AB4F8),
    accent: Color(0xFF4A90D9),
    accentLight: Color(0xFF7EB3FF),
    accentSoft: Color(0xFF7EB3FF),
    accentDeep: Color(0xFF0D2060),
    textPrimary: Color(0xFFFFFFFF),
    textBody: Color(0xFFE5E7EB),
    textMuted: Color(0xFF9CA3AF),
    textInverse: Color(0xFF0F1115),
    surfaceBase: Color(0xFF0F1115),
    surfaceElevated: Color(0xFF252830),
    surfaceAlt: Color(0xFF1C2128),
    surfaceTint: Color(0xFF1C1F26),
    surfaceTintDeep: Color(0xFF0F1115),
    borderSoft: Color(0x1AFFFFFF),
    borderHair: Color(0x0FFFFFFF),
    success: Color(0xFF34C759),
    warning: Color(0xFFFFC107),
    error: Color(0xFFFF3B30),
    errorAlt: Color(0xFFE53935),
  );

  @override
  JNewsColors copyWith({
    Color? primary,
    Color? accent,
    Color? accentLight,
    Color? accentSoft,
    Color? accentDeep,
    Color? textPrimary,
    Color? textBody,
    Color? textMuted,
    Color? textInverse,
    Color? surfaceBase,
    Color? surfaceElevated,
    Color? surfaceAlt,
    Color? surfaceTint,
    Color? surfaceTintDeep,
    Color? borderSoft,
    Color? borderHair,
    Color? success,
    Color? warning,
    Color? error,
    Color? errorAlt,
  }) {
    return JNewsColors(
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      accentLight: accentLight ?? this.accentLight,
      accentSoft: accentSoft ?? this.accentSoft,
      accentDeep: accentDeep ?? this.accentDeep,
      textPrimary: textPrimary ?? this.textPrimary,
      textBody: textBody ?? this.textBody,
      textMuted: textMuted ?? this.textMuted,
      textInverse: textInverse ?? this.textInverse,
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceTint: surfaceTint ?? this.surfaceTint,
      surfaceTintDeep: surfaceTintDeep ?? this.surfaceTintDeep,
      borderSoft: borderSoft ?? this.borderSoft,
      borderHair: borderHair ?? this.borderHair,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      errorAlt: errorAlt ?? this.errorAlt,
    );
  }

  @override
  JNewsColors lerp(ThemeExtension<JNewsColors>? other, double t) {
    if (other is! JNewsColors) return this;
    return JNewsColors(
      primary: Color.lerp(primary, other.primary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentLight: Color.lerp(accentLight, other.accentLight, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textBody: Color.lerp(textBody, other.textBody, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textInverse: Color.lerp(textInverse, other.textInverse, t)!,
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceTint: Color.lerp(surfaceTint, other.surfaceTint, t)!,
      surfaceTintDeep: Color.lerp(surfaceTintDeep, other.surfaceTintDeep, t)!,
      borderSoft: Color.lerp(borderSoft, other.borderSoft, t)!,
      borderHair: Color.lerp(borderHair, other.borderHair, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorAlt: Color.lerp(errorAlt, other.errorAlt, t)!,
    );
  }
}

/// `context.jColors` 짧은 접근.
extension JNewsColorsContext on BuildContext {
  JNewsColors get jColors =>
      Theme.of(this).extension<JNewsColors>() ?? JNewsColors.light;
}
