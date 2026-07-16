import 'dart:async'; // 👈 1. Import สำหรับใช้งาน Timer
import 'package:flutter/material.dart';

// 👈 2. Import API Service และ AlertScreen
import '/services/api_service.dart';
import 'alert_screen.dart';

// Import หน้าจอต่างๆ
import 'home_screen.dart';
import 'history_screen.dart';
import '/notification_screen.dart';
import 'profile_screen.dart';
import 'device_registration_screen.dart';
import 'risk_summary_screen.dart';
// Import ไฟล์ Navbar ของคุณ
import 'menu/custom_bottom_nav_bar.dart';

// ---------------------------------------------------------------------
// ✅ หมายเหตุ: ไฟล์นี้ "ไม่ต้องแก้ไข" เนื้อหา ยังคงทำหน้าที่เดิมทุกอย่าง
// เพียงแต่ตอนนี้เป็น "จุดเดียว" ในทั้งแอปที่รับผิดชอบการ polling แจ้งเตือน
// แล้วเด้งเปิด AlertScreen (เดิมมี home_screen.dart poll ซ้ำอีกจุดหนึ่ง
// ซึ่งถูกตัดออกไปแล้ว ดูหมายเหตุใน home_screen.dart)
// ---------------------------------------------------------------------

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

  final List<Widget> _screens = [
    const HomeScreen(),               // Index 0
    const HistoryScreen(),            // Index 1
    const NotificationScreen(),       // Index 2
    const DeviceRegistrationScreen(), // Index 3
    const RiskTrendsScreen(),         // Index 4
    const ProfileScreen(),            // Index 5
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _startNotificationPolling();
  }

  // Polling Notification ทุกๆ 8 วินาที (จุดเดียวของทั้งแอปที่เด้ง AlertScreen)
  void _startNotificationPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      try {
        final noti = await ApiService.instance.notifications(isRead: false);

        if (mounted && noti.isNotEmpty && !_isShowingAlert) {
          _isShowingAlert = true; // ล็อคไว้ไม่ให้เด้งซ้ำ

          // 🔴 สำคัญ: mark ว่าอ่านแล้วทันทีก่อนเปิดหน้า Alert
          // ป้องกันไม่ให้ polling รอบถัดไป (8 วิถัดมา) เจอ notification ตัวเดิม
          try {
            await ApiService.instance.markAllNotificationsRead();
          } catch (e) {
            debugPrint("Mark notification read error: $e");
          }

          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AlertScreen()),
          );

          if (mounted) {
            _isShowingAlert = false;
          }
        }
      } catch (e) {
        debugPrint("Polling Notification Error: $e");
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