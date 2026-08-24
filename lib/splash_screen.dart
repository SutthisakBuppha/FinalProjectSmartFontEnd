import 'dart:async';

import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

import '/services/api_service.dart';
import '/services/push_notification_service.dart';
import 'devices_screen.dart';
import 'device_registration_screen.dart';
import 'main_layout.dart';
import 'welcome_screen.dart'; // หน้าแรกเดิมของคุณ (มี logic ไป Login เอง)

/// หน้าแรกสุดของแอป (ตั้งเป็น `home:` ใน MaterialApp แทน WelcomeScreen)
/// หน้าที่ทำหน้าที่:
/// 1. โหลด session (token) เก่าที่เคย login ไว้กลับมาจาก local storage
/// 2. ถ้าไม่มี session -> ไปหน้า WelcomeScreen (flow เดิมของคุณ ให้ผู้ใช้กด login/สมัคร)
/// 3. ถ้ามี session -> เช็ค "หน้าล่าสุด" ที่เคยจำไว้ (last_route)
///    - ถ้ามี -> พาไปหน้านั้นตรงๆ (เช่น refresh เว็บ หรือปิด-เปิดแอปมือถือ
///      ก็จะอยู่หน้าเดิมที่ค้างไว้)
///    - ถ้าไม่มี (login ครั้งแรก) -> เช็คว่ามีอุปกรณ์ลงทะเบียนไว้หรือยัง
///      แล้วพาไปหน้ารายการอุปกรณ์ หรือหน้าลงทะเบียนอุปกรณ์ตามเดิม
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    _bootstrap().timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        ApiService.instance.clearSession();
        _goTo(const WelcomeScreen());
      },
    );
  }

  Future<void> _bootstrap() async {
    try {
      final hasSession = await ApiService.instance.restoreSession().timeout(
        const Duration(seconds: 3),
      );

      // A fresh install has no saved token and must always start at Welcome.
      if (!hasSession) {
        _goTo(const WelcomeScreen());
        return;
      }

      // FCM registration is best-effort background work. Never block startup.
      unawaited(PushNotificationService.instance.registerTokenWithBackend());

      final lastRoute = await ApiService.instance.getLastRoute().timeout(
        const Duration(seconds: 3),
      );

      switch (lastRoute) {
        case 'home':
          _goTo(const MainLayout());
          return;
        case 'devices':
          _goTo(const DeviceManagementScreen());
          return;
        // 🆕 เพิ่ม case ใหม่ตรงนี้เมื่อมีหน้าอื่นที่อยากให้จำไว้
        // (อย่าลืมเรียก ApiService.instance.saveLastRoute('key') ใน initState
        // ของหน้านั้นๆ ด้วย ไม่งั้นระบบจะไม่รู้จักหน้านั้น)
      }

      // ไม่มี last_route ที่รู้จัก (เช่น login ครั้งแรก) -> ใช้ logic เดิม
      final devices = await ApiService.instance.devices().timeout(
        const Duration(seconds: 6),
      );
      if (devices.isNotEmpty) {
        _goTo(const DeviceManagementScreen());
      } else {
        _goTo(const DeviceRegistrationScreen());
      }
    } catch (e) {
      // token เก่าหมดอายุ หรือ backend ปฏิเสธ -> ล้าง session แล้วกลับไปหน้า Welcome
      ApiService.instance.clearSession();
      _goTo(const WelcomeScreen());
    }
  }

  void _goTo(Widget screen) {
    if (!mounted || _didNavigate) return;
    _didNavigate = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.cFF0F2557),
      ),
    );
  }
}
