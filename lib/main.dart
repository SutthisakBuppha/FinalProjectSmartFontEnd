import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'theme/app_theme.dart';
import 'welcome_screen.dart';
import 'splash_screen.dart';
import 'main_layout.dart';
import 'services/text_scale_service.dart';
import 'services/push_notification_service.dart';

// 💡 ต้องแน่ใจว่า firebaseMessagingBackgroundHandler เป็น Top-level function สั่งงานนอก Class
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // 1. บังคับผูก Binding ของ Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. เรียก runApp() ขึ้นมาแสดงผลก่อนเพื่อป้องกันหน้าจอขาวค้าง
  runApp(const MyApp());

  // 3. เริ่มทำงาน Services เบื้องหลังหลังจากแอปเริ่มสร้าง UI แล้ว
  _initializeServices();
}

Future<void> _initializeServices() async {
  try {
    await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await PushNotificationService.instance.initialize(
      navigatorKey: navigatorKey,
    );
  } catch (e, stackTrace) {
    log('Firebase/Notification Initialization Error: $e', stackTrace: stackTrace);
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    TextScaleController.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TextScaleController.instance,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'SaveDriveAi',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          
          // 🏠 หน้าเริ่มต้นเมื่อเปิดแอป
          // ⚠️ ต้องเป็น SplashScreen เพื่อให้ restoreSession() ถูกเรียกก่อนเสมอ
          // ถ้าใช้ WelcomeScreen ตรงๆ แอปจะไม่มีโอกาสอ่าน token เก่าจาก
          // SharedPreferences กลับมาเลย ผลคือปิด-เปิดแอปใหม่ทีไรต้อง login ใหม่ทุกที
          home: const SplashScreen(),

          // 🟢 [เพิ่มจุดนี้] ลงทะเบียนเส้นทาง (Routes) ของระบบ
          routes: {
            '/login': (context) => const WelcomeScreen(), // หากมีหน้า LoginScreen แยก สามารถเปลี่ยนเป็น LoginScreen() ได้
            '/main': (context) => const MainLayout(),
          },

          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(
                  TextScaleController.instance.scaleFactor,
                ),
              ),
              child: child!,
            );
          },
        );
      },
    );
  }
}