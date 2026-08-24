import 'dart:async';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    double scale = screenWidth / 375.0;
    scale = scale.clamp(0.85, 1.25);

    final horizontalPadding = (screenWidth * 0.08).clamp(20.0, 40.0);
    final logoBoxSize = (128 * scale).clamp(96.0, 160.0);
    final logoImageSize = (100 * scale).clamp(76.0, 124.0);
    final isCompactHeight = screenHeight < 700;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background, Colors.white],
          ),
        ),
        child: Stack(
          children: [
            // Top Right Blob
            Positioned(
              top: -160,
              right: -160,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cFFEFF6FF.withOpacity(0.6),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cFFEFF6FF,
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
                  color: AppColors.cFFF1F5F9.withOpacity(0.6),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cFFF1F5F9,
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
                                        color: AppColors.primaryLight.withOpacity(0.1),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primaryLight.withOpacity(0.1),
                                            blurRadius: 24,
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Image Logo
                                    Image.asset(
                                      'assets/images/logo.png', // เปลี่ยน Path ให้ตรงกับไฟล์รูปของคุณ
                                      width: logoImageSize,
                                      height: logoImageSize,
                                      fit: BoxFit.contain,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: (isCompactHeight ? 20 : 32) * scale),

                              // Text Content
                              Text(
                                "Smart Drive Guard",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.prompt(
                                  fontSize: (32 * scale).clamp(26.0, 38.0),
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.cFF0F284E,
                                  height: 1.1,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 8 * scale),
                              Text(
                                "สำหรับผู้ขับรถ",
                                style: GoogleFonts.prompt(
                                  fontSize: 13 * scale,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.cFF0F284E.withOpacity(0.7),
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
                                color: AppColors.cFF0F284E,
                                backgroundColor: AppColors.border,
                              ),
                            ),
                            SizedBox(height: 16 * scale),
                            Text(
                              "POWERED BY AI",
                              style: GoogleFonts.prompt(
                                fontSize: 10 * scale,
                                fontWeight: FontWeight.w700,
                                color: AppColors.cFF94A3B8,
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
}