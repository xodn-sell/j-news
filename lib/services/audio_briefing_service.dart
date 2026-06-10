import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/news_result.dart';

/// 뉴스 2인 대화 스크립트를 TTS로 재생하는 서비스.
/// flutter_tts 사용 — 디바이스 내장 TTS 호출 (네트워크 불필요, 비용 0).
class AudioBriefingService extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  List<DialogueTurn> _turns = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isInitialized = false;
  double _speed = 1.0;
  Completer<void>? _speakCompleter;
  bool _stopped = false;

  List<DialogueTurn> get turns => _turns;
  int get currentIndex => _currentIndex;
  int get totalTurns => _turns.length;
  bool get isPlaying => _isPlaying;
  double get speed => _speed;
  bool get hasDialogue => _turns.isNotEmpty;

  DialogueTurn? get currentTurn =>
      (_currentIndex >= 0 && _currentIndex < _turns.length) ? _turns[_currentIndex] : null;

  double get progress =>
      _turns.isEmpty ? 0.0 : (_currentIndex + 1) / _turns.length;

  Future<void> init() async {
    if (_isInitialized) return;
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.5); // flutter_tts 0.0~1.0. 0.5 = 자연스러운 속도
    await _tts.awaitSpeakCompletion(true);

    _tts.setCompletionHandler(() {
      _speakCompleter?.complete();
    });
    _tts.setErrorHandler((msg) {
      _speakCompleter?.completeError(Exception('TTS error: $msg'));
    });
    _tts.setCancelHandler(() {
      _speakCompleter?.complete();
    });
    _isInitialized = true;
  }

  void loadDialogue(List<DialogueTurn> turns) {
    _turns = turns;
    _currentIndex = 0;
    notifyListeners();
  }

  Future<void> play() async {
    if (!_isInitialized) await init();
    if (_turns.isEmpty || _isPlaying) return;
    _isPlaying = true;
    _stopped = false;
    notifyListeners();

    while (_isPlaying && _currentIndex < _turns.length && !_stopped) {
      final turn = _turns[_currentIndex];
      await _speakTurn(turn);
      if (_stopped) break;
      _currentIndex++;
      notifyListeners();
    }

    if (_currentIndex >= _turns.length) {
      // 끝까지 재생 완료 → 초기화
      _currentIndex = 0;
    }
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> _speakTurn(DialogueTurn turn) async {
    // A: 낮은 톤 (호스트 지음). B: 높은 톤 (분석가 소나).
    final pitch = turn.speaker == 'A' ? 0.95 : 1.15;
    await _tts.setPitch(pitch);
    await _tts.setSpeechRate(_clampedRate(_speed));

    _speakCompleter = Completer<void>();
    try {
      await _tts.speak(turn.text);
      // awaitSpeakCompletion이 true면 speak()가 종료될 때까지 await.
      // setCompletionHandler에서 _speakCompleter.complete() 호출.
      await _speakCompleter!.future.timeout(const Duration(seconds: 60), onTimeout: () {});
    } catch (e) {
      // TTS 에러는 무시하고 다음 턴으로
    }
  }

  Future<void> pause() async {
    _isPlaying = false;
    _stopped = true;
    await _tts.stop();
    _speakCompleter?.complete();
    notifyListeners();
  }

  Future<void> skipForward() async {
    final wasPlaying = _isPlaying;
    await pause();
    if (_currentIndex < _turns.length - 1) {
      _currentIndex++;
      notifyListeners();
    }
    if (wasPlaying) await play();
  }

  Future<void> skipBackward() async {
    final wasPlaying = _isPlaying;
    await pause();
    if (_currentIndex > 0) {
      _currentIndex--;
      notifyListeners();
    }
    if (wasPlaying) await play();
  }

  Future<void> seekTo(int index) async {
    if (index < 0 || index >= _turns.length) return;
    final wasPlaying = _isPlaying;
    await pause();
    _currentIndex = index;
    notifyListeners();
    if (wasPlaying) await play();
  }

  void setSpeed(double speed) {
    _speed = speed.clamp(0.5, 1.5);
    notifyListeners();
    // 현재 재생 중인 utterance에는 적용 안 됨 (다음 턴부터)
  }

  double _clampedRate(double speed) {
    // flutter_tts: 0.0 (가장 느림) ~ 1.0 (가장 빠름). 0.5 = 기본
    return (0.5 * speed).clamp(0.25, 1.0);
  }

  Future<void> stopAndReset() async {
    await pause();
    _currentIndex = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
