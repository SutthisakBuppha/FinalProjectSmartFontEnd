import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Import หน้า AlertScreen ที่สร้างไว้
import 'alert_screen.dart';
// Import Navbar เดิมของคุณ
import 'custom_bottom_nav_bar.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // --- Theme Colors ---
  static const Color primaryColor = Color(0xFF0F2646);
  static const Color secondaryColor = Color(0xFFE63946);
  static const Color backgroundColor = Color(0xFFF3F4F6);
  static const Color cardColor = Colors.white;
  static const Color textMain = Color(0xFF1F2937);
  static const Color textSub = Color(0xFF6B7280);

  // Risk Colors
  static const Color riskHigh = Color(0xFFEF4444);    // แดง - ระดับ 3
  static const Color riskMedium = Color(0xFFF97316);  // ส้ม - ระดับ 2
  static const Color riskLow = Color(0xFFEAB308);     // เหลือง - ระดับ 1

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      extendBody: true,
      body: Stack(
        children: [
          Column(
            children: [
              // --- 1. Header Section ---
              _buildHeader(context),

              // --- 2. Main Content ---
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                    child: Column(
                      children: [
                        _buildDivider("วันนี้"),

                        // --- ตัวอย่างที่ 1: ความเสี่ยงสูง (เกิน 1 นาที) ---
                        _buildRiskAlertCard(
                          eventType: "หลับตา", // Detail: อาการ
                          durationSeconds: 65, // 1 นาที 5 วิ -> ระดับ 3
                          time: "14:32 น.",
                          statusText: "ส่งเสียงแจ้งเตือนต่อเนื่อง",
                        ),
                        
                        const SizedBox(height: 16),

                        // --- ตัวอย่างที่ 2: ความเสี่ยงปานกลาง (30-59 วิ) ---
                        _buildRiskAlertCard(
                          eventType: "เหม่อลอย", // Detail: อาการ
                          durationSeconds: 45, // -> ระดับ 2
                          time: "11:15 น.",
                          statusText: "สั่นเตือนแรง",
                        ),

                        const SizedBox(height: 16),

                        // --- ตัวอย่างที่ 3: ความเสี่ยงต่ำ (3-10 วิ) ---
                        _buildRiskAlertCard(
                          eventType: "เหม่อลอย", // Detail: อาการ
                          durationSeconds: 5, // -> ระดับ 1
                          time: "09:45 น.",
                          statusText: "แจ้งเตือนด้วยเสียงเบา",
                        ),

                        const SizedBox(height: 8),
                        _buildDivider("เมื่อวาน"),

                        Opacity(
                          opacity: 0.8,
                          child: _buildRiskAlertCard(
                            eventType: "หลับตา",
                            durationSeconds: 8, // -> ระดับ 1
                            time: "18:20 น.",
                            statusText: "บันทึกเหตุการณ์",
                          ),
                        ),
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

  // --- Helper Methods ---

  // ฟังก์ชันคำนวณระดับความเสี่ยงและสี
  Map<String, dynamic> _getRiskDetails(int seconds) {
    if (seconds >= 60) {
      return {
        'level': 3,
        'label': 'ความเสี่ยงสูง',
        'color': riskHigh,
        'icon': Icons.warning_rounded,
        'desc': 'อันตรายมาก! กรุณาจอดพักทันที'
      };
    } else if (seconds >= 30) {
      return {
        'level': 2,
        'label': 'ความเสี่ยงปานกลาง',
        'color': riskMedium,
        'icon': Icons.info_outline_rounded,
        'desc': 'เริ่มมีอาการเหนื่อยล้า'
      };
    } else {
      // 3-29 วินาที (ครอบคลุม 3-10 ตามโจทย์)
      return {
        'level': 1,
        'label': 'ความเสี่ยงต่ำ',
        'color': riskLow,
        'icon': Icons.remove_red_eye_rounded,
        'desc': 'ตรวจพบอาการเล็กน้อย'
      };
    }
  }

  // Widget การ์ดแบบใหม่ที่รับค่าเป็นวินาทีและประเภทอาการ
  Widget _buildRiskAlertCard({
    required String eventType,    // เช่น "หลับตา", "เหม่อลอย"
    required int durationSeconds, // ระยะเวลาที่เป็น (วินาที)
    required String time,
    required String statusText,
  }) {
    // 1. ดึงค่า Config ตามความเสี่ยง
    final riskData = _getRiskDetails(durationSeconds);
    final int level = riskData['level'];
    final Color color = riskData['color'];
    final String label = riskData['label'];
    final IconData icon = riskData['icon'];

    // แปลงวินาทีเป็นข้อความ (เช่น "1 นาที 5 วินาที")
    String durationText = "$durationSeconds วินาที";
    if (durationSeconds >= 60) {
      int m = durationSeconds ~/ 60;
      int s = durationSeconds % 60;
      durationText = "$m นาที ${s > 0 ? '$s วินาที' : ''}";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        // เส้นขอบซ้ายแสดงสีตามระดับความเสี่ยง
        border: Border(left: BorderSide(color: color, width: 6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: หัวข้อ (อาการ) และ Badge ระดับความเสี่ยง
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    eventType, // แสดง "หลับตา" หรือ "เหม่อลอย"
                    style: GoogleFonts.prompt(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textMain,
                    ),
                  ),
                ],
              ),
              // Risk Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  "ระดับ $level", // Level 1, 2, 3
                  style: GoogleFonts.prompt(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Row 2: รายละเอียด (ระยะเวลา)
          Row(
            children: [
              const SizedBox(width: 34), // เว้นระยะให้ตรงกับ Text ข้างบน
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.prompt(fontSize: 14, color: textSub),
                        children: [
                          const TextSpan(text: "ระยะเวลา: "),
                          TextSpan(
                            text: durationText, // แสดงเวลาที่คำนวณไว้
                            style: TextStyle(
                              color: textMain,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                     Text(
                      label, // "ความเสี่ยงสูง/กลาง/ต่ำ"
                      style: GoogleFonts.prompt(
                        fontSize: 12,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              // เวลาที่เกิดเหตุ
              Text(
                time,
                style: GoogleFonts.prompt(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          
          // Row 3: สถานะการแจ้งเตือน (เส้นประ + ข้อความ)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 16, color: Colors.green.shade400),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: GoogleFonts.prompt(
                    fontSize: 12,
                    color: textSub,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- Widget เดิม (Header & Divider) ---

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [primaryColor, Color(0xFF1A3B66)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Status Bar จำลอง
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("9:41", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                  Row(
                    children: const [
                      Icon(Icons.signal_cellular_alt, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Icon(Icons.wifi, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      RotatedBox(quarterTurns: 1, child: Icon(Icons.battery_full, color: Colors.white, size: 14)),
                    ],
                  )
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.notifications_rounded, color: Colors.white, size: 28),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AlertScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    "ประวัติการแจ้งเตือน",
                    style: GoogleFonts.prompt( // ใช้ Prompt เพื่อภาษาไทยที่สวยงาม
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "ตรวจสอบระดับความเสี่ยงล่าสุดของคุณ",
                    style: GoogleFonts.prompt(
                      color: Colors.blue.shade100.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildHeaderSummaryCard(
                          label: "วันนี้",
                          value: "3",
                          subLabel: "เหตุการณ์",
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildHeaderSummaryCard(
                          label: "ความเสี่ยงสูงสุด",
                          value: "ระดับ 3",
                          subLabel: "อันตราย",
                          valueColor: riskHigh, // ส่งสีแดงไป
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSummaryCard({required String label, required String value, required String subLabel, Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.prompt(
              color: Colors.blue.shade100,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.prompt(
              color: valueColor ?? Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subLabel,
            style: GoogleFonts.prompt(
              color: Colors.blue.shade200,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: Colors.grey.shade300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              text,
              style: GoogleFonts.prompt(
                color: textSub,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: Colors.grey.shade300)),
        ],
      ),
    );
  }
}