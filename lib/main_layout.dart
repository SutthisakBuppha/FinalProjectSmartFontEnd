import 'dart:async';
import 'package:flutter/material.dart';
import '/services/api_service.dart';
import 'alert_screen.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import '/notification_screen.dart';
import 'profile_screen.dart';
import 'device_registration_screen.dart';
import 'risk_summary_screen.dart';
import 'menu/custom_bottom_nav_bar.dart';

class MainLayout extends StatefulWidget {
  final int initialIndex;

  const MainLayout({super.key, this.initialIndex = 0});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  Timer? _pollingTimer;
  bool _isShowingAlert = false;
  dynamic _lastSeenAlertId; // เก็บ id ของ alert ล่าสุดที่เคยเห็นแล้ว (กันเด้งซ้ำ/เด้งของเก่า)

  final List<Widget> _screens = [
    const HomeScreen(), // Index 0
    const HistoryScreen(), // Index 1
    const NotificationScreen(), // Index 2
    const DeviceRegistrationScreen(), // Index 3
    const RiskTrendsScreen(), // Index 4
    const ProfileScreen(), // Index 5
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _startNotificationPolling();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Polling: เช็คทุก 3 วิว่ามี Alert ใหม่จาก AI Guard (ผ่าน Laravel) หรือยัง
  // เช็คจาก alert_id ตรงๆ (ไม่ใช่ผ่าน Notification) เพราะ Notification จะถูก
  // สร้างก็ต่อเมื่อ Laravel นับได้ว่า Alert ประเภทเดียวกันซ้ำครบ 3 ครั้งใน 10
  // นาทีอีกชั้นหนึ่ง ซึ่งเป็นคนละตัวนับกับที่ฝั่ง AI (python) นับไว้แล้วก่อนยิง
  // เข้ามา ทำให้กว่าจะเด้งจอต้องรอ Alert ซ้อนกันหลายรอบโดยไม่จำเป็น
  //
  // จุดเดียวของทั้งแอปที่เด้ง AlertScreen (ย้ายมาจาก map_screen.dart เดิม
  // เพื่อให้ทำงานได้ไม่ว่าผู้ใช้จะอยู่หน้าไหนใน MainLayout ก็ตาม)
  // ═══════════════════════════════════════════════════════════════════════
  void _startNotificationPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || _isShowingAlert) return;
      if (!ApiService.instance.isLoggedIn) return;

      try {
        final alert = await ApiService.instance.latestAlert();
        if (alert == null) return;

        final alertId = alert['alert_id'];
        if (alertId == null) return;

        if (_lastSeenAlertId == null) {
          // ดึงมาเป็นครั้งแรก -> แค่จำ id ไว้เฉยๆ ยังไม่เด้งจอ
          // (กันไม่ให้ alert เก่าที่เคยเกิดไปแล้วก่อนเปิดแอปมาเด้งซ้ำ)
          _lastSeenAlertId = alertId;
          return;
        }

        if (alertId == _lastSeenAlertId) return;

        _lastSeenAlertId = alertId;
        _isShowingAlert = true;

        try {
          await ApiService.instance.markAllNotificationsRead();
        } catch (e) {
          debugPrint("Mark notification read error: $e");
        }

        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AlertScreen(deviceId: alert['device_id']),
          ),
        );

        if (mounted) {
          _isShowingAlert = false;
        }
      } catch (e) {
        debugPrint("Polling Alert Error: $e");
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _screens[_selectedIndex],
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}