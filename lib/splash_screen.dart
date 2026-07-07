import 'package:flutter/material.dart';

import '/services/api_service.dart';
import 'devices_screen.dart';
import 'device_registration_screen.dart';
import 'welcome_screen.dart'; // หน้าแรกเดิมของคุณ (มี logic ไป Login เอง)

/// หน้าแรกสุดของแอป (ตั้งเป็น `home:` ใน MaterialApp แทน WelcomeScreen)
/// หน้าที่ทำหน้าที่:
/// 1. โหลด session (token) เก่าที่เคย login ไว้กลับมาจาก local storage
/// 2. ถ้าไม่มี session -> ไปหน้า WelcomeScreen (flow เดิมของคุณ ให้ผู้ใช้กด login/สมัคร)
/// 3. ถ้ามี session -> เช็คกับ backend ว่ามีอุปกรณ์ลงทะเบียนไว้หรือยัง
///    - มีแล้ว -> ไปหน้ารายการอุปกรณ์ (DeviceManagementScreen) ตรงๆ
///    - ยังไม่มี -> ไปหน้าลงทะเบียนอุปกรณ์ (DeviceRegistrationScreen)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Color primaryColor = Color(0xFF0F2557);
  static const Color backgroundColor = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final hasSession = await ApiService.instance.restoreSession();

    if (!hasSession) {
      _goTo(const WelcomeScreen());
      return;
    }

    try {
      final devices = await ApiService.instance.devices();
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
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: CircularProgressIndicator(color: primaryColor),
      ),
    );
  }
}