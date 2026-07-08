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
    final screenWidth = MediaQuery.of(context).size.width;
    double scale = screenWidth / 375.0;
    scale = scale.clamp(0.85, 1.25);
    final horizontalPadding = (screenWidth * 0.06).clamp(16.0, 32.0);

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBody: true,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context, scale, horizontalPadding),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, 24 * scale, horizontalPadding, 120 * scale),
                    child: Column(
                      children: [
                        _buildDivider("วันนี้", scale),

                        _buildRiskAlertCard(
                          eventType: "หลับตา",
                          durationSeconds: 65,
                          time: "14:32 น.",
                          statusText: "ส่งเสียงแจ้งเตือนต่อเนื่อง",
                          scale: scale,
                        ),
                        
                        SizedBox(height: 16 * scale),

                        _buildRiskAlertCard(
                          eventType: "เหม่อลอย",
                          durationSeconds: 45,
                          time: "11:15 น.",
                          statusText: "สั่นเตือนแรง",
                          scale: scale,
                        ),

                        SizedBox(height: 16 * scale),

                        _buildRiskAlertCard(
                          eventType: "เหม่อลอย",
                          durationSeconds: 5,
                          time: "09:45 น.",
                          statusText: "แจ้งเตือนด้วยเสียงเบา",
                          scale: scale,
                        ),

                        SizedBox(height: 8 * scale),
                        _buildDivider("เมื่อวาน", scale),

                        Opacity(
                          opacity: 0.8,
                          child: _buildRiskAlertCard(
                            eventType: "หลับตา",
                            durationSeconds: 8,
                            time: "18:20 น.",
                            statusText: "บันทึกเหตุการณ์",
                            scale: scale,
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
      return {
        'level': 1,
        'label': 'ความเสี่ยงต่ำ',
        'color': riskLow,
        'icon': Icons.remove_red_eye_rounded,
        'desc': 'ตรวจพบอาการเล็กน้อย'
      };
    }
  }

  Widget _buildRiskAlertCard({
    required String eventType,
    required int durationSeconds,
    required String time,
    required String statusText,
    required double scale,
  }) {
    final riskData = _getRiskDetails(durationSeconds);
    final int level = riskData['level'];
    final Color color = riskData['color'];
    final String label = riskData['label'];
    final IconData icon = riskData['icon'];

    String durationText = "$durationSeconds วินาที";
    if (durationSeconds >= 60) {
      int m = durationSeconds ~/ 60;
      int s = durationSeconds % 60;
      durationText = "$m นาที ${s > 0 ? '$s วินาที' : ''}";
    }

    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 6 * scale)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24 * scale),
                  SizedBox(width: 10 * scale),
                  Text(
                    eventType,
                    style: GoogleFonts.prompt(
                      fontSize: 18 * scale,
                      fontWeight: FontWeight.bold,
                      color: textMain,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 4 * scale),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  "ระดับ $level",
                  style: GoogleFonts.prompt(
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 12 * scale),
          
          Row(
            children: [
              SizedBox(width: 34 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.prompt(fontSize: 14 * scale, color: textSub),
                        children: [
                          const TextSpan(text: "ระยะเวลา: "),
                          TextSpan(
                            text: durationText,
                            style: const TextStyle(
                              color: textMain,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                     Text(
                      label,
                      style: GoogleFonts.prompt(
                        fontSize: 12 * scale,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                time,
                style: GoogleFonts.prompt(
                  fontSize: 12 * scale,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          SizedBox(height: 12 * scale),
          
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 8 * scale),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 16 * scale, color: Colors.green.shade400),
                SizedBox(width: 8 * scale),
                Text(
                  statusText,
                  style: GoogleFonts.prompt(
                    fontSize: 12 * scale,
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

  Widget _buildHeader(BuildContext context, double scale, double padding) {
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
            // นำ Mock Status Bar ออกแล้ว
            SizedBox(height: 16 * scale),
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 0, padding, 32 * scale),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(Icons.notifications_rounded, color: Colors.white, size: 28 * scale),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AlertScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 24 * scale),
                  
                  Text(
                    "ประวัติการแจ้งเตือน",
                    style: GoogleFonts.prompt(
                      color: Colors.white,
                      fontSize: 30 * scale,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 4 * scale),
                  Text(
                    "ตรวจสอบระดับความเสี่ยงล่าสุดของคุณ",
                    style: GoogleFonts.prompt(
                      color: Colors.blue.shade100.withOpacity(0.9),
                      fontSize: 14 * scale,
                    ),
                  ),

                  SizedBox(height: 24 * scale),

                  Row(
                    children: [
                      Expanded(
                        child: _buildHeaderSummaryCard(
                          label: "วันนี้",
                          value: "3",
                          subLabel: "เหตุการณ์",
                          scale: scale,
                        ),
                      ),
                      SizedBox(width: 16 * scale),
                      Expanded(
                        child: _buildHeaderSummaryCard(
                          label: "ความเสี่ยงสูงสุด",
                          value: "ระดับ 3",
                          subLabel: "อันตราย",
                          valueColor: riskHigh,
                          scale: scale,
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

  Widget _buildHeaderSummaryCard({required String label, required String value, required String subLabel, Color? valueColor, required double scale}) {
    return Container(
      padding: EdgeInsets.all(12 * scale),
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
              fontSize: 10 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4 * scale),
          Text(
            value,
            style: GoogleFonts.prompt(
              color: valueColor ?? Colors.white,
              fontSize: 24 * scale,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subLabel,
            style: GoogleFonts.prompt(
              color: Colors.blue.shade200,
              fontSize: 10 * scale,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(String text, double scale) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0 * scale),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: Colors.grey.shade300)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0 * scale),
            child: Text(
              text,
              style: GoogleFonts.prompt(
                color: textSub,
                fontSize: 12 * scale,
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