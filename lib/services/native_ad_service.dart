import 'package:google_mobile_ads/google_mobile_ads.dart';

const _kAdUnitId = 'ca-app-pub-5328100277559359/7830578115';
const _kFactoryId = 'fullCard';
const _kPoolSize = 3;

/// 네이티브 광고 프리로드 풀 (최대 3개 — 뉴스 7개 시 광고 슬롯 {2,5,8}).
/// 화면 진입 전에 미리 load() 해놓고 NativeAdCard 가 즉시 rendering.
class NativeAdService {
  static final List<NativeAd> _pool = [];
  static int _loadingCount = 0;

  /// 앱 시작 시 호출 — 풀을 목표 크기까지 채움.
  static void preload() {
    while (_pool.length + _loadingCount < _kPoolSize) {
      _startLoad();
    }
  }

  static void _startLoad() {
    _loadingCount++;
    final ad = NativeAd(
      adUnitId: _kAdUnitId,
      factoryId: _kFactoryId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (loaded) {
          _pool.add(loaded as NativeAd);
          _loadingCount--;
        },
        onAdFailedToLoad: (failed, _) {
          failed.dispose();
          _loadingCount--;
          // 실패 시 자동 재시도 안 함 (무한 루프 방지) — 다음 take() 에서 재시도
        },
      ),
    );
    ad.load();
  }

  /// 프리로드된 광고 1개 꺼냄. 다음 광고 즉시 예열.
  static NativeAd? take() {
    NativeAd? ad;
    if (_pool.isNotEmpty) ad = _pool.removeAt(0);
    // 풀 채우기 (1개 빠졌으니 1개 추가 로드)
    preload();
    return ad;
  }

  static String get factoryId => _kFactoryId;
  static String get adUnitId => _kAdUnitId;
}
