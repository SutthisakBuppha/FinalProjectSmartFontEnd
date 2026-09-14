import 'dart:async';
import 'package:flutter/material.dart';
import '/services/api_service.dart';
import '/services/rest_mode_service.dart';
import '/services/trip_tracking_service.dart';
import '/services/push_notification_service.dart';
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
  final bool openSleepRestMode;

  const MainLayout({
    super.key,
    this.initialIndex = 0,
    this.openSleepRestMode = false,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  bool _sessionReady = false;

  Timer? _pollingTimer;
  Timer? _riskPollingTimer;
  bool _isShowingAlert = false;
  bool _isPollingNotifications = false;
  dynamic _lastSeenNotificationId;
  bool _notificationBaselineReady = false;
  bool _isPollingRiskEvents = false;
  bool _riskBaselineReady = false;
  dynamic _lastSeenAlertId;
  late final DateTime _riskPollingStartedAt;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _riskPollingStartedAt = DateTime.now().toUtc();
    _selectedIndex = widget.initialIndex;
    _screens = [
      HomeScreen(
        autoOpenSleepRestMode: widget.openSleepRestMode,
        onAutoRestModeConsumed: _consumeAutoSleepRestMode,
      ), // Index 0
      const HistoryScreen(), // Index 1
      const NotificationScreen(), // Index 2
      const DeviceSection(), // Index 3
      const RiskTrendsScreen(), // Index 4
      const ProfileScreen(), // Index 5
    ];
    _initializeAuthenticatedLayout();
  }

  void _consumeAutoSleepRestMode() {
    // คำสั่งจากหน้า Map ใช้ได้เพียงครั้งเดียว หากผู้ใช้สลับเมนูแล้วกลับ Home
    // จะสร้าง HomeScreen ปกติและไม่เปิดตัวเลือกเวลาพักซ้ำอีก
    _screens[0] = const HomeScreen();
  }

  Future<void> _initializeAuthenticatedLayout() async {
    final hasSession =
        ApiService.instance.isLoggedIn ||
        await ApiService.instance.restoreSession();

    if (!mounted) return;
    if (!hasSession) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      return;
    }

    setState(() => _sessionReady = true);

    // โหลดสถานะโหมดพักรถที่เคย persist ไว้ (เผื่อผู้ใช้ปิด-เปิดแอประหว่างพักรถ)
    RestModeService.instance.ensureInitialized();
    unawaited(TripTrackingService.instance.restore());
    unawaited(PushNotificationService.instance.registerTokenWithBackend());
    _startNotificationPolling();
    _startRiskEventPolling();
  }

  void _startRiskEventPolling() {
    _riskPollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || _isPollingRiskEvents || !ApiService.instance.isLoggedIn) {
        return;
      }

      _isPollingRiskEvents = true;
      try {
        final alerts = await ApiService.instance.alerts(limit: 3);
        final latestAlert = alerts.isEmpty ? null : alerts.first;
        final alertId = latestAlert?['alert_id'];

        final isFirstPoll = !_riskBaselineReady;
        if (isFirstPoll) {
          _lastSeenAlertId = alertId;
          _riskBaselineReady = true;
          final timestamp = DateTime.tryParse(
            latestAlert?['timestamp']?.toString() ?? '',
          )?.toUtc();
          if (timestamp == null || timestamp.isBefore(_riskPollingStartedAt)) {
            return;
          }
        }
        if (alertId == null ||
            (!isFirstPoll && alertId == _lastSeenAlertId)) {
          return;
        }
        _lastSeenAlertId = alertId;

        if (PushNotificationService.instance.wasAlertHandled(alertId)) return;
        if (RestModeService.instance.isActive ||
            TripTrackingService.instance.isNavigatingToRestStop) {
          return;
        }

        final latestIsCritical = latestAlert?['notifications_exists'] == true ||
            latestAlert?['notifications_exists'] == 1;
        if (latestIsCritical) {
          return;
        }

        var eventCount = 0;
        for (final alert in alerts) {
          final isCritical = alert['notifications_exists'] == true ||
              alert['notifications_exists'] == 1;
          if (isCritical) break;
          eventCount++;
        }

        await PushNotificationService.instance.showRiskEventFromPolling(
          alertId: alertId.toString(),
          deviceId: latestAlert?['device_id']?.toString() ?? '',
          type: latestAlert?['type']?.toString() ?? 'ไม่ระบุประเภท',
          eventCount: eventCount.clamp(1, 2).toInt(),
        );
      } catch (error) {
        debugPrint('Polling risk event error: $error');
      } finally {
        _isPollingRiskEvents = false;
      }
    });
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
      if (!mounted || _isShowingAlert || _isPollingNotifications) return;
      if (!ApiService.instance.isLoggedIn) return;

      _isPollingNotifications = true;
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
        if (PushNotificationService.instance.wasCriticalNotificationHandled(
          notificationId,
        )) {
          return;
        }
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

        try {
          await PushNotificationService.instance.showCriticalFromPolling(
            notificationId: notificationId.toString(),
            alertId: alertData['alert_id']?.toString() ?? '',
            deviceId: alertData['device_id']?.toString() ?? '',
            type: alertData['type']?.toString() ?? 'ไม่ระบุประเภท',
          );
        } finally {
          _isShowingAlert = false;
        }
      } catch (e) {
        debugPrint("Polling Alert Error: $e");
      } finally {
        _isPollingNotifications = false;
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _riskPollingTimer?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
