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

  // Polling Notification ทุกๆ 8 วินาที (จุดเดียวของทั้งแอปที่เด้ง AlertScreen)
  void _startNotificationPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final noti = await ApiService.instance.notifications(isRead: false);

        if (mounted && noti.isNotEmpty && !_isShowingAlert) {
          _isShowingAlert = true;

          try {
            await ApiService.instance.markAllNotificationsRead();
          } catch (e) {
            debugPrint("Mark notification read error: $e");
          }

          // 🔴 ใหม่: ดึง device_id จาก alert ล่าสุด เพื่อรู้ว่าต้องเล่นเสียงของอุปกรณ์ไหน
          dynamic deviceId;
          try {
            final latest = await ApiService.instance.latestAlert();
            deviceId = latest?['device_id'];
          } catch (e) {
            debugPrint("โหลด latest alert (device_id) ล้มเหลว: $e");
          }

          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AlertScreen(deviceId: deviceId)),
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
