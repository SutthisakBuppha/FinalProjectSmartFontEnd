import 'package:flutter/material.dart';

// Import หน้าจอต่างๆ
import 'home_screen.dart';
import 'history_screen.dart';
import 'notification_screen.dart'; 
import 'profile_screen.dart';      
import 'device_registration_screen.dart';
import 'risk_summary_screen.dart';
// Import ไฟล์ Navbar ของคุณ
import 'custom_bottom_nav_bar.dart'; 

class MainLayout extends StatefulWidget {
  // 1. เพิ่มตัวแปร initialIndex รับค่าเริ่มต้น
  final int initialIndex; 

  // 2. กำหนดค่า default เป็น 0 (หน้า Home)
  const MainLayout({super.key, this.initialIndex = 0}); 

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),          // Index 0
    const HistoryScreen(),       // Index 1
    const NotificationScreen(),  // Index 2
    const DeviceRegistrationScreen(),  // Index 3
    const RiskTrendsScreen(),  // Index 4
    const ProfileScreen(),       // Index 5
  ];

  @override
  void initState() {
    super.initState();
    // 3. กำหนดให้หน้าที่จะแสดง = ค่าที่รับเข้ามาตอนเริ่ม
    _selectedIndex = widget.initialIndex;
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