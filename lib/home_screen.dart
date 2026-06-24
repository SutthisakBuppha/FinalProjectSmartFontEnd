import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Import ไฟล์ ProfileScreen ของจริง
import 'profile_screen.dart';

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

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isMonitoring = false;

  // --- ปรับชุดสีใหม่ให้เข้มและชัดขึ้น ---
  static const Color primaryColor = Color(0xFF0F2557); // น้ำเงินเข้ม (Deep Navy)
  static const Color primaryLight = Color(0xFF24469C); // น้ำเงินสว่างขึ้นเล็กน้อย
  static const Color backgroundLight = Color(0xFFECF0F3); // พื้นหลังเทาอมฟ้า (เข้มกว่าเดิม)
  static const Color accentSuccess = Color(0xFF059669); // เขียวเข้ม (Emerald 600)
  static const Color textDark = Color(0xFF1E293B); // สีข้อความหัวข้อ (Slate 800)
  static const Color textGrey = Color(0xFF64748B); // สีข้อความรอง (Slate 500)

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMonitoring() {
    setState(() {
      _isMonitoring = !_isMonitoring;
      if (_isMonitoring) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    });
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
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 120), // เพิ่ม Top padding
                    child: Column(
                      children: [
                        _buildPulsingCircle(),
                        const SizedBox(height: 40),
                        
                        // Stats Grid
                        Opacity(
                          opacity: _isMonitoring ? 1.0 : 0.6, // ปรับ Opacity ตอนปิดให้เห็นชัดขึ้น (จาก 0.5 เป็น 0.6)
                          child: Row(
                            children: [
                              Expanded(
                                  child: _buildStatCard(Icons.alt_route_rounded,
                                      "ระยะทาง", "45", "กม.")),
                              const SizedBox(width: 16), // เพิ่มระยะห่าง
                              Expanded(
                                  child: _buildStatCard(Icons.schedule_rounded,
                                      "เวลาขับขี่", "01:12", "ชม.")),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        _buildControlButton(),
                      ],
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

 Widget _buildHeader(BuildContext context) {
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
                  Text("9:41",
                      style: GoogleFonts.kanit(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      const Icon(Icons.signal_cellular_alt_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      const Icon(Icons.wifi_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      const RotatedBox(
                          quarterTurns: 1,
                          child: Icon(Icons.battery_full_rounded,
                              color: Colors.white, size: 16)),
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
                          border:
                              Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.directions_car_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Smart Drive Guard",
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
                      // --- แก้ไขตรงนี้: ลบ Navigator.push ออก หรือใส่เป็น null ---
                      onTap: () {
                         // ใส่ว่างๆ ไว้เพื่อให้กดได้แต่ไม่ไปไหน
                         // หรือถ้าไม่อยากให้กดได้เลย ให้เปลี่ยน onTap: () { ... } เป็น onTap: null,
                      },
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: CircleAvatar(
                          backgroundColor: Colors.transparent,
                          child: const Icon(Icons.person_rounded,
                              color: Colors.white, size: 26),
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
                      scale: 0.95 + (_controller.value * 0.1), // ขยายวงให้กว้างขึ้น
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // เพิ่มความเข้มของสี Pulse จาก 0.05 เป็น 0.15
                          color: primaryColor.withOpacity(0.15),
                          boxShadow: [
                            if (_controller.value < 0.7)
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3 * (1 - _controller.value)), // เงาเข้มขึ้น
                                blurRadius: 10,
                                spreadRadius: 30 * _controller.value,
                              )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              // Inner Circle
              Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  // เปลี่ยนสีตอนปิด จากเทาอ่อน เป็นเทาเข้ม (Blue Grey 300) ให้เห็นชัด
                  color: _isMonitoring ? primaryColor : const Color(0xFF90A4AE), 
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 8), // ขอบหนาขึ้น
                  boxShadow: [
                    BoxShadow(
                      color: _isMonitoring
                          ? primaryColor.withOpacity(0.4) // เงาเข้มขึ้น
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
                      _isMonitoring
                          ? Icons.verified_user_rounded
                          : Icons.gpp_maybe_rounded,
                      color: Colors.white,
                      size: 64, // ไอคอนใหญ่ขึ้น
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isMonitoring ? "ขับขี่ปลอดภัย" : "พร้อมใช้งาน",
                      style: GoogleFonts.kanit(
                        color: Colors.white,
                        fontSize: 26, // ตัวใหญ่ขึ้น
                        fontWeight: FontWeight.bold,
                        shadows: [
                            const Shadow(
                                offset: Offset(0, 2),
                                blurRadius: 4,
                                color: Colors.black26)
                        ]
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2), // พื้นหลังป้าย Status เข้มขึ้น
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _isMonitoring ? "AI กำลังทำงาน" : "รอการเริ่มระบบ",
                        style: GoogleFonts.kanit(
                          color: Colors.white, // เปลี่ยนเป็นขาวล้วนเพื่อความชัด
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
                  color: const Color(0xFF0F2557).withOpacity(0.1), // เงาสีน้ำเงิน
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
                    fontSize: 16, // ใหญ่ขึ้น
                    fontWeight: FontWeight.w600, // หนาขึ้น
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value, String unit,
      {bool isScore = false}) {
    return Container(
      padding: const EdgeInsets.all(16), // Padding เยอะขึ้น
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withOpacity(0.15), // เงาสีเทาเข้ม
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
                  color: const Color(0xFFEFF6FF), // Blue 50
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFDBEAFE)), // ขอบจางๆ
                ),
                child: Icon(icon, color: primaryColor, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: GoogleFonts.kanit(
                  color: textGrey, // สีเทาเข้ม อ่านง่ายกว่าเดิม
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
                        color: textDark, // สีดำ Slate 800
                        fontSize: 24, // ใหญ่ขึ้น
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
      height: 68, // สูงขึ้น
      decoration: BoxDecoration(
        color: _isMonitoring ? primaryColor : accentSuccess,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _isMonitoring 
                ? primaryColor.withOpacity(0.4) 
                : accentSuccess.withOpacity(0.4), // เงาเข้มขึ้น
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
                _isMonitoring
                    ? Icons.stop_circle_rounded
                    : Icons.play_circle_fill_rounded,
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