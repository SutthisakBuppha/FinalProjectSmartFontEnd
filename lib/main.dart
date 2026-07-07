import 'package:flutter/material.dart';
import 'splash_screen.dart'; // 💡 เพิ่ม import นี้
// welcome_screen.dart ไม่ต้อง import ตรงนี้แล้ว เพราะ splash_screen จะเป็นคนเรียกไปหาเอง
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
      home: const SplashScreen(), // 💡 เปลี่ยนจาก WelcomeScreen() เป็น SplashScreen()
    );
  }
}