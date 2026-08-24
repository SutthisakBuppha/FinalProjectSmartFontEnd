import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';
import '/services/api_service.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  // ส่งคำขอรหัส OTP ไปที่ backend จริง
  void _handleResetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกอีเมล')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.instance.forgotPasswordDriver(email: email);
      if (!mounted) return;
      _showSuccessDialog();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งคำขอไม่สำเร็จ กรุณาลองใหม่')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.cFFD1FAE5,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.success,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "ส่งรหัสยืนยันสำเร็จ!",
              style: GoogleFonts.prompt(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "กรุณาตรวจสอบอีเมลของคุณ\nเพื่อนำรหัส OTP มากรอกตั้งรหัสผ่านใหม่",
              textAlign: TextAlign.center,
              style: GoogleFonts.prompt(fontSize: 14, color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ResetPasswordScreen(
                        email: _emailController.text.trim(),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "กรอกรหัสยืนยัน",
                  style: GoogleFonts.prompt(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.lock_reset_rounded,
                size: 48,
                color: AppColors.primaryLight,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "ลืมรหัสผ่าน?",
              style: GoogleFonts.prompt(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            // ↓ แก้ข้อความให้ตรงกับ flow จริง: ส่งรหัส OTP ไม่ใช่ลิงก์
            Text(
              "ไม่ต้องกังวล! กรุณากรอกอีเมลที่เชื่อมโยงกับบัญชีของคุณ เราจะส่งรหัสยืนยัน 6 หลักไปที่อีเมลของคุณเพื่อตั้งรหัสผ่านใหม่",
              style: GoogleFonts.prompt(
                fontSize: 16,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "อีเมล",
              style: GoogleFonts.prompt(
                fontWeight: FontWeight.w600,
                color: AppColors.text,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: "example@email.com",
                hintStyle: GoogleFonts.prompt(color: Colors.grey.shade400),
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: Colors.grey.shade400,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleResetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  shadowColor: AppColors.primaryDark.withOpacity(0.3),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    // ↓ แก้ข้อความปุ่มจาก "ส่งลิงก์รีเซ็ตรหัสผ่าน" เป็นข้อความที่ตรงกับ OTP จริง
                    : Text(
                        "ส่งรหัสยืนยันรีเซ็ตรหัสผ่าน",
                        style: GoogleFonts.prompt(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
