import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  static const String _webClientId =
      '813400070963-t55qlrbag595qe51rmrq95m5k2sbn1om.apps.googleusercontent.com';
      // '813400070963-4u3uh33snabf60hk3fcldqc94bmnsaf3.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<void>? _initFuture;

  Future<void> ensureInitialized() {
    return _initFuture ??= _googleSignIn.initialize(
      clientId: kIsWeb ? _webClientId : null,
      serverClientId: kIsWeb ? null : _webClientId,
    );
  }

  /// ดักฟังการเปลี่ยนแปลงสิทธิ์ (เช่น เมื่อกดปุ่ม Sign-In บน Web สำเร็จ)
  Stream<GoogleSignInAuthenticationEvent> get googleSignInEvents =>
      _googleSignIn.authenticationEvents;

  /// ✨ เพิ่ม Getter นี้เพื่อแปลง Event จาก GoogleSignInAuthenticationEventSignIn
  /// แล้วคัดแยกส่งเฉพาะ idToken (String) ออกไปให้ UI
  Stream<String> get onIdTokenReceived => googleSignInEvents
      .map((event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          return event.user.authentication.idToken;
        }
        return null;
      })
      .where((token) => token != null)
      .cast<String>();

  Future<String?> signInAndGetIdToken() async {
    await ensureInitialized();

    late final GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('TIMEOUT: authenticate ค้างเกิน 15 วิ'),
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) throw Exception('ไม่สามารถรับ Token ได้');
    return idToken;
  }

  Future<void> signOut() async {
    await ensureInitialized();
    await _googleSignIn.signOut();
  }
}