import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';
import 'main_layout.dart';
import 'services/api_service.dart';
import 'google_auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController(); 
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;

  Color get primaryColor => const Color(0xFF112D4E);
  Color get primaryLight => const Color(0xFF274A75);

  bool get isDark => Theme.of(context).brightness == Brightness.dark;
  Color get backgroundColor =>
      isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);
  Color get surfaceColor =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  Color get borderColor =>
      isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
  Color get textColor =>
      isDark ? const Color(0xFFF8FAFC) : const Color(0xFF112D4E);
  Color get placeholderColor =>
      isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
  Color get iconColor =>
      isDark ? const Color(0xFF9CA3AF) : const Color(0xFF112D4E);

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose(); 
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim(); 
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      _errorMessage = null;
    });

    if (name.isEmpty ||
        username.isEmpty || 
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
        name: name,
        username: username, 
        email: email,
        password: password,
        passwordConfirmation: confirmPassword,
      );

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
      ApiService.instance.clearSession(); 

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
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
    // --- Responsive Helpers แบบเดียวกับหน้า Login ---
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    double scale = screenWidth / 375.0;
    scale = scale.clamp(0.85, 1.25);

    final horizontalPadding = (screenWidth * 0.08).clamp(20.0, 40.0);
    final logoSize = (96 * scale).clamp(72.0, 120.0);
    final isCompactHeight = screenHeight < 700;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // นำแถวเวลา แบตเตอรี่ ด้านบนสุดออกแล้ว เปลี่ยนเป็น Spacer ตัวเล็กแทนเพื่อความสวยงาม
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
                      width: logoSize,
                      height: logoSize,
                      child: SvgPicture.string(
                        _logoSvg,
                        colorFilter: ColorFilter.mode(
                          isDark ? Colors.white : primaryColor,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    SizedBox(height: 16 * scale),
                    
                    // Title
                    Text(
                      "Smart Drive Guard",
                      style: GoogleFonts.inter(
                        fontSize: (30 * scale).clamp(24.0, 34.0),
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : primaryColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: (isCompactHeight ? 20 : 32) * scale),
                    
                    Text(
                      "สมัครสมาชิก",
                      style: GoogleFonts.inter(
                        fontSize: (24 * scale).clamp(20.0, 28.0),
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "ลงทะเบียนเพื่อเริ่มติดตามการขับขี่ของคุณ",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.prompt( // เปลี่ยนเป็นฟอนต์ไทยให้อ่านง่ายสอดคล้องกัน
                        fontSize: 13 * scale,
                        color: isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280),
                      ),
                    ),

                    SizedBox(height: 24 * scale),

                    // --- Google Sign-Up ---
                    SizedBox(
                      width: double.infinity,
                      height: (48 * scale).clamp(44.0, 54.0),
                      child: Material(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _isGoogleLoading ? null : _handleGoogleSignUp,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: borderColor),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isGoogleLoading)
                                  SizedBox(
                                    width: 18 * scale,
                                    height: 18 * scale,
                                    child: const CircularProgressIndicator(
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
                        Expanded(child: Divider(color: borderColor)),
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
                        Expanded(child: Divider(color: borderColor)),
                      ],
                    ),
                    SizedBox(height: 20 * scale),

                    // --- Form Fields (Responsive padding) ---
                    // _buildTextField(
                    //   controller: _nameController,
                    //   hint: "ชื่อ-นามสกุล",
                    //   icon: Icons.person_outline,
                    //   inputType: TextInputType.name,
                    //   scale: scale,
                    // ),
                    // SizedBox(height: 16 * scale),

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
                          () => _obscureConfirmPassword = !_obscureConfirmPassword,
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
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.prompt(
                            fontSize: 13 * scale,
                            color: const Color(0xFFB91C1C),
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
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: primaryColor.withOpacity(0.6),
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
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF6B7280),
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
                              color: isDark ? Colors.white : primaryColor,
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
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFE5E7EB),
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
          hintStyle: GoogleFonts.prompt(color: placeholderColor, fontSize: 15 * scale),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          contentPadding: EdgeInsets.symmetric(
            vertical: 18 * scale,
            horizontal: 16,
          ),
          prefixIcon: Icon(icon, color: iconColor, size: 22 * scale),
          suffixIcon: onToggleVisibility != null
              ? IconButton(
                  icon: Icon(
                    isObscure ? Icons.visibility_off : Icons.visibility,
                    color: const Color(0xFF9CA3AF),
                    size: 22 * scale,
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: primaryColor, width: 2),
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