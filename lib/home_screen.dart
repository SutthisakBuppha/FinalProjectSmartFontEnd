import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async'; 
import 'dart:convert';
import 'package:http/http.dart' as http;

// Import ส่วนประกอบต่างๆ ของแอปพลิเคชันคุณ
import '/services/api_service.dart';
import 'profile_screen.dart'; 
import 'alert_screen.dart'; // 👈 นำเข้าหน้า Alert เพื่อสลับไปแสดงผลอัตโนมัติ

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HomeScreen(),
  ));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isMonitoring = false;
  
  // State สำหรับจัดการข้อมูล API และการทำ Background Polling
  bool _isLoading = false;
  bool _isSilentChecking = false; 
  String? _errorMessage;
  Map<String, dynamic>? _dashboardData;
  Timer? _autoCheckTimer; 

  // Polling สถานะไฟเลี้ยงของอุปกรณ์ (ออนไลน์/ออฟไลน์) เพื่อเริ่ม/หยุดการตรวจจับอัตโนมัติ
  Timer? _deviceStatusTimer;
  bool _isCheckingDeviceStatus = false;
  static const Duration _deviceStatusPollInterval = Duration(seconds: 5);

  static const Color primaryColor = Color(0xFF0F2557);
  static const Color primaryLight = Color(0xFF24469C);
  static const Color backgroundLight = Color(0xFFECF0F3);
  static const Color accentSuccess = Color(0xFF059669);
  static const Color textDark = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // เริ่ม polling สถานะอุปกรณ์ทันที: พอจ่ายไฟ (ออนไลน์) ให้เริ่มตรวจจับเอง
    // พอถอดไฟ/บอร์ดขาดการเชื่อมต่อ (ออฟไลน์) ให้หยุดตรวจจับเองเช่นกัน
    _checkDeviceStatus();
    _deviceStatusTimer = Timer.periodic(_deviceStatusPollInterval, (_) {
      _checkDeviceStatus();
    });
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel(); // ล้างหน่วยความจำ Timer ทั้งหมดออกเพื่อป้องกัน Memory Leak
    _deviceStatusTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // 🔄 ฟังก์ชันสืบค้นพฤติกรรมเสี่ยงล่าสุดจากฝั่งเบื้องหลัง (Background Polling)
  Future<void> _checkLatestEmergencyAlerts() async {
    if (_isSilentChecking) return; // ล็อคป้องกันไม่ให้เกิด Thread การยิงซ้ำซ้อนกัน
    
    setState(() {
      _isSilentChecking = true;
    });

    try {
      // ดึงเลขไอดีคนขับ จาก ApiService ตัวหลัก (หากทดสอบระบบแมนนวลให้ดักไว้เป็นเลข 1)
      final int currentDriverId = ApiService.instance.driverId ?? 1;

      final response = await http.get(
        Uri.parse('${ApiService.instance.baseUrl}/driver-latest-alert?driver_id=$currentDriverId'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        if (responseData['success'] == true && responseData['data'] != null) {
          final Map<String, dynamic> latestAlert = responseData['data'];
          final String alertType = latestAlert['type'] ?? '';
          final String createdAtStr = latestAlert['created_at'] ?? '';

          // ตรวจสอบระดับความสดใหม่ของชุดข้อมูล (เกิดขึ้นไม่เกิน 12 วินาทีก่อนหน้านี้หรือไม่)
          final DateTime alertTime = DateTime.parse(createdAtStr).toLocal();
          final DateTime now = DateTime.now();
          final int secondsDiff = now.difference(alertTime).inSeconds.abs();

          // 🚨 เงื่อนไขสำคัญ: ตรวจพบ "ง่วงนอน", สัญญาณใหม่ และหน้าจอหลักเปิดโหมดสแกนสแตนบายอยู่
          if (alertType == "ง่วงนอน" && secondsDiff <= 12 && _isMonitoring) {
            
            // 1. เคลียร์การนับ Polling เพื่อหยุดลูปชั่วคราว ไม่ให้เด้งทับหน้ากัน
            _autoCheckTimer?.cancel();
            _autoCheckTimer = null;
            setState(() {
              _isMonitoring = false;
              _controller.stop();
            });

            // 2. 🚀 AUTO-JUMP: สั่งเด้งเปิดหน้า AlertScreen ทันทีอย่างไร้รอยต่อ
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AlertScreen()),
              ).then((_) {
                // หลังจากปิดหน้านำทางเสร็จสิ้นและกดย้อนกลับมา ให้เปิดลูประบบทำงานต่ออัตโนมัติ
                _toggleMonitoring();
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Polling Error Log: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSilentChecking = false;
        });
      }
    }
  }

  // 🔌 ตรวจสอบสถานะไฟเลี้ยงของอุปกรณ์ (heartbeat จาก backend) แล้ว sync ปุ่มตรวจจับให้ตรงกันอัตโนมัติ
  // - อุปกรณ์ "ออนไลน์" (มีไฟจ่ายเข้า/ส่ง heartbeat อยู่) → เริ่มตรวจจับให้เอง
  // - อุปกรณ์ "ออฟไลน์" (ถอดไฟ/ถอดบอร์ดออก) → หยุดตรวจจับให้เอง
  Future<void> _checkDeviceStatus() async {
    if (_isCheckingDeviceStatus) return; // กันยิงซ้อนกันถ้า request ก่อนหน้ายังไม่จบ
    _isCheckingDeviceStatus = true;

    try {
      final devices = await ApiService.instance.devices();
      print("DEBUG DEVICES: $devices");
      // ถือว่า "มีไฟจ่ายอยู่" ถ้ามีอุปกรณ์ตัวใดตัวหนึ่งของผู้ใช้สถานะเป็นออนไลน์
      final bool isDeviceOnline = devices.any(
        (d) => d['status'] == 'ออนไลน์' || d['status'] == 'online',
      );

      if (!mounted) return;

      if (isDeviceOnline != _isMonitoring) {
        _setMonitoring(isDeviceOnline);
      }
    } catch (e) {
      // เน็ตสะดุด/เรียก API ไม่สำเร็จ ไม่ต้องรบกวนผู้ใช้ด้วย SnackBar แค่ log ไว้เฉยๆ แล้วรอ poll รอบถัดไป
      debugPrint("Device status poll error: $e");
    } finally {
      _isCheckingDeviceStatus = false;
    }
  }

  // ตั้งค่าสถานะการตรวจจับ (ใช้ร่วมกันทั้งตอน auto-sync จากอุปกรณ์ และตอนผู้ใช้กดปุ่มเอง)
  void _setMonitoring(bool shouldMonitor) {
    if (!mounted) return;
    setState(() {
      _isMonitoring = shouldMonitor;
      if (_isMonitoring) {
        _controller.repeat();
        _autoCheckTimer ??= Timer.periodic(const Duration(seconds: 3), (timer) {
          _checkLatestEmergencyAlerts();
        });
      } else {
        _controller.stop();
        _autoCheckTimer?.cancel();
        _autoCheckTimer = null;
      }
    });
  }

  // 🎛️ ปุ่มกดด้วยมือ: ใช้เป็น manual override ชั่วคราว (โพลล์รอบถัดไปจะ sync กลับตามสถานะไฟจริงเสมอ)
  void _toggleMonitoring() {
    _setMonitoring(!_isMonitoring);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final scale = isLandscape ? 0.8 : 1.0;

    return Scaffold(
      backgroundColor: backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildStatusSection(scale),
                const SizedBox(height: 32),
                _buildControlButton(scale),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      // แก้ไขจาก MainAxisAlignment.between มาเป็นคำสั่งเต็ม MainAxisAlignment.spaceBetween
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "ยินดีต้อนรับ",
              style: GoogleFonts.kanit(color: textDark.withOpacity(0.6), fontSize: 16),
            ),
            Text(
              "ผู้ขับขี่ปลอดภัย",
              style: GoogleFonts.kanit(color: textDark, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.person_pin, size: 36, color: primaryColor),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
          },
        )
      ],
    );
  }

  Widget _buildStatusSection(double scale) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isMonitoring 
                      ? primaryColor.withOpacity(0.1 * (1 - _controller.value))
                      : Colors.grey.withOpacity(0.1),
                ),
                child: Icon(
                  _isMonitoring ? Icons.security_rounded : Icons.shield_moon_rounded,
                  size: 72 * scale,
                  color: _isMonitoring ? primaryColor : Colors.grey,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            _isMonitoring ? "ระบบ AI กำลังคุ้มครองคุณ" : "ระบบปิดการทำงานอยู่",
            style: GoogleFonts.kanit(
              color: _isMonitoring ? primaryLight : textDark,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isMonitoring
                ? "กำลังตรวจสอบพฤติกรรมการขับขี่แบบเรียลไทม์..."
                : "ระบบจะเริ่มทำงานอัตโนมัติเมื่อจ่ายไฟเข้าอุปกรณ์",
            textAlign: TextAlign.center,
            style: GoogleFonts.kanit(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(double scale) {
    return Container(
      width: double.infinity,
      height: (68 * scale).clamp(56.0, 76.0),
      decoration: BoxDecoration(
        color: _isMonitoring ? const Color(0xFFFF4D4D) : accentSuccess,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _isMonitoring ? Colors.red.withOpacity(0.3) : accentSuccess.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleMonitoring, 
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isMonitoring ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 32 * scale,
              ),
              const SizedBox(width: 12),
              Text(
                _isMonitoring ? "หยุดการตรวจจับ" : "เริ่มตรวจจับ",
                style: GoogleFonts.kanit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}