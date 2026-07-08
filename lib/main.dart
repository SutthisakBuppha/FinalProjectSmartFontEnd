import 'package:flutter/material.dart';
import 'welcome_screen.dart'; // 💡 เปลี่ยนมาเรียกหน้า Welcome เป็นจุดเริ่มต้นแทน SplashScreen
import 'main_layout.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SaveDriveAi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F284E)),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(), // 💡 เปิดแอปแล้วไปหน้า Welcome ก่อนเสมอ
    );
  }
}