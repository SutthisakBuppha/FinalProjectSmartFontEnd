import 'dart:convert';

import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

// --- Import ไฟล์ที่เกี่ยวข้อง ---
import 'WifiProvisioningScreen.dart';
import 'devices_screen.dart';
import '/services/api_service.dart';
import 'qr_scanner_screen.dart';

class DeviceRegistrationScreen extends StatefulWidget {
  const DeviceRegistrationScreen({super.key, this.onRegistered});

  final VoidCallback? onRegistered;

  @override
  State<DeviceRegistrationScreen> createState() =>
      _DeviceRegistrationScreenState();
}

class _DeviceRegistrationScreenState extends State<DeviceRegistrationScreen> {
  final TextEditingController _serialController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _currentIndex = 1;
  bool _isLoading = false;
  String? _wifiProvisionedSerial;
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

  Future<void> _checkExistingDevices() async {
    try {
      final devices = await ApiService.instance.devices();

      if (devices.isNotEmpty && mounted) {
        widget.onRegistered?.call();
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
    if (!_formKey.currentState!.validate()) return;

    final serialNumber = _serialController.text.trim();
    setState(() => _isLoading = true);

    try {
      // Provision Wi-Fi first. If registration fails afterwards, remember the
      // successful S/N so retrying does not force the user through BLE again.
      if (_wifiProvisionedSerial != serialNumber) {
        final connected = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => WifiProvisioningScreen(
              serialNumber: serialNumber,
            ),
          ),
        );
        if (!mounted) return;
        if (connected != true) return;
        _wifiProvisionedSerial = serialNumber;
      }

      final isSuccess = await ApiService.instance.registerDevice(serialNumber);

      if (!mounted) return;

      if (!isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "กล้องเชื่อมต่อ Wi-Fi แล้ว แต่บันทึกอุปกรณ์ไม่สำเร็จ กรุณากดลองบันทึกอีกครั้ง",
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ลงทะเบียนอุปกรณ์สำเร็จแล้ว")),
      );

      if (widget.onRegistered != null) {
        widget.onRegistered!.call();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DeviceManagementScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("เกิดข้อผิดพลาด: ${e.toString()}")),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // เปิดกล้องสแกน QR แล้วนำค่าที่ได้มาใส่ในช่อง Serial Number อัตโนมัติ
  Future<void> _scanQRCode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );

    if (result != null && result.isNotEmpty && mounted) {
      final uri = Uri.tryParse(result);
      final isWebLink =
          uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

      if (isWebLink) {
        try {
          setState(() => _isLoading = true);
          final response = await http.get(uri).timeout(const Duration(seconds: 15));
          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw Exception('เว็บไซต์ตอบกลับ HTTP ${response.statusCode}');
          }

          final content = _extractQrWebContent(response.body);
          if (content.isEmpty) {
            throw Exception('ไม่พบข้อมูลในลิงก์ QR Code');
          }

          if (!mounted) return;
          setState(() => _serialController.text = content);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ดึงข้อมูลจากลิงก์มาใส่ในช่องเรียบร้อยแล้ว'),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ไม่สามารถอ่านข้อมูลจากลิงก์ QR Code ได้: $e')),
          );
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
        return;
      }

      setState(() => _serialController.text = result);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("สแกนสำเร็จ: $result")));
    }
  }

  String _extractQrWebContent(String responseBody) {
    final body = responseBody.trim();
    if (body.isEmpty) return '';

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        for (final key in const [
          'serial_number',
          'serial',
          'device_serial',
          'sn',
          'content',
          'data',
        ]) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
      } else if (decoded is String) {
        return decoded.trim();
      }
    } catch (_) {
      // The endpoint may return plain text or a small HTML document.
    }

    return body
        .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        title: Text(
          "ตั้งค่าอุปกรณ์",
          style: GoogleFonts.prompt(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.cFF0F2557,
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

                Text(
                  "ยินดีต้อนรับ!",
                  style: GoogleFonts.prompt(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cFF0F2557,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "กรุณาลงทะเบียนอุปกรณ์ของคุณเพื่อเริ่มต้นใช้งานระบบตรวจจับ",
                  style: GoogleFonts.prompt(
                    fontSize: 15,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cFFFFF7ED,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.cFF9A3412.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.cFF9A3412,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "คำแนะนำ: หมายเลข Serial Number จะอยู่บนสติกเกอร์ที่ติดอยู่กับตัวเครื่องโปรดตรวจสอบให้ถูกต้อง",
                          style: GoogleFonts.prompt(
                            fontSize: 13,
                            color: AppColors.cFF9A3412,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                Text(
                  "หมายเลข Serial Number อุปกรณ์",
                  style: GoogleFonts.prompt(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _serialController,
                  onChanged: (value) {
                    if (_wifiProvisionedSerial != null &&
                        value.trim() != _wifiProvisionedSerial) {
                      setState(() => _wifiProvisionedSerial = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: "เช่น SD-AI-2024XXXX",
                    hintStyle: GoogleFonts.prompt(
                      color: Colors.grey[400],
                    ),
                    prefixIcon: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppColors.cFF0F2557,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.camera_alt_rounded,
                        color: AppColors.cFF0F2557,
                      ),
                      tooltip: "สแกน QR Code",
                      onPressed: _scanQRCode,
                    ),
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
                      borderSide: const BorderSide(
                        color: AppColors.cFF0F2557,
                        width: 2,
                      ),
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
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegistration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cFF0F2557,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: AppColors.cFF0F2557.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _wifiProvisionedSerial ==
                                    _serialController.text.trim()
                                ? "ลองบันทึกอุปกรณ์อีกครั้ง"
                                : "ลงทะเบียนอุปกรณ์",
                            style: GoogleFonts.prompt(
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
    );
  }
}
