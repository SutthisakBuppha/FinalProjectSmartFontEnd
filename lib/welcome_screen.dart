import 'dart:async'; // 1. เพิ่ม import นี้สำหรับ Timer
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart'; // Import หน้า Login

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // สีที่ดึงมาจาก Config ของ Tailwind ในไฟล์ HTML
  static const Color primaryColor = Color(0xFF0F284E);
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color blue50 = Color(0xFFEFF6FF);
  static const Color blue900 = Color(0xFF1E3A8A);

  Timer? _timer; // ตัวแปรเก็บ Timer

  @override
  void initState() {
    super.initState();
    // --- 2. จับเวลา 5 วินาที ด้วย Timer (ปลอดภัยกว่า Future.delayed) ---
    _timer = Timer(const Duration(seconds: 5), _navigateToLogin);
  }

  // ฟังก์ชันสำหรับเปลี่ยนหน้า
  void _navigateToLogin() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // 3. ยกเลิก Timer ถ้าปิดหน้าจอก่อนครบเวลา
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // พื้นหลัง Gradient
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [slate50, Colors.white],
          ),
        ),
        child: Stack(
          children: [
            // 1. Background Blobs (วงกลมเบลอๆ ด้านหลัง)
            // Top Right Blob
            Positioned(
              top: -160,
              right: -160,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: blue50.withOpacity(0.6),
                ),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    boxShadow: [
                      BoxShadow(
                        color: blue50,
                        blurRadius: 100,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Left Blob
            Positioned(
              bottom: -160,
              left: -160,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: slate100.withOpacity(0.6),
                ),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    boxShadow: [
                      BoxShadow(
                        color: slate100,
                        blurRadius: 100,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Main Content
            SafeArea(
              child: Column(
                children: [
                  // --- Status Bar (Simulated to match HTML) ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "9:41",
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: primaryColor.withOpacity(0.8),
                          ),
                        ),
                        Row(
                          children: [
                            _buildStatusIcon(Icons.signal_cellular_alt),
                            const SizedBox(width: 6),
                            _buildStatusIcon(Icons.wifi),
                            const SizedBox(width: 6),
                            _buildStatusIcon(Icons.battery_full),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Spacer(), // ดันเนื้อหาตรงกลาง

                  // --- Center Content (Logo & Title) ---
                  Transform.translate(
                    offset: const Offset(0, -30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo Container
                        SizedBox(
                          width: 128,
                          height: 128,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Glow effect behind logo
                              Container(
                                width: 128,
                                height: 128,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: blue900.withOpacity(0.1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: blue900.withOpacity(0.1),
                                      blurRadius: 24,
                                      spreadRadius: 5,
                                    )
                                  ],
                                ),
                              ),
                              // SVG Logo
                              SvgPicture.string(
                                _logoSvgString,
                                width: 100,
                                height: 100,
                                colorFilter: const ColorFilter.mode(
                                  primaryColor,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32), // mb-8
                        
                        // Text Content
                        Text(
                          "Smart Drive Guard",
                          style: GoogleFonts.outfit(
                            fontSize: 36, // ~text-4xl
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                            height: 1.1,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "สำหรับผู้ขับรถ",
                          style: GoogleFonts.outfit(
                            fontSize: 14, // text-sm
                            fontWeight: FontWeight.w500,
                            color: primaryColor.withOpacity(0.7),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(), // ดัน Footer ลงล่าง

                  // --- Footer (Spinner & Powered By) ---
                  Column(
                    children: [
                      // Spinner (Custom CircularProgressIndicator)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryColor,
                          backgroundColor: slate200,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "POWERED BY AI",
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: slate400,
                          letterSpacing: 2.5, // tracking-[0.25em]
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48), // pb-12
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper สำหรับสร้างไอคอน Status bar
  Widget _buildStatusIcon(IconData icon) {
    return Icon(
      icon,
      size: 16, // text-sm
      color: primaryColor.withOpacity(0.8),
    );
  }

  // SVG String จาก HTML
  static const String _logoSvgString = '''
  <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
    <path d="M50 10C27.9086 10 10 27.9086 10 50C10 72.0914 27.9086 90 50 90C72.0914 90 90 72.0914 90 50C90 27.9086 72.0914 10 50 10ZM50 82C32.3269 82 18 67.6731 18 50C18 32.3269 32.3269 18 50 18C67.6731 18 82 32.3269 82 50C82 67.6731 67.6731 82 50 82Z" fill="currentColor"/>
    <path d="M50 18V35" stroke="currentColor" stroke-linecap="round" stroke-width="6"/>
    <path d="M30 68L42 55" stroke="currentColor" stroke-linecap="round" stroke-width="6"/>
    <path d="M70 68L58 55" stroke="currentColor" stroke-linecap="round" stroke-width="6"/>
    <path d="M22 45H35L42 30L50 60L58 40L65 45H78" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="4"/>
  </svg>
  ''';
}