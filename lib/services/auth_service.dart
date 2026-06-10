import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// 현재 인증된 사용자의 UID. 미인증 시 null.
  static String? get uid => _auth.currentUser?.uid;

  /// 로그인 여부
  static bool get isSignedIn => _auth.currentUser != null;

  /// 앱 시작 시 1회 호출. 이미 로그인된 경우 재인증 안 함.
  static Future<void> init() async {
    if (_auth.currentUser != null) {
      debugPrint('[AuthService] 이미 인증됨: ${_auth.currentUser!.uid}');
      return;
    }
    debugPrint('[AuthService] 미인증 상태 — 로그인 화면으로 이동 필요');
  }

  /// Google Sign-In 실행. 성공 시 FirebaseUser 반환.
  static Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // 사용자가 로그인 취소
        debugPrint('[AuthService] Google 로그인 취소됨');
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      debugPrint('[AuthService] Google 로그인 성공: ${userCredential.user?.uid}');
      return userCredential.user;
    } catch (e) {
      debugPrint('[AuthService] Google 로그인 실패: $e');
      rethrow;
    }
  }

  /// 로그아웃
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    debugPrint('[AuthService] 로그아웃 완료');
  }
}
