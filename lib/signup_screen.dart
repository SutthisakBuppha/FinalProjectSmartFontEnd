import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'google_auth_service.dart';
import 'google_signin_web_stub.dart'
    if (dart.library.js_interop) 'google_signin_web_impl.dart'
    as gsi_web;
import 'login_screen.dart';
import 'main_layout.dart';
import 'services/api_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  StreamSubscription? _googleSignInSub;

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;

  bool get isDark => Theme.of(context).brightness == Brightness.dark;
  Color get background => isDark ? AppColors.text : AppColors.surface;
  Color get surfaceColor => isDark ? AppColors.cFF1E293B : AppColors.surface;
  Color get borderColor => isDark ? AppColors.cFF374151 : AppColors.cFFE5E7EB;
  Color get textColor => isDark ? AppColors.background : AppColors.cFF112D4E;
  Color get placeholderColor =>
      isDark ? AppColors.cFF6B7280 : AppColors.cFF9CA3AF;
  Color get iconColor => isDark ? AppColors.cFF9CA3AF : AppColors.cFF112D4E;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      GoogleAuthService.instance.ensureInitialized().then((_) {
        // ให้ฟัง stream ที่คืนค่ามาเป็น idToken (String) โดยตรง
        _googleSignInSub = GoogleAuthService.instance.onIdTokenReceived.listen((
          token,
        ) async {
          if (token != null && mounted) {
            setState(() => _isGoogleLoading = true);
            try {
              await ApiService.instance.loginWithGoogle(idToken: token);
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const MainLayout()),
                  (route) => false,
                );
              }
            } on ApiException catch (e) {
              if (mounted) setState(() => _errorMessage = e.message);
            } catch (e) {
              if (mounted) {
                setState(
                  () => _errorMessage =
                      'สมัครสมาชิกด้วย Google ไม่สำเร็จ กรุณาลองใหม่',
                );
              }
            } finally {
              if (mounted) setState(() => _isGoogleLoading = false);
            }
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _googleSignInSub?.cancel();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      _errorMessage = null;
    });

    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() {
        _errorMessage = 'กรุณากรอกข้อมูลให้ครบทุกช่อง';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = 'รหัสผ่านและยืนยันรหัสผ่านไม่ตรงกัน';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.instance.registerDriver(
        name: username,
        username: username,
        email: email,
        password: password,
        passwordConfirmation: confirmPassword,
      );

      // Successfully registered -> redirect to login screen
      ApiService.instance.clearSession();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignUp() async {
    setState(() {
      _errorMessage = null;
      _isGoogleLoading = true;
    });

    try {
      final idToken = await GoogleAuthService.instance.signInAndGetIdToken();

      if (idToken == null) {
        return;
      }

      await ApiService.instance.loginWithGoogle(idToken: idToken);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainLayout()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e, st) {
      debugPrint('Google sign-up failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(
        () => _errorMessage = 'สมัครสมาชิกด้วย Google ไม่สำเร็จ กรุณาลองใหม่',
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    double scale = screenWidth / 375.0;
    scale = scale.clamp(0.85, 1.25);

    final horizontalPadding = (screenWidth * 0.08).clamp(20.0, 40.0);
    final logoSize = (96 * scale).clamp(72.0, 120.0);
    final isCompactHeight = screenHeight < 700;

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: isCompactHeight ? 12 : 24),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 10 * scale),

                    // Logo
                    SizedBox(
                      // 1. เพิ่มสเกลตั้งต้น และขยายเพดาน .clamp(min, max) ให้กว้างขึ้น
                      width: (250 * scale).clamp(180.0, 350.0),
                      height: (120 * scale).clamp(90.0, 180.0),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(height: (isCompactHeight ? 20 : 32) * scale),

                    Text(
                      "สมัครสมาชิก",
                      style: GoogleFonts.prompt(
                        fontSize: (24 * scale).clamp(20.0, 28.0),
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.cFF112D4E,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "ลงทะเบียนเพื่อเริ่มติดตามการขับขี่ของคุณ",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.prompt(
                        fontSize: 13 * scale,
                        color: isDark
                            ? AppColors.cFF9CA3AF
                            : AppColors.cFF6B7280,
                      ),
                    ),

                    SizedBox(height: 24 * scale),

                    // --- Google Sign-Up ---
                    kIsWeb
                        ? SizedBox(
                            width: double.infinity,
                            height: (48 * scale).clamp(44.0, 54.0),
                            child: gsi_web.renderButton(
                              configuration: gsi_web.GSIButtonConfiguration(
                                type: gsi_web.GSIButtonType.standard,
                                theme: gsi_web.GSIButtonTheme.filledBlue,
                                size: gsi_web.GSIButtonSize.large,
                                text: gsi_web.GSIButtonText.signinWith,
                                shape: gsi_web.GSIButtonShape.rectangular,
                              ),
                            ),
                          )
                        : SizedBox(
                            width: double.infinity,
                            height: (48 * scale).clamp(44.0, 54.0),
                            child: Material(
                              color: isDark
                                  ? AppColors.cFF1E293B
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: _isGoogleLoading
                                    ? null
                                    : _handleGoogleSignUp,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.border),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_isGoogleLoading)
                                        SizedBox(
                                          width: 18 * scale,
                                          height: 18 * scale,
                                          child:
                                              const CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                        )
                                      else ...[
                                        SvgPicture.string(
                                          _googleSvg,
                                          width: 20 * scale,
                                          height: 20 * scale,
                                        ),
                                        SizedBox(width: 8 * scale),
                                        Text(
                                          "สมัครสมาชิกด้วย Google",
                                          style: GoogleFonts.prompt(
                                            fontSize: 14 * scale,
                                            fontWeight: FontWeight.w500,
                                            color: textColor,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                    SizedBox(height: 20 * scale),
                    Row(
                      children: [
                        Expanded(child: Divider(color: AppColors.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            "หรือสมัครด้วยอีเมล",
                            style: GoogleFonts.prompt(
                              fontSize: 12 * scale,
                              color: placeholderColor,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: AppColors.border)),
                      ],
                    ),
                    SizedBox(height: 20 * scale),

                    // --- Form Fields ---
                    _buildTextField(
                      controller: _usernameController,
                      hint: "ชื่อผู้ใช้ (Username)",
                      icon: Icons.account_circle_outlined,
                      inputType: TextInputType.text,
                      scale: scale,
                    ),
                    SizedBox(height: 16 * scale),

                    _buildTextField(
                      controller: _emailController,
                      hint: "อีเมล",
                      icon: Icons.email_outlined,
                      inputType: TextInputType.emailAddress,
                      scale: scale,
                    ),
                    SizedBox(height: 16 * scale),

                    _buildTextField(
                      controller: _passwordController,
                      hint: "รหัสผ่าน",
                      icon: Icons.lock_outline,
                      isPassword: true,
                      isObscure: _obscurePassword,
                      scale: scale,
                      onToggleVisibility: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    SizedBox(height: 16 * scale),

                    _buildTextField(
                      controller: _confirmPasswordController,
                      hint: "ยืนยันรหัสผ่าน",
                      icon: Icons.verified_user_outlined,
                      isPassword: true,
                      isObscure: _obscureConfirmPassword,
                      scale: scale,
                      onToggleVisibility: () {
                        setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        );
                      },
                    ),

                    if (_errorMessage != null) ...[
                      SizedBox(height: 16 * scale),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cFFFEF2F2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cFFFCA5A5),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.prompt(
                            fontSize: 13 * scale,
                            color: AppColors.cFFB91C1C,
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: 24 * scale),

                    // --- Register Button ---
                    Container(
                      width: double.infinity,
                      height: (56 * scale).clamp(48.0, 64.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: AppColors.cFF112D4E.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cFF112D4E,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.cFF112D4E
                              .withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          padding: EdgeInsets.zero,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 20 * scale,
                                height: 20 * scale,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "ลงทะเบียน",
                                    style: GoogleFonts.prompt(
                                      fontSize: 16 * scale,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 8 * scale),
                                  Icon(Icons.arrow_forward, size: 20 * scale),
                                ],
                              ),
                      ),
                    ),

                    SizedBox(height: 32 * scale),

                    // --- Login Redirect ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "มีบัญชีอยู่แล้วใช่ไหม?",
                          style: GoogleFonts.prompt(
                            fontSize: 14 * scale,
                            color: isDark
                                ? AppColors.cFF9CA3AF
                                : AppColors.cFF6B7280,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            "เข้าสู่ระบบ",
                            style: GoogleFonts.prompt(
                              fontSize: 14 * scale,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.cFF112D4E,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: (isCompactHeight ? 24 : 40) * scale),

                    // Bottom Accent Line
                    Container(
                      width: 64 * scale,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.cFF1F2937
                            : AppColors.cFFE5E7EB,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    SizedBox(height: 16 * scale),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required IconData icon,
    required double scale,
    TextEditingController? controller,
    bool isPassword = false,
    bool isObscure = false,
    VoidCallback? onToggleVisibility,
    TextInputType inputType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? isObscure : false,
        keyboardType: inputType,
        style: GoogleFonts.prompt(color: textColor, fontSize: 16 * scale),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.prompt(
            color: placeholderColor,
            fontSize: 15 * scale,
          ),
          filled: true,
          fillColor: isDark ? AppColors.cFF1E293B : AppColors.surface,
          contentPadding: EdgeInsets.symmetric(
            vertical: 18 * scale,
            horizontal: 16,
          ),
          prefixIcon: Icon(icon, color: iconColor, size: 22 * scale),
          suffixIcon: onToggleVisibility != null
              ? IconButton(
                  icon: Icon(
                    isObscure ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.cFF9CA3AF,
                    size: 22 * scale,
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.cFF112D4E, width: 2),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  static const String _logoSvg = '''
  <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
    <path clip-rule="evenodd" d="M50 10C27.9086 10 10 27.9086 10 50C10 72.0914 27.9086 90 50 90C72.0914 90 90 72.0914 90 50C90 27.9086 72.0914 10 50 10ZM4 50C4 24.5949 24.5949 4 50 4C75.4051 4 96 24.5949 96 50C96 75.4051 75.4051 96 50 96C24.5949 96 4 75.4051 4 50Z" fill-rule="evenodd"/>
    <path d="M15 50H35L42 35L50 65L58 35L65 50H85" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="6"/>
    <path d="M50 65V90" stroke="currentColor" stroke-linecap="round" stroke-width="6"/>
    <path d="M22 72L35 60" stroke="currentColor" stroke-linecap="round" stroke-width="6"/>
    <path d="M78 72L65 60" stroke="currentColor" stroke-linecap="round" stroke-width="6"/>
  </svg>
  ''';

  static const String _googleSvg = '''
  <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
    <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
    <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
    <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.26.81-.58z" fill="#FBBC05"/>
    <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
  </svg>
  ''';
}
