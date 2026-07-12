import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  static const String _webClientId =
      '813400070963-t55qlrbag595qe51rmrq95m5k2sbn1om.apps.googleusercontent.com'; //web app
      // '813400070963-4u3uh33snabf60hk3fcldqc94bmnsaf3.apps.googleusercontent.com'; // MobileApp

  // google_sign_in v7+: ไม่มี constructor ตรงๆ แล้ว ต้องใช้ instance แบบ singleton
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<void>? _initFuture;

  /// v7+: ต้องเรียกและ await ครั้งเดียวก่อนใช้เมธอดอื่นของ GoogleSignIn
  /// เรียกซ้ำได้อย่างปลอดภัย เพราะเก็บ Future เดิมไว้ใช้ซ้ำ
  Future<void> ensureInitialized() {
    return _initFuture ??= _googleSignIn.initialize(
      clientId: kIsWeb ? _webClientId : null,
      serverClientId: kIsWeb ? null : _webClientId,
    );
  }

  /// ✨ แทนที่ onCurrentUserChanged เดิม (ถูกลบใน v7)
  /// ใช้สำหรับดักฟังการเปลี่ยนแปลงสิทธิ์ (เช่น เมื่อกดปุ่ม Sign-In บน Web สำเร็จ)
  Stream<GoogleSignInAuthenticationEvent> get googleSignInEvents =>
      _googleSignIn.authenticationEvents;

  /// ฟังก์ชันสำหรับ Mobile (ดั้งเดิม) หรือการล็อกอินเบื้องหลัง
  /// คืนค่า null ถ้าผู้ใช้กดยกเลิกการล็อกอิน
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

    // v7+: authentication เป็น synchronous getter และมีแค่ idToken เท่านั้น
    // (accessToken ต้องขอแยกผ่าน account.authorizationClient แทน)
    final idToken = account.authentication.idToken;
    if (idToken == null) throw Exception('ไม่สามารถรับ Token ได้');
    return idToken;
  }

  Future<void> signOut() async {
    await ensureInitialized();
    await _googleSignIn.signOut();
  }
}