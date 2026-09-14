import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'language_service.dart';
import '/alert_screen.dart';
import '/risk_event_dialog.dart';
import 'rest_mode_service.dart';
import 'trip_tracking_service.dart';

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  // Do not resolve FirebaseMessaging while constructing this singleton.
  // MainLayout can be created before Firebase.initializeApp() finishes.
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;
  bool _isShowingEventDialog = false;
  String? _lastHandledCriticalNotificationId;
  String? _lastHandledAlertId;

  bool wasCriticalNotificationHandled(dynamic notificationId) =>
      notificationId != null &&
      notificationId.toString() == _lastHandledCriticalNotificationId;

  bool wasAlertHandled(dynamic alertId) =>
      alertId != null && alertId.toString() == _lastHandledAlertId;

  /// Attach navigation independently from Firebase. Flutter Web may not have
  /// Firebase configured, but API polling must still be able to show alerts.
  void attachNavigator(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  Future<void> showRiskEventFromPolling({
    required String alertId,
    required String deviceId,
    required String type,
    required int eventCount,
  }) {
    return _showRiskEventDialog({
      'alert_id': alertId,
      'device_id': deviceId,
      'type': type,
      'event_count': eventCount.toString(),
      'alert_level': 'event',
    });
  }

  Future<void> showCriticalFromPolling({
    required String notificationId,
    required String alertId,
    required String deviceId,
    required String type,
  }) {
    return _showCriticalSequence({
      'notification_id': notificationId,
      'alert_id': alertId,
      'device_id': deviceId,
      'type': type,
      'event_count': '3',
      'alert_level': 'critical',
    });
  }

  String _tr(String source) => LanguageController.instance.translate(source);

  AndroidNotificationChannel get _alertChannel => AndroidNotificationChannel(
    'drive_guard_alerts',
    _tr('แจ้งเตือนความเสี่ยงขณะขับขี่'),
    description: _tr('แจ้งเตือนเมื่อพบพฤติกรรมเสี่ยงครบตามเงื่อนไข'),
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    attachNavigator(navigatorKey);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('🔔 Push permission: ${settings.authorizationStatus}');

    const androidInit = AndroidInitializationSettings('ic_notification');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) async {
        await _handleNotificationTap(response.payload);
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_alertChannel);

    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleAlertData(message.data);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleAlertData(initialMessage.data);
    }
  }

  Future<void> registerTokenWithBackend() async {
    if (!ApiService.instance.isLoggedIn || kIsWeb) return;
    try {
      await Firebase.initializeApp();
      final token = await _messaging.getToken();
      if (token == null) return;
      await ApiService.instance.registerFcmToken(
        token: token,
        platform: defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      );
      debugPrint(
        '✅ ส่ง FCM token ไป backend สำเร็จ: ${token.substring(0, 12)}...',
      );
    } catch (e) {
      debugPrint('❌ ส่ง FCM token ไม่สำเร็จ: $e');
    }

    _messaging.onTokenRefresh.listen((newToken) {
      ApiService.instance
          .registerFcmToken(
            token: newToken,
            platform: defaultTargetPlatform == TargetPlatform.iOS
                ? 'ios'
                : 'android',
          )
          .catchError((e) => debugPrint('❌ Refresh FCM token ไม่สำเร็จ: $e'));
    });
  }

  Future<void> unregisterToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await ApiService.instance.unregisterFcmToken(token: token);
      }
    } catch (e) {
      debugPrint('❌ ยกเลิก FCM token ไม่สำเร็จ: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title == null ? null : _tr(notification.title!),
        notification.body == null ? null : _tr(notification.body!),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'drive_guard_alerts',
            _tr('แจ้งเตือนความเสี่ยงขณะขับขี่'),
            icon: 'ic_notification',
            importance: Importance.max,
            priority: Priority.high,
            playSound: false,
          ),
          iOS: const DarwinNotificationDetails(presentSound: false),
        ),
        payload: jsonEncode({'action': 'alert', ...message.data}),
      );
    }

    _handleAlertData(message.data);
  }

  Future<void> _handleNotificationTap(String? payload) async {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload);
      if (data is Map<String, dynamic> && data['action'] == 'qr_link') {
        final url = data['url']?.toString();
        if (url != null) {
          // Give Android time to resume the activity after the notification
          // launches the app before sending the browser intent.
          await Future<void>.delayed(const Duration(milliseconds: 500));
          await _openExternalUrl(url);
        }
        return;
      }
      if (data is Map<String, dynamic>) {
        _handleAlertData(data);
        return;
      }
    } catch (_) {
      // Support notification payloads created by older app versions.
    }
    _handleAlertData({'device_id': payload, 'alert_level': 'critical'});
  }

  Future<void> showQrLinkNotification(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw const FormatException('QR Code นี้ไม่ใช่ลิงก์ http/https');
    }

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      _tr('สแกน QR Code สำเร็จ'),
      url,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'qr_scan_results',
          _tr('ลิงก์จาก QR Code'),
          icon: 'ic_notification',
          channelDescription: _tr('แสดงลิงก์ที่อ่านได้จาก QR Code'),
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode({'action': 'qr_link', 'url': url}),
    );
  }

  Future<void> showRestModeEndingSoon() async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      _tr('โหมดพักรถใกล้สิ้นสุด'),
      _tr('ระบบจะกลับมาตรวจจับพฤติกรรมและแจ้งเตือนอีกครั้งใน 1 นาที'),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'rest_mode_status',
          _tr('สถานะโหมดพักรถ'),
          icon: 'ic_notification',
          channelDescription: _tr('แจ้งเตือนก่อนระบบกลับมาตรวจจับพฤติกรรม'),
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> showRestModeEnded() async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      _tr('หมดเวลาพักรถแล้ว'),
      _tr('ถึงเวลาตื่นและเตรียมพร้อมเดินทาง ระบบกลับมาตรวจจับตามปกติแล้ว'),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'rest_mode_status',
          _tr('สถานะโหมดพักรถ'),
          icon: 'ic_notification',
          channelDescription: _tr('แจ้งสถานะการเปิดและปิดโหมดพักรถ'),
          importance: Importance.high,
          priority: Priority.high,
          playSound: false,
        ),
        iOS: DarwinNotificationDetails(presentSound: false),
      ),
    );
  }

  Future<void> _openExternalUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  void _navigateToAlert(Map<String, dynamic> data) {
    _lastHandledCriticalNotificationId = data['notification_id']?.toString();
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => AlertScreen(deviceId: data['device_id']),
      ),
    );
  }

  void _handleAlertData(Map<String, dynamic> data) {
    if (RestModeService.instance.isActive ||
        TripTrackingService.instance.isNavigatingToRestStop) {
      return;
    }
    if (data['alert_level']?.toString() == 'event') {
      _showRiskEventDialog(data);
      return;
    }
    _showCriticalSequence(data);
  }

  Future<void> _showCriticalSequence(Map<String, dynamic> data) async {
    _lastHandledCriticalNotificationId = data['notification_id']?.toString();
    await _showRiskEventDialog({...data, 'event_count': '3'});
    if (RestModeService.instance.isActive ||
        TripTrackingService.instance.isNavigatingToRestStop) {
      return;
    }
    _navigateToAlert(data);
  }

  Future<void> _showRiskEventDialog(Map<String, dynamic> data) async {
    _lastHandledAlertId = data['alert_id']?.toString();
    if (_isShowingEventDialog) return;
    final context = _navigatorKey?.currentContext;
    if (context == null) return;
    _isShowingEventDialog = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => RiskEventDialog(
          deviceId: data['device_id']?.toString() ?? '',
          type: data['type']?.toString() ?? 'ไม่ระบุประเภท',
          eventCount:
              int.tryParse(data['event_count']?.toString() ?? '') ?? 1,
        ),
      );
    } finally {
      _isShowingEventDialog = false;
    }
  }
}
