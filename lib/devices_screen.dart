import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main_layout.dart';
import 'device_setting.dart';
import 'device_registration_screen.dart';
import '/services/api_service.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  static const Color primaryColor = Color(0xFF0F2646);
  static const Color backgroundColor = Color(0xFFF3F4F6);
  static const Color cardColor = Colors.white;
  static const Color textMain = Color(0xFF1F2937);
  static const Color textSub = Color(0xFF6B7280);
  static const Color successGreen = Color(0xFF4ADE80);
  static const Color offlineGrey = Color(0xFF9CA3AF);

  List<Map<String, dynamic>> _deviceList = [];
  bool _isLoading = true;
  Timer? _pollTimer;

  // ระยะเวลาที่จะ auto-refresh สถานะอุปกรณ์ (ให้สอดคล้องกับรอบ heartbeat/timeout ฝั่ง backend)
  static const Duration _pollInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _loadDevices();
    // เริ่ม polling อัตโนมัติ เพื่อให้สถานะออนไลน์/ออฟไลน์อัปเดตเองโดยไม่ต้องรอผู้ใช้ปัดหน้าจอ
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      _loadDevices(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // silent = true ใช้ตอน poll พื้นหลัง จะไม่โชว์ loading spinner เต็มจอ และไม่ redirect ไปหน้าลงทะเบียนอัตโนมัติ
  // (กันเคส network สะดุดชั่วคราวแล้วดันเด้งผู้ใช้ออกจากหน้าที่กำลังดูอยู่)
  Future<void> _loadDevices({bool silent = false}) async {
    try {
      // แก้ไข: เรียกใช้งาน devices() แบบไม่มี arguments ตามความจริงในโปรเจกต์ของคุณ
      final list = await ApiService.instance.devices();

      if (!mounted) return;

      if (list.isEmpty) {
        if (silent) {
          // ตอน poll เงียบๆ ถ้าไม่มีอุปกรณ์เลย แค่เคลียร์ list ในจอ ไม่ redirect ระหว่างที่ผู้ใช้เปิดหน้าอยู่
          setState(() {
            _deviceList = [];
            _isLoading = false;
          });
        } else {
          // หากไม่มีการผูกอุปกรณ์ไว้เลยในระบบ ให้เด้งกลับไปหน้าลงทะเบียน (เฉพาะตอนโหลดครั้งแรก/ปัดรีเฟรชเอง)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DeviceRegistrationScreen()),
          );
        }
        return;
      }

      setState(() {
        _deviceList = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent) {
        // poll พื้นหลังล้มเหลว (เช่น เน็ตสะดุด) ไม่ต้องรบกวนผู้ใช้ด้วย SnackBar ทุกครั้ง แค่ log ไว้เฉยๆ
        debugPrint("Silent poll โหลดข้อมูลอุปกรณ์ล้มเหลว: $e");
        return;
      }
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("โหลดข้อมูลอุปกรณ์ล้มเหลว: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: backgroundColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    final onlineCount = _deviceList.where((d) => d['status'] == 'ออนไลน์' || d['status'] == 'online').length;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
            decoration: const BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const MainLayout(initialIndex: 0)),
                          (route) => false,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "รายการอุปกรณ์",
                      style: GoogleFonts.prompt(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 48, top: 4),
                  child: Text(
                    "เชื่อมต่อ $onlineCount อุปกรณ์ออนไลน์",
                    style: GoogleFonts.prompt(color: Colors.blue.shade100, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          // List ของอุปกรณ์ที่ลงทะเบียนไว้
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadDevices,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _deviceList.length,
                itemBuilder: (context, index) {
                  final device = _deviceList[index];
                  final isOnline = device['status'] == 'ออนไลน์' || device['status'] == 'online';

                  return GestureDetector(
                    onTap: () {
                      // กดที่ Card แล้วลิงก์ไปยังหน้าแก้ไขการตั้งค่าอุปกรณ์ตัวนั้นๆ ทันที
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DeviceCustomizationScreen(deviceData: device),
                        ),
                      ).then((_) => _loadDevices()); // เมื่อกลับมาหน้านี้ ให้รีเฟรชข้อมูลใหม่
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isOnline ? successGreen.withOpacity(0.1) : offlineGrey.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.developer_board_rounded,
                              color: isOnline ? successGreen : offlineGrey,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  device['device_name'] ?? 'ไม่ระบุชื่ออุปกรณ์',
                                  style: GoogleFonts.prompt(
                                    color: textMain,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "S/N: ${device['serial_number'] ?? '-'}",
                                  style: GoogleFonts.prompt(color: textSub, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOnline ? successGreen.withOpacity(0.2) : offlineGrey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isOnline ? "ออนไลน์" : "ออฟไลน์",
                                  style: GoogleFonts.prompt(
                                    color: isOnline ? Colors.green.shade800 : Colors.grey.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Icon(Icons.arrow_forward_ios_rounded, color: offlineGrey, size: 14),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}