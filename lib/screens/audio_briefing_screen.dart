import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../models/news_result.dart';
import '../services/audio_briefing_service.dart';
import '../theme/jnews_colors.dart';

class AudioBriefingScreen extends StatefulWidget {
  final List<DialogueTurn> dialogue;
  final String headline;

  const AudioBriefingScreen({
    super.key,
    required this.dialogue,
    required this.headline,
  });

  @override
  State<AudioBriefingScreen> createState() => _AudioBriefingScreenState();
}

class _AudioBriefingScreenState extends State<AudioBriefingScreen> {
  late final AudioBriefingService _service;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _service = AudioBriefingService();
    _service.loadDialogue(widget.dialogue);
    _service.addListener(_onServiceChanged);
    FirebaseAnalytics.instance.logEvent(name: 'audio_briefing_opened', parameters: {
      'turns': widget.dialogue.length,
    });
    // 자동 재생
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _service.play();
    });
  }

  void _onServiceChanged() {
    if (!mounted) return;
    setState(() {});
    _scrollToCurrent();
  }

  void _scrollToCurrent() {
    if (!_scrollController.hasClients) return;
    final idx = _service.currentIndex;
    final target = (idx * 80.0).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _service.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = context.jColors;
    // `:68` 라이트 bg → surfaceBase 토큰 경유 (Colors.white 하드코딩 제거)
    final bg = c.surfaceBase;

    if (widget.dialogue.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('오디오 브리핑')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '아직 오디오 브리핑이 준비되지 않았어요.\n다음 세션에 다시 와주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('오디오 브리핑', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 헤드라인
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                Text(
                  widget.headline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: isDark ? c.textPrimary : c.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '지음 & 소나 · ${widget.dialogue.length}개 발화',
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // 대화 스크립트 (현재 발화 하이라이트)
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: widget.dialogue.length,
              itemBuilder: (_, i) {
                final turn = widget.dialogue[i];
                final isCurrent = i == _service.currentIndex;
                final isA = turn.speaker == 'A';
                // `:131` 소나 색 #E91E63 핑크 제거 — "채도 높은 보조색 금지"(DESIGN.md §7)
                // 화자 구분: A=accent(브랜드 블루), B=accentDeep(명도 차 대비)
                final accent = isA ? c.accent : c.accentDeep;
                final name = isA ? '지음' : '소나';

                return InkWell(
                  onTap: () => _service.seekTo(i),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? accent.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isCurrent ? Border.all(color: accent.withValues(alpha: 0.3)) : null,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: isCurrent ? 1.0 : 0.6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              isA ? 'A' : 'B',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: accent,
                              )),
                              const SizedBox(height: 2),
                              Text(
                                turn.text,
                                style: TextStyle(
                                  fontSize: 14, height: 1.5,
                                  color: c.textPrimary.withValues(alpha: isCurrent ? 1.0 : 0.65),
                                  fontWeight: isCurrent ? FontWeight.w500 : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 컨트롤 바
          // `:198` 다크 #1C1C1E (iOS 시스템 컬러) → surfaceCard 토큰 경유
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: isDark ? c.surfaceCard : c.surfaceAlt,
              border: Border(
                top: BorderSide(color: c.borderHair),
              ),
            ),
            child: Column(
              children: [
                // 진행 바
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _service.progress,
                    minHeight: 4,
                    backgroundColor: c.borderHair,
                    valueColor: AlwaysStoppedAnimation<Color>(c.accent),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${_service.currentIndex + 1}',
                      style: TextStyle(fontSize: 11, color: c.textMuted)),
                    Text('${_service.totalTurns}',
                      style: TextStyle(fontSize: 11, color: c.textMuted)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _CtrlButton(
                      icon: Icons.replay_10_rounded,
                      onTap: _service.skipBackward,
                      size: 36,
                    ),
                    Material(
                      color: c.accent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          if (_service.isPlaying) {
                            _service.pause();
                          } else {
                            _service.play();
                          }
                          FirebaseAnalytics.instance.logEvent(name: 'audio_toggle', parameters: {
                            'playing': _service.isPlaying ? 0 : 1,
                          });
                        },
                        child: SizedBox(
                          width: 64, height: 64,
                          child: Icon(
                            _service.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white, size: 36,
                          ),
                        ),
                      ),
                    ),
                    _CtrlButton(
                      icon: Icons.forward_10_rounded,
                      onTap: _service.skipForward,
                      size: 36,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // `:269-295` 속도 칩 — 히트 영역 48dp 확장 (SizedBox.fromSize wrapper)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [0.75, 1.0, 1.25, 1.5].map((s) {
                    final isActive = (_service.speed - s).abs() < 0.01;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: SizedBox(
                        // 히트 영역 48dp 확보 (DESIGN.md accessibility.minTouchTarget)
                        height: 48,
                        child: InkWell(
                          onTap: () => _service.setSpeed(s),
                          borderRadius: BorderRadius.circular(14),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isActive ? c.accent : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isActive ? c.accent : c.borderSoft,
                                ),
                              ),
                              child: Text(
                                '${s}x',
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: isActive ? Colors.white : c.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CtrlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _CtrlButton({required this.icon, required this.onTap, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final c = context.jColors;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 56, height: 56,
          child: Icon(
            icon,
            size: size,
            color: c.textPrimary.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}
