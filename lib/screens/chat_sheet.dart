import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../services/chat_service.dart';
import '../models/news_result.dart';
import '../theme/jnews_colors.dart';

class ChatSheet extends StatefulWidget {
  final String newsTitle;
  final String newsBody;
  final String whyMatters;
  final List<GlossaryItem> glossary;

  const ChatSheet({
    super.key,
    required this.newsTitle,
    required this.newsBody,
    this.whyMatters = '',
    this.glossary = const [],
  });

  static Future<void> show(
    BuildContext context, {
    required String newsTitle,
    required String newsBody,
    String whyMatters = '',
    List<GlossaryItem> glossary = const [],
  }) {
    FirebaseAnalytics.instance.logEvent(name: 'chat_opened', parameters: {
      'title_len': newsTitle.length,
    });
    // 풀스크린 페이지 — 바텀시트(85%)는 뒷화면이 비쳐 보여 산만 (UX 피드백)
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ChatSheet(
          newsTitle: newsTitle,
          newsBody: newsBody,
          whyMatters: whyMatters,
          glossary: glossary,
        ),
      ),
    );
  }

  @override
  State<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<ChatSheet> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _limitReached = false; // 일일 한도 초과 — 입력 비활성화

  // 제안 질문들 — 사용자가 처음 진입했을 때 빠른 시작용
  static const List<String> _starterQuestions = [
    '이거 무슨 의미야?',
    '왜 이게 중요해?',
    '쉽게 설명해줘',
    '찬반 양쪽 어떻게 봐?',
  ];

  // 후속 질문칩 — AI 답변 후 학습 심화용
  static const List<String> _followUpChips = [
    '더 자세히',
    '예시 들어줘',
    '반대 입장은?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending || _limitReached) return;

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: trimmed, ts: DateTime.now()));
      _isSending = true;
    });
    _controller.clear();
    _scrollToBottom();

    FirebaseAnalytics.instance.logEvent(name: 'chat_message_sent', parameters: {
      'turn': _messages.length,
      'msg_len': trimmed.length,
    });

    try {
      // 마지막 메시지(현재 user msg) 제외하고 history 전송
      final history = _messages.sublist(0, _messages.length - 1);
      final reply = await ChatService.sendMessage(
        newsContext: {
          'title': widget.newsTitle,
          'body': widget.newsBody,
          if (widget.whyMatters.isNotEmpty) 'why_matters': widget.whyMatters,
          if (widget.glossary.isNotEmpty)
            'glossary': widget.glossary
                .map((g) => {'term': g.term, 'definition': g.definition})
                .toList(),
        },
        history: history,
        message: trimmed,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: reply, ts: DateTime.now()));
        _isSending = false;
      });
      _scrollToBottom();
    } on ChatDailyLimitException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: e.message,
          ts: DateTime.now(),
        ));
        _isSending = false;
        _limitReached = true;
      });
      _scrollToBottom();
      FirebaseAnalytics.instance.logEvent(name: 'chat_daily_limit', parameters: {
        'turn': _messages.length,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: '⚠️ ${e.toString().replaceFirst('Exception: ', '')}',
          ts: DateTime.now(),
        ));
        _isSending = false;
      });
      _scrollToBottom();
      FirebaseAnalytics.instance.logEvent(name: 'chat_error', parameters: {
        'error': e.toString().length > 80 ? e.toString().substring(0, 80) : e.toString(),
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = context.jColors;

    return Scaffold(
      backgroundColor: isDark ? c.surfaceCard : c.surfaceElevated,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // 헤더: AI 이름 + 뉴스 컨텍스트
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0052CC), Color(0xFF1E88E5)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child: Text('J', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 카피 "지음 AI" → "AI 튜터" (LEARNING_PIVOT.md 통일)
                        Text('AI 튜터', style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        )),
                        Text(widget.newsTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(
                          fontSize: 12,
                          color: c.textMuted,
                        )),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.borderHair),
            // 메시지 리스트
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState(isDark, c)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      itemCount: _messages.length + (_isSending ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i >= _messages.length) {
                          return _buildTypingBubble(isDark, c);
                        }
                        final msg = _messages[i];
                        // 가장 최근 assistant 메시지에만 후속 칩 노출 (전송 중엔 숨김)
                        final isLastAssistant = !_isSending &&
                            !_limitReached &&
                            msg.role == 'assistant' &&
                            i == _messages.length - 1;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMessageBubble(msg, isDark, c),
                            if (isLastAssistant)
                              _buildFollowUpChips(isDark, c),
                          ],
                        );
                      },
                    ),
            ),
            // 입력바
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10), // SafeArea가 하단 인셋 처리
              decoration: BoxDecoration(
                color: isDark ? c.surfaceCard : c.surfaceElevated,
                border: Border(
                  top: BorderSide(color: c.borderHair),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.borderHair,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _controller,
                        enabled: !_limitReached,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _send,
                        decoration: InputDecoration(
                          hintText: _limitReached ? '오늘 사용량을 다 썼어요' : '뉴스에 대해 뭐든 물어봐',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: _limitReached
                        ? c.accent.withValues(alpha: 0.35)
                        : c.accent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: (_isSending || _limitReached) ? null : () => _send(_controller.text),
                      child: SizedBox(
                        width: 44, height: 44,
                        child: _isSending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, JNewsColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text('이 뉴스에 대해 같이 얘기해보자', style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600,
            color: c.textPrimary.withValues(alpha: 0.8),
          )),
          const SizedBox(height: 4),
          Text('아래 질문을 누르거나 직접 입력해도 돼', style: TextStyle(
            fontSize: 12,
            color: c.textMuted,
          )),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8, runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _starterQuestions.map((q) {
              return InkWell(
                onTap: () => _send(q),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: c.borderHair,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.accent.withValues(alpha: 0.25)),
                  ),
                  child: Text(q, style: TextStyle(
                    fontSize: 13,
                    color: c.textPrimary,
                  )),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpChips(bool isDark, JNewsColors c) {
    return Padding(
      padding: const EdgeInsets.only(left: 36, top: 6, bottom: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _followUpChips.map((q) {
          return InkWell(
            onTap: () => _send(q),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: c.borderHair,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.accent.withValues(alpha: 0.25)),
              ),
              child: Text(
                q,
                style: TextStyle(
                  fontSize: 12,
                  color: c.textBody,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isDark, JNewsColors c) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28, height: 28,
              margin: const EdgeInsets.only(top: 4, right: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c.accent, c.accentLight]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('AI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? c.accent
                    : (isDark ? Colors.white.withValues(alpha: 0.08) : c.surfaceAlt),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Text(
                msg.content,
                style: TextStyle(
                  fontSize: 14, height: 1.45,
                  color: isUser ? Colors.white : c.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingBubble(bool isDark, JNewsColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            margin: const EdgeInsets.only(top: 4, right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c.accent, c.accentLight]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('AI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : c.surfaceAlt,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: SizedBox(
              width: 24, height: 12,
              child: _TypingDots(accentColor: c.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  final Color accentColor;
  const _TypingDots({required this.accentColor});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(3, (i) {
            final phase = (_c.value - i * 0.18) % 1.0;
            final scale = 0.5 + (1 - (phase - 0.3).abs() * 2).clamp(0.0, 1.0) * 0.8;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
