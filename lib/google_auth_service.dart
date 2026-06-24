import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  static const String _webClientId =
      '813400070963-t55qlrbag595qe51rmrq95m5k2sbn1om.apps.googleusercontent.com';

  GoogleSignIn? _googleSignInInstance;
  GoogleSignIn get _googleSignIn {
    return _googleSignInInstance ??= GoogleSignIn(
      scopes: ['email', 'profile'],
      clientId: kIsWeb ? _webClientId : null,
      // ✅ serverClientId ใช้ได้เฉพาะ Mobile เท่านั้น
      serverClientId: kIsWeb ? null : _webClientId,
    );
  }

  Future<String?> signInAndGetIdToken() async {
    final account = await _googleSignIn.signIn().timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('TIMEOUT: signIn ค้างเกิน 15 วิ'),
    );
    if (account == null) return null;

    final auth = await account.authentication.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('TIMEOUT: authentication ค้างเกิน 15 วิ'),
    );

    final token = auth.idToken ?? auth.accessToken;

    if (token == null) throw Exception('ไม่สามารถรับ Token ได้');
    return token;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}