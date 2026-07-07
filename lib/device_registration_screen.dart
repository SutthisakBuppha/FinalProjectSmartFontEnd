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
  bool _isLoading = false; 
  bool _isCheckingDevice = true; // สถานะตรวจเช็กข้อมูลเดิมตอนเปิดหน้าแอป

  @override
  void initState() {
    super.initState();
    _checkExistingDevices(); // เรียกใช้งานการตรวจสอบอัตโนมัติทันที
  }

  @override
  void dispose() {
    _serialController.dispose();
    super.dispose();
  }

  // ฟังก์ชันตรวจสอบ: ถ้ามีอุปกรณ์ที่เคยลงทะเบียนอยู่แล้ว ให้เปิดหน้ารายการอุปกรณ์ทันที
  Future<void> _checkExistingDevices() async {
    try {
      // เรียกใช้ devices() แบบไม่มี arguments ตามที่ ApiService ของคุณกำหนดไว้
      final devices = await ApiService.instance.devices();
      
      // ถ้าพบข้อมูลอุปกรณ์ในฐานข้อมูลแล้ว ให้ย้ายข้ามหน้านี้ไปหน้ารายการเลยครับ
      if (devices.isNotEmpty && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DeviceManagementScreen()),
        );
        return;
      }
    } catch (e) {
      debugPrint("Error auto-checking devices: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingDevice = false; // ตรวจสอบเสร็จสิ้น ปิดหน้าโหลดนิ่ง
        });
      }
    }
  }

  // ฟังก์ชันจัดการการลงทะเบียนอุปกรณ์ชิ้นใหม่
  Future<void> _handleRegistration() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // ดึง serial number จากกล่องข้อความ
        final serialNumber = _serialController.text.trim();

        // registerDevice รับ positional parameter และคืนค่าเป็น bool (ไม่ throw)
        final isSuccess = await ApiService.instance.registerDevice(serialNumber);

        if (!mounted) return;

        if (!isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("ลงทะเบียนไม่สำเร็จ: S/N นี้อาจถูกใช้ไปแล้ว หรือเซิร์ฟเวอร์มีปัญหา")),
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ลงทะเบียนอุปกรณ์สำเร็จแล้ว")),
        );

        // เมื่อลงทะเบียนเสร็จสำเร็จ ส่งไปยังหน้ารายการอุปกรณ์
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DeviceManagementScreen()),
        );

      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("เกิดข้อผิดพลาด: ${e.toString()}")),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // หากระบบกำลังเรียกเช็กประวัติอุปกรณ์เดิมจาก API ให้แสดงวงกลมโหลดข้อมูลสั้นๆ
    if (_isCheckingDevice) {
      return const Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          "ตั้งค่าอุปกรณ์",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                
                // 1. Welcome Header
                Text(
                  "ยินดีต้อนรับ!",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "กรุณาลงทะเบียนอุปกรณ์ของคุณเพื่อเริ่มต้นใช้งานระบบตรวจจับ",
                  style: GoogleFonts.notoSansThai(
                    fontSize: 15,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // 2. Warning Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: warningBgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: warningTextColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: warningTextColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "คำแนะนำ: หมายเลข Serial Number จะอยู่บนสติกเกอร์ที่ติดอยู่กับตัวเครื่องโปรดตรวจสอบให้ถูกต้อง",
                          style: GoogleFonts.notoSansThai(
                            fontSize: 13,
                            color: warningTextColor,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 3. Form Input Field
                Text(
                  "หมายเลข Serial Number อุปกรณ์",
                  style: GoogleFonts.notoSansThai(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _serialController,
                  decoration: InputDecoration(
                    hintText: "เช่น SD-AI-2024XXXX",
                    hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.qr_code_scanner_rounded, color: primaryColor),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: primaryColor, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.red, width: 1),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'กรุณากรอกหมายเลข Serial Number อุปกรณ์';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // 4. Shortcut link to Wi-Fi Provisioning
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      final serialNumber = _serialController.text.trim();
                      if (serialNumber.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("กรุณากรอก Serial Number ก่อนไปตั้งค่า Wi-Fi")),
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WifiProvisioningScreen(serialNumber: serialNumber),
                        ),
                      );
                    },
                    icon: const Icon(Icons.wifi_rounded, size: 18),
                    label: Text(
                      "เชื่อมต่อไวไฟให้อุปกรณ์",
                      style: GoogleFonts.notoSansThai(fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(foregroundColor: primaryColor),
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