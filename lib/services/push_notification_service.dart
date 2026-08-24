import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import '/alert_screen.dart';

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  // Do not resolve FirebaseMessaging while constructing this singleton.
  // MainLayout can be created before Firebase.initializeApp() finishes.
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;

  static const AndroidNotificationChannel _alertChannel =
      AndroidNotificationChannel(
        'drive_guard_alerts',
        'แจ้งเตือนความเสี่ยงขณะขับขี่',
        description: 'แจ้งเตือนเมื่อพบพฤติกรรมเสี่ยงครบตามเงื่อนไข',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    _navigatorKey = navigatorKey;

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
      _navigateToAlert(message.data);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _navigateToAlert(initialMessage.data);
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

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'drive_guard_alerts',
          'แจ้งเตือนความเสี่ยงขณะขับขี่',
          icon: 'ic_notification',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode({
        'action': 'alert',
        'device_id': message.data['device_id']?.toString() ?? '',
      }),
    );

    _navigateToAlert(message.data);
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
        _navigateToAlert(data);
        return;
      }
    } catch (_) {
      // Support notification payloads created by older app versions.
    }
    _navigateToAlert({'device_id': payload});
  }

  Future<void> showQrLinkNotification(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw const FormatException('QR Code นี้ไม่ใช่ลิงก์ http/https');
    }

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      'สแกน QR Code สำเร็จ',
      url,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'qr_scan_results',
          'ลิงก์จาก QR Code',
          icon: 'ic_notification',
          channelDescription: 'แสดงลิงก์ที่อ่านได้จาก QR Code',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode({'action': 'qr_link', 'url': url}),
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
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => AlertScreen(deviceId: data['device_id']),
      ),
    );
  }
}
