import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';
import '/alert_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📩 [Background] Alert แจ้งเตือนใหม่: ${message.data}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> initialize({required GlobalKey<NavigatorState> navigatorKey}) async {
    _navigatorKey = navigatorKey;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('🔔 Push permission: ${settings.authorizationStatus}');

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) => _handleNotificationTap(response.payload),
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await ApiService.instance.registerFcmToken(
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
      debugPrint('✅ ส่ง FCM token ไป backend สำเร็จ: ${token.substring(0, 12)}...');
    } catch (e) {
      debugPrint('❌ ส่ง FCM token ไม่สำเร็จ: $e');
    }

    _messaging.onTokenRefresh.listen((newToken) {
      ApiService.instance
          .registerFcmToken(token: newToken, platform: Platform.isIOS ? 'ios' : 'android')
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
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data['device_id']?.toString(),
    );

    _navigateToAlert(message.data);
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null) return;
    _navigateToAlert({'device_id': payload});
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