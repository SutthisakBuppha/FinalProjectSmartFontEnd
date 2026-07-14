import 'dart:async'; // 👈 1. Import สำหรับใช้งาน Timer
import 'package:flutter/material.dart';

// 👈 2. Import API Service และ AlertScreen (อย่าลืมแก้ไข path ให้ตรงกับโปรเจกต์ของคุณ)
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

class MainLayout extends StatefulWidget {
  // 1. เพิ่มตัวแปร initialIndex รับค่าเริ่มต้น
  final int initialIndex;

  // 2. กำหนดค่า default เป็น 0 (หน้า Home)
  const MainLayout({super.key, this.initialIndex = 0});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  // 👈 3. เพิ่มตัวแปร Timer และตัวป้องกันการเด้งหน้าจอซ้อนกัน
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
    // 3. กำหนดให้หน้าที่จะแสดง = ค่าที่รับเข้ามาตอนเริ่ม
    _selectedIndex = widget.initialIndex;

    // 👈 4. เรียกใช้ฟังก์ชันเริ่มตรวจสอบ Notification
    _startNotificationPolling();
  }

  // 👈 5. ฟังก์ชันสำหรับ Polling Notification ทุกๆ 8 วินาที
  void _startNotificationPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      try {
        final noti = await ApiService.instance.notifications(isRead: false);

        // เช็คว่าหน้าจอยังเปิดอยู่ (mounted), มีแจ้งเตือน, และยังไม่ได้เปิดหน้า Alert ค้างไว้
        if (mounted && noti.isNotEmpty && !_isShowingAlert) {
          _isShowingAlert = true; // ล็อคไว้ไม่ให้เด้งซ้ำ

          // 🔴 สำคัญ: mark ว่าอ่านแล้วทันทีก่อนเปิดหน้า Alert
          // ป้องกันไม่ให้ polling รอบถัดไป (8 วิถัดมา) เจอ notification ตัวเดิม
          // แล้วเด้งเปิด AlertScreen ซ้ำวนลูปไม่รู้จบ ทั้งที่ผู้ใช้เพิ่งปิดไป
          try {
            await ApiService.instance.markAllNotificationsRead();
          } catch (e) {
            debugPrint("Mark notification read error: $e");
          }

          // เปิดหน้า AlertScreen แบบรอผลลัพธ์
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AlertScreen()),
          );

          // เมื่อกดกลับมาจากหน้า Alert ให้ปลดล็อค
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
    // 👈 6. สำคัญมาก: ต้องเคลียร์ Timer ทิ้งเมื่อออกจากหน้านี้หรือแอพถูกปิด
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