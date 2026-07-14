import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // --- Color Palette (ปรับให้สอดคล้องกับ LoginScreen) ---
  Color get primaryColor => const Color(0xFF0F284E);
  Color get slate50 => const Color(0xFFF8FAFC);
  Color get slate100 => const Color(0xFFF1F5F9);
  Color get slate200 => const Color(0xFFE2E8F0);
  Color get slate400 => const Color(0xFF94A3B8);
  Color get blue50 => const Color(0xFFEFF6FF);
  Color get blue900 => const Color(0xFF1E3A8A);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 5), _navigateToLogin);
  }

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
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- Responsive Helpers (ถอดแบบมาจาก login_screen.dart) ---
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    double scale = screenWidth / 375.0;
    scale = scale.clamp(0.85, 1.25);

    final horizontalPadding = (screenWidth * 0.08).clamp(20.0, 40.0);
    final logoBoxSize = (128 * scale).clamp(96.0, 160.0);
    final logoSvgSize = (100 * scale).clamp(76.0, 124.0);
    final isCompactHeight = screenHeight < 700;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [slate50, Colors.white],
          ),
        ),
        child: Stack(
          children: [
            // Top Right Blob
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
                child: DecoratedBox(
                  // เอา const ตรงนี้ออก
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
                child: DecoratedBox(
                  // เอา const ตรงนี้ออกเช่นกันครับ
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

            // Main Content
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  // จำกัดความกว้างสูงสุดเหมือนหน้า login_screen
                  // เพื่อไม่ให้เนื้อหากระจาย/เพี้ยนบนจอกว้าง (เว็บ/เดสก์ท็อป)
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      children: [
                        SizedBox(height: isCompactHeight ? 12 : 24),

                    const Spacer(),

                    // --- Center Content (Logo & Title) ---
                    Transform.translate(
                      offset: Offset(0, isCompactHeight ? -12 : -30),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo Container
                          SizedBox(
                            width: logoBoxSize,
                            height: logoBoxSize,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Glow effect behind logo
                                Container(
                                  width: logoBoxSize,
                                  height: logoBoxSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: blue900.withOpacity(0.1),
                                    boxShadow: [
                                      BoxShadow(
                                        color: blue900.withOpacity(0.1),
                                        blurRadius: 24,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                ),
                                // SVG Logo
                                SvgPicture.string(
                                  _logoSvgString,
                                  width: logoSvgSize,
                                  height: logoSvgSize,
                                  colorFilter: ColorFilter.mode(
                                    primaryColor,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: (isCompactHeight ? 20 : 32) * scale),

                          // Text Content
                          Text(
                            "Smart Drive Guard",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: (32 * scale).clamp(26.0, 38.0),
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                              height: 1.1,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 8 * scale),
                          Text(
                            "สำหรับผู้ขับรถ",
                            style: GoogleFonts.prompt(
                              // เปลี่ยนเป็น Prompt เพื่อให้เข้ากับฟอนต์ภาษาไทยของหน้า Login
                              fontSize: 13 * scale,
                              fontWeight: FontWeight.w500,
                              color: primaryColor.withOpacity(0.7),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // --- Footer (Spinner & Powered By) ---
                    Column(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryColor,
                            backgroundColor: slate200,
                          ),
                        ),
                        SizedBox(height: 16 * scale),
                        Text(
                          "POWERED BY AI",
                          style: GoogleFonts.outfit(
                            fontSize: 10 * scale,
                            fontWeight: FontWeight.w700,
                            color: slate400,
                            letterSpacing: 2.5,
                          ),
                        ),
                      ],
                    ),
                        SizedBox(height: (isCompactHeight ? 28 : 48) * scale),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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