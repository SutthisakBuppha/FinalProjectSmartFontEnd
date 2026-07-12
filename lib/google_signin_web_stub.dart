// ไฟล์นี้ถูกใช้บนแพลตฟอร์มที่ไม่ใช่ Web (Android/iOS) เท่านั้น
// ไม่ import package:google_sign_in_web เลย จึงไม่ดึง dart:js_interop เข้ามาคอมไพล์
// รูปร่าง (shape) ของคลาส/ฟังก์ชันต้องตรงกับ google_signin_web_impl.dart
// เพื่อให้ login_screen.dart เขียนโค้ดเดียวใช้ได้ทั้งสองฝั่ง

import 'package:flutter/widgets.dart';

class GSIButtonType {
  const GSIButtonType._();
  static const standard = GSIButtonType._();
}

class GSIButtonTheme {
  const GSIButtonTheme._();
  static const filledBlue = GSIButtonTheme._();
}

class GSIButtonSize {
  const GSIButtonSize._();
  static const large = GSIButtonSize._();
}

class GSIButtonText {
  const GSIButtonText._();
  static const signinWith = GSIButtonText._();
}

class GSIButtonShape {
  const GSIButtonShape._();
  static const rectangular = GSIButtonShape._();
}

class GSIButtonConfiguration {
  const GSIButtonConfiguration({
    this.type,
    this.theme,
    this.size,
    this.text,
    this.shape,
  });
  final GSIButtonType? type;
  final GSIButtonTheme? theme;
  final GSIButtonSize? size;
  final GSIButtonText? text;
  final GSIButtonShape? shape;
}

/// จะไม่ถูกเรียกใช้งานจริงบน non-web (ถูกกันด้วย kIsWeb ? ... : ... ใน login_screen.dart)
/// ใส่ไว้แค่ให้ signature ตรงกันตอน compile
Widget renderButton({GSIButtonConfiguration? configuration}) {
  return const SizedBox.shrink();
}