import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  String? _errorMessage;
  Map<String, dynamic>? _dashboardData;

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
    
    // ดึงข้อมูลเมื่อเริ่มเปิดหน้าจอ
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- ฟังก์ชันดึงข้อมูลจาก Backend ---
  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ApiService.instance.dashboard();
      setState(() {
        _dashboardData = data;
        // เช็คว่ามี trip ที่กำลัง active อยู่หรือไม่
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
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // --- ฟังก์ชันจัดการปุ่ม เริ่ม/หยุด ตรวจจับ ---
  Future<void> _toggleMonitoring() async {
    // ป้องกันการกดซ้ำขณะโหลด
    if (_isLoading) return; 

    try {
      setState(() => _isLoading = true);

      if (_isMonitoring) {
        // กรณีหยุด: อัปเดต Trip ปัจจุบันให้สถานะเป็น completed
        final currentTripId = _dashboardData?['current_trip']?['trip_id'];
        if (currentTripId != null) {
          await ApiService.instance.updateTrip(
            currentTripId, 
            endTime: DateTime.now(), 
            status: 'completed',
          );
        }
      } else {
        // กรณีเริ่ม: สร้าง Trip ใหม่ (หากมี Device ID ควรรหัสส่งไปด้วย)
        await ApiService.instance.createTrip(); 
      }

      // ดึงข้อมูลใหม่เพื่ออัปเดตหน้าจอ
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
    return Scaffold(
      backgroundColor: backgroundLight,
      extendBody: true,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: RefreshIndicator( // ลากลงเพื่อโหลดข้อมูลใหม่ได้
                  onRefresh: _fetchDashboardData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 30, 24, 120),
                      child: _buildBodyContent(),
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

  Widget _buildBodyContent() {
    if (_isLoading && _dashboardData == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 100),
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    if (_errorMessage != null && _dashboardData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 100),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: GoogleFonts.kanit(color: textDark)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchDashboardData,
                child: Text('ลองใหม่', style: GoogleFonts.kanit()),
              )
            ],
          ),
        ),
      );
    }

    // ดึงค่าสถิติจาก API
    final currentTrip = _dashboardData?['current_trip'];
final num distance = num.tryParse(currentTrip?['distance']?.toString() ?? '') ?? 0;
final int durationMin = int.tryParse(currentTrip?['duration']?.toString() ?? '') ?? 0;

    return Column(
      children: [
        _buildPulsingCircle(),
        const SizedBox(height: 40),
        
        Opacity(
          opacity: _isMonitoring ? 1.0 : 0.6,
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  Icons.alt_route_rounded,
                  "ระยะทาง",
                  distance.toStringAsFixed(1), // ทศนิยม 1 ตำแหน่ง
                  "กม."
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  Icons.schedule_rounded,
                  "เวลาขับขี่",
                  _formatDuration(durationMin),
                  "ชม."
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        
        // แสดง loading ย่อยที่ปุ่มกรณีที่มีการรอ API ตอบกลับ
        _isLoading 
            ? const CircularProgressIndicator(color: primaryColor)
            : _buildControlButton(),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    // ดึงชื่อคนขับจาก ApiService ที่เก็บไว้ตอน Login
    final driverName = ApiService.instance.currentDriver?['name'] ?? "Driver";

    return Container(
      padding: const EdgeInsets.only(bottom: 40),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Smart Drive Guard",
                      style: GoogleFonts.kanit(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      const Icon(Icons.signal_cellular_alt_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      const Icon(Icons.wifi_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      const RotatedBox(
                          quarterTurns: 1,
                          child: Icon(Icons.battery_full_rounded, color: Colors.white, size: 16)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "สวัสดี, $driverName", // ใช้ชื่อจาก API
                            style: GoogleFonts.kanit(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "หน้าหลัก",
                            style: GoogleFonts.kanit(
                              color: Colors.blue.shade100,
                              fontSize: 14,
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
                      onTap: () {
                         // กดเพื่อไปหน้าโปรไฟล์
                      },
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: const CircleAvatar(
                          backgroundColor: Colors.transparent,
                          child: Icon(Icons.person_rounded, color: Colors.white, size: 26),
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

  // --- ส่วน UI ที่เหลือเหมือนเดิมเป๊ะ ---
  Widget _buildPulsingCircle() {
    return Column(
      children: [
        SizedBox(
          width: 260,
          height: 260,
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
                        width: 260,
                        height: 260,
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
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  color: _isMonitoring ? primaryColor : const Color(0xFF90A4AE), 
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 8),
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
                      size: 64,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isMonitoring ? "ขับขี่ปลอดภัย" : "พร้อมใช้งาน",
                      style: GoogleFonts.kanit(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        shadows: [
                            const Shadow(offset: Offset(0, 2), blurRadius: 4, color: Colors.black26)
                        ]
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _isMonitoring ? "AI กำลังทำงาน" : "รอการเริ่มระบบ",
                        style: GoogleFonts.kanit(
                          color: Colors.white,
                          fontSize: 14,
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
        const SizedBox(height: 32),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _isMonitoring ? 1.0 : 0.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                  width: 12,
                  height: 12,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                       if (_isMonitoring)
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(seconds: 1),
                          builder: (context, value, child) {
                            return Container(
                              width: 12 + (12 * value),
                              height: 12 + (12 * value),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accentSuccess.withOpacity(0.5 * (1 - value)),
                              ),
                            );
                          },
                        ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: accentSuccess,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "กำลังตรวจจับ...",
                  style: GoogleFonts.kanit(
                    color: primaryColor,
                    fontSize: 16,
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

  Widget _buildStatCard(IconData icon, String label, String value, String unit, {bool isScore = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: Icon(icon, color: primaryColor, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: GoogleFonts.kanit(
                  color: textGrey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: GoogleFonts.kanit(
                        color: textDark,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (unit.isNotEmpty)
                      TextSpan(
                        text: " $unit",
                        style: GoogleFonts.kanit(
                          color: textGrey,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton() {
    return Container(
      width: double.infinity,
      height: 68,
      decoration: BoxDecoration(
        color: _isMonitoring ? primaryColor : accentSuccess,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _isMonitoring 
                ? primaryColor.withOpacity(0.4) 
                : accentSuccess.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleMonitoring, // เปลี่ยนไปเรียกฟังก์ชันที่ยิง API
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isMonitoring ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                _isMonitoring ? "หยุดการตรวจจับ" : "เริ่มตรวจจับ",
                style: GoogleFonts.kanit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}