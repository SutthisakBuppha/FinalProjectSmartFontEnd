import 'package:flutter/material.dart';
import 'welcome_screen.dart';
// ไม่ต้อง import login_screen ที่นี่ เพราะ welcome_screen จะเป็นคนเรียกไปหาเอง
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
      home: const WelcomeScreen(), // เรียกหน้านี้เป็นหน้าแรก
    );
  }
}