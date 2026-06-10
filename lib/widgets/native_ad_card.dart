import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/native_ad_service.dart';

class NativeAdCard extends StatefulWidget {
  final bool isDark;
  final VoidCallback? onAdLoaded;
  final VoidCallback? onAdFailed;
  final VoidCallback? onAdImpression;
  final VoidCallback? onAdClicked;

  const NativeAdCard({
    super.key,
    required this.isDark,
    this.onAdLoaded,
    this.onAdFailed,
    this.onAdImpression,
    this.onAdClicked,
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
    // 풀 카드 네이티브 광고: 화면 전체 차지
    return SizedBox.expand(
      child: AdWidget(ad: _nativeAd!),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: const Color(0xFF0D1117).withValues(alpha: 0.2),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '광고 로딩 중...',
          style: TextStyle(
            fontSize: 12,
            color: const Color(0xFF0D1117).withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }

  Widget _buildFailedState() {
    return Text(
      '광고를 불러올 수 없어요',
      style: TextStyle(
        fontSize: 13,
        color: const Color(0xFF0D1117).withValues(alpha: 0.35),
      ),
    );
  }
}
