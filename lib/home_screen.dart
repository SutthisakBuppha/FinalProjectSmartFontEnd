import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async'; // สำคัญ: เพิ่มสำหรับใช้งาน Timer

// Import ApiService
import '/services/api_service.dart';
import 'profile_screen.dart'; // ของคุณ

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
  
  // State สำหรับจัดการข้อมูล API
  bool _isLoading = true;
  bool _isSilentChecking = false; // ตัวแปรป้องกันไม่ให้ยิง API ซ้อนกันในเบื้องหลัง
  String? _errorMessage;
  Map<String, dynamic>? _dashboardData;
  Timer? _autoCheckTimer; // Timer สำหรับเช็กสถานะบอร์ดอัตโนมัติ

  static const Color primaryColor = Color(0xFF0F2557);
  static const Color primaryLight = Color(0xFF24469C);
  static const Color backgroundLight = Color(0xFFECF0F3);
  static const Color accentSuccess = Color(0xFF059669);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textGrey = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    
    // 1. ดึงข้อมูลครั้งแรกเมื่อเปิดหน้าจอ
    _fetchDashboardData();

    // 2. เริ่มต้นระบบเช็กสถานะบอร์ดอัตโนมัติทุกๆ 5 วินาที
    _startAutoCheckTimer();
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel(); // ล้าง Timer ทิ้งเมื่อออกจากหน้าป้องกัน Memory Leak
    _controller.dispose();
    super.dispose();
  }

  // --- ฟังก์ชันดึงข้อมูลจาก Backend (แบบเปิดหน้าจอ/โหลดใหม่ด้วยมือ) ---
  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ApiService.instance.dashboard();
      if (!mounted) return;
      setState(() {
        _dashboardData = data;
        _isMonitoring = data['current_trip'] != null;
        if (_isMonitoring) {
          _controller.repeat();
        } else {
          _controller.stop();
          _controller.reset();
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // --- ระบบตรวจเช็กสถานะบอร์ด & สลับโหมดอัตโนมัติ (Background Polling) ---
  void _startAutoCheckTimer() {
    // ตั้งเวลาให้ทำงานทุกๆ 5 วินาที (ปรับเวลาได้ตามต้องการ)
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      // ถ้ากำลังโหลดหน้าหลัก หรือระบบอัตโนมัติก่อนหน้ากำลังทำงานอยู่ ให้ข้ามไปก่อน
      if (_isLoading || _isSilentChecking) return;

      _isSilentChecking = true;

      try {
        // 1. เช็กสถานะบอร์ดว่าออนไลน์หรือไม่ (เหมือนหน้า devices_screen)
        final devices = await ApiService.instance.devices();
        bool isBoardOnline = devices.any((d) => d['status'] == 'ออนไลน์' || d['status'] == 'online');

        // 2. ดึงข้อมูล Dashboard ล่าสุดเพื่อเช็กสถานะทริปปัจจุบันในระบบ
        final data = await ApiService.instance.dashboard();
        bool isTripActive = data['current_trip'] != null;

        if (!mounted) return;

        // 3. เปรียบเทียบเงื่อนไขเพื่อสั่งงานอัตโนมัติ
        if (isBoardOnline && !isTripActive) {
          // เงื่อนไข: บอร์ดมีไฟเข้า (Online) แต่แอปยังไม่ได้เริ่มตรวจจับ -> เริ่มอัตโนมัติ!
          await ApiService.instance.createTrip();
          await _fetchDashboardData(); // โหลดข้อมูล UI ใหม่
        } 
        else if (!isBoardOnline && isTripActive) {
          // เงื่อนไข: บอร์ดไม่มีไฟ (Offline) แต่ในแอปยังค้างสถานะตรวจจับอยู่ -> หยุดอัตโนมัติ!
          final currentTripId = data['current_trip']?['trip_id'];
          if (currentTripId != null) {
            await ApiService.instance.updateTrip(
              currentTripId, 
              endTime: DateTime.now(), 
              status: 'completed',
            );
          }
          await _fetchDashboardData(); // โหลดข้อมูล UI ใหม่
        } 
        else {
          // สถานะบอร์ดกับแอปตรงกันอยู่แล้ว แค่อัปเดตข้อมูลตัวเลขระยะทาง/เวลา บนหน้าจอแบบเงียบๆ
          setState(() {
            _dashboardData = data;
            _isMonitoring = isTripActive;
            if (_isMonitoring) {
              if (!_controller.isAnimating) _controller.repeat();
            } else {
              _controller.stop();
              _controller.reset();
            }
          });
        }
      } catch (e) {
        debugPrint("Auto check connection background error: $e");
      } finally {
        _isSilentChecking = false;
      }
    });
  }

  // --- ฟังก์ชันจัดการปุ่ม เริ่ม/หยุด ตรวจจับ (กรณีผู้ใช้กดเลือกเองแมนนวล) ---
  Future<void> _toggleMonitoring() async {
    if (_isLoading) return; 

    try {
      setState(() => _isLoading = true);

      if (_isMonitoring) {
        final currentTripId = _dashboardData?['current_trip']?['trip_id'];
        if (currentTripId != null) {
          await ApiService.instance.updateTrip(
            currentTripId, 
            endTime: DateTime.now(), 
            status: 'completed',
          );
        }
      } else {
        await ApiService.instance.createTrip(); 
      }

      await _fetchDashboardData();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  // ฟังก์ชันแปลงนาทีเป็นรูปแบบ HH:MM
  String _formatDuration(int? minutes) {
    if (minutes == null || minutes == 0) return "00:00";
    final int hours = minutes ~/ 60;
    final int mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    double scale = screenWidth / 375.0;
    scale = scale.clamp(0.85, 1.25);
    final horizontalPadding = (screenWidth * 0.08).clamp(20.0, 40.0);

    return Scaffold(
      backgroundColor: backgroundLight,
      extendBody: true,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context, scale, horizontalPadding),
              Expanded(
                child: RefreshIndicator( 
                  onRefresh: _fetchDashboardData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding, 
                        30 * scale, 
                        horizontalPadding, 
                        120 * scale,
                      ),
                      child: _buildBodyContent(scale),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(double scale) {
    if (_isLoading && _dashboardData == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(top: 100 * scale),
          child: const CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    if (_errorMessage != null && _dashboardData == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(top: 100 * scale),
          child: Column(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48 * scale),
              SizedBox(height: 16 * scale),
              Text(_errorMessage!, style: GoogleFonts.kanit(color: textDark, fontSize: 14 * scale)),
              SizedBox(height: 16 * scale),
              ElevatedButton(
                onPressed: _fetchDashboardData,
                child: Text('ลองใหม่', style: GoogleFonts.kanit(fontSize: 14 * scale)),
              )
            ],
          ),
        ),
      );
    }

    final currentTrip = _dashboardData?['current_trip'];
    final num distance = num.tryParse(currentTrip?['distance']?.toString() ?? '') ?? 0;
    final int durationMin = int.tryParse(currentTrip?['duration']?.toString() ?? '') ?? 0;

    return Column(
      children: [
        _buildPulsingCircle(scale),
        SizedBox(height: 40 * scale),
        
        Opacity(
          opacity: _isMonitoring ? 1.0 : 0.6,
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  Icons.alt_route_rounded,
                  "ระยะทาง",
                  distance.toStringAsFixed(1),
                  "กม.",
                  scale
                ),
              ),
              SizedBox(width: 16 * scale),
              Expanded(
                child: _buildStatCard(
                  Icons.schedule_rounded,
                  "เวลาขับขี่",
                  _formatDuration(durationMin),
                  "ชม.",
                  scale
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 40 * scale),
        
        _isLoading 
            ? const CircularProgressIndicator(color: primaryColor)
            : _buildControlButton(scale),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, double scale, double padding) {
    final driverName = ApiService.instance.currentDriver?['name'] ?? "Driver";

    return Container(
      padding: EdgeInsets.only(bottom: 30 * scale),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryLight],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x660F2557),
            blurRadius: 25,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 12 * scale),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Smart Drive Guard",
                      style: GoogleFonts.kanit(
                          color: Colors.white,
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            SizedBox(height: 12 * scale),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48 * scale,
                        height: 48 * scale,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Icon(Icons.directions_car_rounded, color: Colors.white, size: 24 * scale),
                      ),
                      SizedBox(width: 16 * scale),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "สวัสดี, $driverName",
                            style: GoogleFonts.kanit(
                              color: Colors.white,
                              fontSize: 22 * scale,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "หน้าหลัก",
                            style: GoogleFonts.kanit(
                              color: Colors.blue.shade100,
                              fontSize: 14 * scale,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        width: 44 * scale,
                        height: 44 * scale,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: CircleAvatar(
                          backgroundColor: Colors.transparent,
                          child: Icon(Icons.person_rounded, color: Colors.white, size: 26 * scale),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulsingCircle(double scale) {
    final outerSize = 260 * scale;
    final innerSize = 210 * scale;

    return Column(
      children: [
        SizedBox(
          width: outerSize,
          height: outerSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isMonitoring)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 0.95 + (_controller.value * 0.1),
                      child: Container(
                        width: outerSize,
                        height: outerSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor.withOpacity(0.15),
                          boxShadow: [
                            if (_controller.value < 0.7)
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3 * (1 - _controller.value)),
                                blurRadius: 10,
                                spreadRadius: 30 * _controller.value,
                              )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              Container(
                width: innerSize,
                height: innerSize,
                decoration: BoxDecoration(
                  color: _isMonitoring ? primaryColor : const Color(0xFF90A4AE), 
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 8 * scale),
                  boxShadow: [
                    BoxShadow(
                      color: _isMonitoring
                          ? primaryColor.withOpacity(0.4)
                          : Colors.grey.withOpacity(0.4),
                      blurRadius: 40,
                      spreadRadius: 5,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isMonitoring ? Icons.verified_user_rounded : Icons.gpp_maybe_rounded,
                      color: Colors.white,
                      size: 64 * scale,
                    ),
                    SizedBox(height: 8 * scale),
                    Text(
                      _isMonitoring ? "ขับขี่ปลอดภัย" : "พร้อมใช้งาน",
                      style: GoogleFonts.kanit(
                        color: Colors.white,
                        fontSize: 26 * scale,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          const Shadow(offset: Offset(0, 2), blurRadius: 4, color: Colors.black26)
                        ]
                      ),
                    ),
                    SizedBox(height: 6 * scale),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 6 * scale),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _isMonitoring ? "AI กำลังทำงาน" : "รอการเริ่มระบบ",
                        style: GoogleFonts.kanit(
                          color: Colors.white,
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 32 * scale),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _isMonitoring ? 1.0 : 0.0,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 12 * scale),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: primaryColor.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F2557).withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12 * scale,
                  height: 12 * scale,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                       if (_isMonitoring)
                       TweenAnimationBuilder<double>(
                         tween: Tween(begin: 0.0, end: 1.0),
                         duration: const Duration(seconds: 1),
                         builder: (context, value, child) {
                           return Container(
                             width: (12 * scale) + ((12 * scale) * value),
                             height: (12 * scale) + ((12 * scale) * value),
                             decoration: BoxDecoration(
                               shape: BoxShape.circle,
                               color: accentSuccess.withOpacity(0.5 * (1 - value)),
                             ),
                           );
                         },
                       ),
                      Container(
                        width: 10 * scale,
                        height: 10 * scale,
                        decoration: const BoxDecoration(
                          color: accentSuccess,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10 * scale),
                Text(
                  "กำลังตรวจจับ...",
                  style: GoogleFonts.kanit(
                    color: primaryColor,
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value, String unit, double scale) {
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40 * scale,
            height: 40 * scale,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Icon(icon, color: primaryColor, size: 22 * scale),
          ),
          SizedBox(height: 12 * scale),
          Text(
            label,
            style: GoogleFonts.kanit(color: textGrey, fontSize: 14 * scale, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 4 * scale),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: GoogleFonts.kanit(color: textDark, fontSize: 24 * scale, fontWeight: FontWeight.bold),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: " $unit",
                    style: GoogleFonts.kanit(color: textGrey, fontSize: 14 * scale, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
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
        color: _isMonitoring ? primaryColor : accentSuccess,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _isMonitoring ? primaryColor.withOpacity(0.4) : accentSuccess.withOpacity(0.4),
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
              SizedBox(width: 12 * scale),
              Text(
                _isMonitoring ? "หยุดการตรวจจับ" : "เริ่มตรวจจับ",
                style: GoogleFonts.kanit(color: Colors.white, fontSize: 20 * scale, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}