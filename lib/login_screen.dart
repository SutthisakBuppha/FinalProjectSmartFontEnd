import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'signup_screen.dart';
import 'main_layout.dart';
import 'forgot_password_screen.dart';
import 'services/api_service.dart';
import 'google_auth_service.dart';

// นำเข้าจาก web_only.dart สำหรับดึงวิดเจ็ตแสดงผลปุ่ม Google บนเว็บ
import 'package:google_sign_in_web/web_only.dart' as gsi_web;
import 'package:flutter/foundation.dart' show kIsWeb;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final bool _isDarkMode = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // ขั้นตอนที่ 2.1: ดักฟังเหตุการณ์ Google Sign-In สำหรับการทำงานบน Web
    if (kIsWeb) {
      GoogleAuthService.instance.googleSignInEvents.listen((account) async {
        if (account != null) {
          final auth = await account.authentication;
          final token = auth.idToken ?? auth.accessToken;

          if (token != null) {
            setState(() => _isGoogleLoading = true);
            try {
              // เรียก api_service ส่ง Token ไปยัง Laravel backend
              await ApiService.instance.loginWithGoogle(idToken: token);
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MainLayout()),
                );
              }
            } on ApiException catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message)),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('เข้าสู่ระบบด้วย Google ไม่สำเร็จ: $e')),
                );
              }
            } finally {
              if (mounted) setState(() => _isGoogleLoading = false);
            }
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อผู้ใช้และรหัสผ่าน')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiService.instance.loginDriver(
        username: username,
        password: password,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainLayout()),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เข้าสู่ระบบไม่สำเร็จ กรุณาลองใหม่')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ฟังก์ชันล็อกอิน Google แบบดั้งเดิม (จะทำงานเฉพาะบน Mobile)
  Future<void> _handleGoogleLogin() async {
    setState(() => _isGoogleLoading = true);

    try {
      final idToken = await GoogleAuthService.instance.signInAndGetIdToken();

      if (idToken == null) {
        return;
      }

      await ApiService.instance.loginWithGoogle(idToken: idToken);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainLayout()),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เข้าสู่ระบบด้วย Google ไม่สำเร็จ กรุณาลองใหม่')),
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  // --- Color Palette ---
  Color get primary => const Color(0xFF0F284E);
  Color get secondary => const Color(0xFF3B5998);
  Color get background =>
      _isDarkMode ? const Color(0xFF0A1120) : const Color(0xFFFFFFFF);
  Color get surface =>
      _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
  Color get textMain =>
      _isDarkMode ? const Color(0xFFE2E8F0) : const Color(0xFF0F284E);
  Color get textSub =>
      _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get inputBorder =>
      _isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get iconColor =>
      _isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  Color get focusRing => primary.withOpacity(0.2);

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
      backgroundColor: background,
      resizeToAvoidBottomInset: true,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: background,
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 256,
                height: 256,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withOpacity(0.05),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.05),
                      blurRadius: 100,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 160,
              left: -80,
              child: Container(
                width: 192,
                height: 192,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withOpacity(0.05),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.05),
                      blurRadius: 100,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 16,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      children: [
                        SizedBox(height: isCompactHeight ? 8 : 20),
                        SizedBox(
                          width: logoSize,
                          height: logoSize,
                          child: SvgPicture.string(
                            _logoSvgString(_isDarkMode),
                          ),
                        ),
                        SizedBox(height: 16 * scale),
                        Text(
                          "Smart Drive Guard",
                          style: GoogleFonts.prompt(
                            fontSize: 28 * scale,
                            fontWeight: FontWeight.w700,
                            color: primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 8 * scale),
                        Text(
                          "ระบบติดตามอัจฉริยะ เพื่อการขับขี่ที่ปลอดภัย",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.prompt(
                            fontSize: 13 * scale,
                            fontWeight: FontWeight.w400,
                            color: textSub,
                          ),
                        ),
                        SizedBox(height: (isCompactHeight ? 24 : 36) * scale),
                        Text(
                          "ยินดีต้อนรับกลับ",
                          style: GoogleFonts.prompt(
                            fontSize: 22 * scale,
                            fontWeight: FontWeight.w600,
                            color: primary,
                          ),
                        ),
                        SizedBox(height: 4 * scale),
                        Text(
                          "กรุณากรอกข้อมูลเพื่อเข้าสู่ระบบ",
                          style: GoogleFonts.prompt(
                            fontSize: 13 * scale,
                            color: textSub,
                          ),
                        ),
                        SizedBox(height: 22 * scale),
                        _buildLabel("ชื่อผู้ใช้ (Username)", scale),
                        SizedBox(height: 6 * scale),
                        _buildTextField(
                          controller: _usernameController,
                          hint: "username",
                          icon: Icons.person_outline,
                          inputType: TextInputType.text,
                          scale: scale,
                        ),
                        SizedBox(height: 18 * scale),
                        _buildLabel("รหัสผ่าน", scale),
                        SizedBox(height: 6 * scale),
                        _buildTextField(
                          controller: _passwordController,
                          hint: "••••••••",
                          icon: Icons.lock_outline,
                          isPassword: true,
                          scale: scale,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.only(top: 8.0 * scale),
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                "ลืมรหัสผ่าน?",
                                style: GoogleFonts.prompt(
                                  fontSize: 12 * scale,
                                  fontWeight: FontWeight.w500,
                                  color: primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 14 * scale),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: primary.withOpacity(0.08),
                                offset: const Offset(0, 4),
                                blurRadius: 20,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(vertical: 15 * scale),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "เข้าสู่ระบบ",
                                        style: GoogleFonts.prompt(
                                          fontSize: 15 * scale,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: 8 * scale),
                                      Icon(Icons.arrow_forward, size: 18 * scale),
                                    ],
                                  ),
                          ),
                        ),
                        SizedBox(height: (isCompactHeight ? 18 : 24) * scale),
                        Row(
                          children: [
                            Expanded(child: Divider(color: inputBorder)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0 * scale),
                              child: Text(
                                "หรือเข้าสู่ระบบด้วย",
                                style: GoogleFonts.prompt(
                                  fontSize: 12 * scale,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: inputBorder)),
                          ],
                        ),
                        SizedBox(height: (isCompactHeight ? 18 : 24) * scale),
                        
                        // 🛠️ ตรวจสอบเรียบร้อย: วิดเจ็ตปุ่ม Google สำหรับ Web และ Mobile ทำงานปกติ ไร้ตัวอักษรพิมพ์ตกค้าง
                        kIsWeb
                            ? SizedBox(
                                width: double.infinity,
                                height: 46 * scale,
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
                            : Row(
                                children: [
                                  Expanded(
                                    child: _buildSocialButton(
                                      label: "Google",
                                      svgIcon: _googleSvg,
                                      isLoading: _isGoogleLoading,
                                      onTap: _isGoogleLoading ? null : _handleGoogleLogin,
                                      scale: scale,
                                    ),
                                  ),
                                ],
                              ),
                        SizedBox(height: (isCompactHeight ? 20 : 32) * scale),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "ยังไม่มีบัญชี?",
                              style: GoogleFonts.prompt(
                                fontSize: 13 * scale,
                                color: textSub,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SignUpScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: 4 * scale),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                "สมัครสมาชิก",
                                style: GoogleFonts.prompt(
                                  fontSize: 13 * scale,
                                  fontWeight: FontWeight.w700,
                                  color: primary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: (isCompactHeight ? 16 : 24) * scale),
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

  Widget _buildLabel(String text, double scale) {
    return Padding(
      padding: EdgeInsets.only(left: 4.0 * scale),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: GoogleFonts.prompt(
            fontSize: 13 * scale,
            fontWeight: FontWeight.w500,
            color: primary,
          ),
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
    TextInputType inputType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: inputBorder),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        keyboardType: inputType,
        style: GoogleFonts.prompt(fontSize: 14 * scale, color: textMain),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.prompt(color: const Color(0xFF94A3B8)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14 * scale),
          prefixIcon: Icon(icon, color: iconColor, size: 20 * scale),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: iconColor,
                    size: 20 * scale,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String label,
    required String svgIcon,
    required VoidCallback? onTap,
    required double scale,
    bool isLoading = false,
  }) {
    return Container(
      height: 46 * scale,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: inputBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                SvgPicture.string(svgIcon, width: 20 * scale, height: 20 * scale),
                SizedBox(width: 8 * scale),
                Text(
                  label,
                  style: GoogleFonts.prompt(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF475569),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _logoSvgString(bool dark) {
    const textColor = "#0F284E";
    const strokeColor = "#0F284E";
    const bgColor = "#FFFFFF";

    return '''
    <svg viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M50 10C27.9086 10 10 27.9086 10 50C10 72.0914 27.9086 90 50 90C72.0914 90 90 72.0914 90 50C90 27.9086 72.0914 10 50 10ZM50 82C32.3269 82 18 67.6731 18 50C18 32.3269 32.3269 18 50 18C67.6731 18 82 32.3269 82 50C82 67.6731 67.6731 82 50 82Z" fill="$textColor"/>
      <path d="M22 45H35L42 30L50 60L58 40L65 45H78" stroke="$strokeColor" stroke-width="4" stroke-linecap="round" stroke-linejoin="round" fill="$bgColor" />
      <path d="M50 18V35" stroke="$strokeColor" stroke-linecap="round" stroke-width="6"/>
      <path d="M30 68L42 55" stroke="$strokeColor" stroke-linecap="round" stroke-width="6"/>
      <path d="M70 68L58 55" stroke="$strokeColor" stroke-linecap="round" stroke-width="6"/>
    </svg>
    ''';
  }

  final String _googleSvg = '''
  <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
    <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
    <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
    <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.26.81-.58z" fill="#FBBC05"/>
    <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.97 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
  </svg>
  ''';
}