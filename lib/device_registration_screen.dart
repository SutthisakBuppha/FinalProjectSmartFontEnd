import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- Import ไฟล์ที่เกี่ยวข้อง ---
import 'devices_screen.dart';
import 'custom_bottom_nav_bar.dart';
import 'WifiProvisioningScreen.dart'; // ไปหน้าต่อ Wi-Fi (BLE)
import '/services/api_service.dart'; // ดึง ApiService มาใช้งาน

class DeviceRegistrationScreen extends StatefulWidget {
  const DeviceRegistrationScreen({super.key});

  @override
  State<DeviceRegistrationScreen> createState() => _DeviceRegistrationScreenState();
}

class _DeviceRegistrationScreenState extends State<DeviceRegistrationScreen> {
  static const Color primaryColor = Color(0xFF0F2557);
  static const Color backgroundColor = Color(0xFFF3F4F6);
  static const Color warningBgColor = Color(0xFFFFF7ED);
  static const Color warningTextColor = Color(0xFF9A3412);

  final TextEditingController _serialController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _currentIndex = 1; 
  bool _isLoading = false; // เพิ่มสถานะ Loading ป้องกันการกดปุ่มซ้ำ

  @override
  void dispose() {
    _serialController.dispose();
    super.dispose();
  }

  // ฟังก์ชันจัดการการลงทะเบียน
  Future<void> _handleRegistration() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true); // เปิดวงแหวนโหลดดิ่ง

      // ยิง API ไปที่ Laravel Backend เพื่อบันทึก S/N
      String serialNumber = _serialController.text.trim();
      bool isSuccess = await ApiService.instance.registerDevice(serialNumber);

      setState(() => _isLoading = false); // ปิดวงแหวนโหลดดิ่ง

      if (!mounted) return;

      if (isSuccess) {
        // [Success] บันทึกลง Database สำเร็จ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Text("ลงทะเบียนฐานข้อมูลสำเร็จ!", style: GoogleFonts.inter()),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 1),
          ),
        );
        
        // เด้งไปหน้าจับคู่ Bluetooth เพื่อส่งรหัส Wi-Fi ให้กล้อง
        Future.delayed(const Duration(seconds: 1), () {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => WifiProvisioningScreen(
                  serialNumber: serialNumber,
                ), 
              ),
            );
        });
      } else {
        // [Error] บันทึกไม่สำเร็จ (เช่น กรอก S/N ซ้ำ หรือเน็ตหลุด)
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              "ไม่สามารถลงทะเบียนได้",
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
            content: Text(
              "อุปกรณ์นี้อาจถูกลงทะเบียนไปแล้ว หรือระบบเซิร์ฟเวอร์มีปัญหา กรุณาลองใหม่อีกครั้ง",
              style: GoogleFonts.inter(),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("ตกลง", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: primaryColor)),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          "ลงทะเบียนอุปกรณ์",
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // 1. Icon Section
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.cast_connected_rounded,
                      size: 64,
                      color: primaryColor,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // 2. Title Text
                Text(
                  "เชื่อมต่ออุปกรณ์ SaveDrive",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "กรุณากรอก Serial Number (MAC) ที่อยู่ด้านหลังอุปกรณ์\nหรือสแกน QR Code เพื่อเริ่มต้นใช้งาน",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 40),

                // 3. Input Field (Serial Number)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Serial Number (S/N)",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _serialController,
                      enabled: !_isLoading, // ล็อกช่องกรอกหากกำลังโหลด
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                        letterSpacing: 1.0,
                      ),
                      decoration: InputDecoration(
                        hintText: "เช่น SN-2024-XXXX",
                        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                          borderSide: const BorderSide(color: primaryColor, width: 1.5),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          color: primaryColor,
                          onPressed: _isLoading ? null : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("กำลังเปิดกล้องสแกน QR Code...", style: GoogleFonts.inter()),
                                backgroundColor: primaryColor,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณากรอก Serial Number';
                        }
                        if (value.length < 5) {
                          return 'Serial Number สั้นเกินไป';
                        }
                        return null;
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 4. Policy Warning
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: warningBgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFF97316), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "ข้อกำหนดการใช้งาน",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: warningTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "1 บัญชีผู้ใช้ สามารถลงทะเบียนเชื่อมต่ออุปกรณ์ได้หลายอุปกณ์ แต่ละอุปกรณ์ต้องมี Serial Number ที่ไม่ซ้ำกัน กรุณาเก็บรักษา Serial Number ไว้ให้ดี",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: warningTextColor.withOpacity(0.8),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // 5. Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegistration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: primaryColor.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            "ลงทะเบียนอุปกรณ์",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}