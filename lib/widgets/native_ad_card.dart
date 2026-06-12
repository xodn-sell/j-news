import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/native_ad_service.dart';

class NativeAdCard extends StatefulWidget {
  final bool isDark;
  final VoidCallback? onAdLoaded;
  final VoidCallback? onAdFailed;
  final VoidCallback? onAdImpression;
  final VoidCallback? onAdClicked;
  // 플랫폼 뷰(AdWidget)가 터치를 전부 소비해 스와이프 불가 → 하단 버튼으로 이동 제공
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const NativeAdCard({
    super.key,
    required this.isDark,
    this.onAdLoaded,
    this.onAdFailed,
    this.onAdImpression,
    this.onAdClicked,
    this.onPrev,
    this.onNext,
  });

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    final preloaded = NativeAdService.take();
    if (preloaded != null) {
      _nativeAd = preloaded;
      _isLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onAdLoaded?.call();
      });
      return;
    }
    _loadInline();
  }

  void _loadInline() {
    _nativeAd = NativeAd(
      adUnitId: NativeAdService.adUnitId,
      factoryId: NativeAdService.factoryId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isLoaded = true);
          widget.onAdLoaded?.call();
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _loadFailed = true);
          widget.onAdFailed?.call();
        },
        onAdImpression: (_) => widget.onAdImpression?.call(),
        onAdClicked: (_) => widget.onAdClicked?.call(),
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _nativeAd == null) {
      return Center(
        child: _loadFailed ? _buildFailedState() : _buildLoadingState(),
      );
    }
    // 풀 카드 네이티브 광고 + 하단 내비게이션 (AdWidget 영역 밖 — AdMob 정책 안전)
    return Column(
      children: [
        Expanded(child: AdWidget(ad: _nativeAd!)),
        _buildNavBar(),
      ],
    );
  }

  Widget _buildNavBar() {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Container(
      color: theme.colorScheme.surface,
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          if (widget.onPrev != null)
            TextButton.icon(
              onPressed: widget.onPrev,
              icon: Icon(Icons.arrow_back_rounded, size: 16, color: onSurface.withValues(alpha: 0.55)),
              label: Text(
                '이전',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: onSurface.withValues(alpha: 0.55)),
              ),
            ),
          const Spacer(),
          if (widget.onNext != null)
            FilledButton.icon(
              onPressed: widget.onNext,
              style: FilledButton.styleFrom(
                backgroundColor: onSurface.withValues(alpha: 0.08),
                foregroundColor: onSurface.withValues(alpha: 0.75),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Text('다음 뉴스', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              label: const Icon(Icons.arrow_forward_rounded, size: 16),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: onSurface.withValues(alpha: 0.2),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '광고 로딩 중...',
          style: TextStyle(
            fontSize: 12,
            color: onSurface.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }

  Widget _buildFailedState() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Text(
      '광고를 불러올 수 없어요',
      style: TextStyle(
        fontSize: 13,
        color: onSurface.withValues(alpha: 0.35),
      ),
    );
  }
}
