import 'dart:async';
import 'package:flutter/material.dart';
import '/services/api_service.dart';
import '/services/rest_mode_service.dart';
import '/services/trip_tracking_service.dart';
import '/services/push_notification_service.dart';
import 'alert_screen.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import '/notification_screen.dart';
import 'profile_screen.dart';
import 'device_registration_screen.dart';
import 'devices_screen.dart';
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
  dynamic _lastSeenNotificationId;
  bool _notificationBaselineReady = false;

  final List<Widget> _screens = [
    const HomeScreen(), // Index 0
    const HistoryScreen(), // Index 1
    const NotificationScreen(), // Index 2
    const DeviceSection(), // Index 3
    const RiskTrendsScreen(), // Index 4
    const ProfileScreen(), // Index 5
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    // โหลดสถานะโหมดพักรถที่เคย persist ไว้ (เผื่อผู้ใช้ปิด-เปิดแอประหว่างพักรถ)
    RestModeService.instance.ensureInitialized();
    unawaited(TripTrackingService.instance.restore());
    unawaited(PushNotificationService.instance.registerTokenWithBackend());
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
  //
  // 🆕 โหมดพักรถ (Rest Mode): ถ้าผู้ใช้เปิดโหมดพักรถอยู่ (เช่น จอดรถนอนพัก/
  // จอดหยิบของโดยติดเครื่องทิ้งไว้) จะ "ไม่เด้ง" หน้า AlertScreen และไม่เล่น
  // เสียงเตือนในแอป แต่ยังคงติดตาม alert id ล่าสุดไว้ตามปกติ เพื่อไม่ให้เกิด
  // การเด้งแจ้งเตือนแบบ "ค้าง" ทันทีที่โหมดพักรถหมดอายุ (จะรอ alert ใหม่จริงๆ
  // ที่เกิดขึ้นหลังจากพ้นโหมดพักรถแล้วเท่านั้น)
  // ═══════════════════════════════════════════════════════════════════════
  void _startNotificationPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || _isShowingAlert) return;
      if (!ApiService.instance.isLoggedIn) return;

      try {
        final notifications = await ApiService.instance.notifications();
        final notification = notifications.isEmpty ? null : notifications.first;
        final notificationId = notification?['noti_id'];

        if (!_notificationBaselineReady) {
          // Remember the state that existed before this app session so an old
          // critical notification does not reopen AlertScreen.
          _lastSeenNotificationId = notificationId;
          _notificationBaselineReady = true;
          return;
        }

        if (notificationId == null ||
            notificationId == _lastSeenNotificationId) {
          return;
        }

        _lastSeenNotificationId = notificationId;
        final alert = notification?['alert'];
        if (alert is! Map) return;
        final alertData = Map<String, dynamic>.from(alert);

        // While Google Maps is guiding the driver to a selected rest stop,
        // keep recording the event but never stack another AlertScreen over
        // the navigation flow.
        if (TripTrackingService.instance.isNavigatingToRestStop) {
          debugPrint(
            'กำลังนำทางไปจุดพักรถ -> ไม่เปิด AlertScreen ซ้ำ '
            '(notification_id=$notificationId)',
          );
          return;
        }

        // 🆕 ถ้ากำลังอยู่ในโหมดพักรถ -> ระงับการเด้ง AlertScreen ไว้ก่อน
        // (ยังคงมาร์คว่าเห็น alert นี้แล้วเหมือนเดิม เพื่อไม่ให้เด้งซ้ำภายหลัง)
        if (RestModeService.instance.isActive) {
          debugPrint(
            "Rest Mode กำลังทำงานอยู่ (เหลือ ${RestModeService.instance.remaining.inMinutes} นาที) "
            "-> ระงับการแจ้งเตือน notification_id=$notificationId ไว้ก่อน",
          );
          return;
        }

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
            builder: (_) => AlertScreen(deviceId: alertData['device_id']),
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

class DeviceSection extends StatefulWidget {
  const DeviceSection({super.key});

  @override
  State<DeviceSection> createState() => _DeviceSectionState();
}

class _DeviceSectionState extends State<DeviceSection> {
  bool? _hasDevices;

  @override
  void initState() {
    super.initState();
    _loadDeviceState();
  }

  Future<void> _loadDeviceState() async {
    try {
      final devices = await ApiService.instance.devices();
      if (mounted) setState(() => _hasDevices = devices.isNotEmpty);
    } catch (_) {
      if (mounted) setState(() => _hasDevices = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasDevices == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasDevices!) {
      return DeviceManagementScreen(
        onDevicesEmpty: () => setState(() => _hasDevices = false),
      );
    }
    return DeviceRegistrationScreen(
      onRegistered: () => setState(() => _hasDevices = true),
    );
  }
}
