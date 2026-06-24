import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Import Navbar ที่คุณมีอยู่แล้ว
import 'custom_bottom_nav_bar.dart';
// Import หน้า Detail เพื่อให้ลิงก์ไปหาได้
import 'history_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // --- Theme Colors (ตรงตาม Tailwind Config) ---
  static const Color primaryColor = Color(0xFF0F2647);
  static const Color secondaryColor = Color(0xFF1E3A66);
  static const Color accentColor = Color(0xFF3B82F6);
  static const Color backgroundColor = Color(0xFFF3F4F6); // background-light
  static const Color cardColor = Color(0xFFFFFFFF); // card-light
  static const Color dangerColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color textLight = Color(0xFF1F2937);
  static const Color subTextLight = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      // extendBody: true เพื่อให้เนื้อหาไหลไปอยู่ใต้ Navbar แบบลอย
      extendBody: true,
      
      body: Stack(
        children: [
          Column(
            children: [
              // --- 1. Header Section (Gradient + Date) ---
              _buildHeader(),

              // --- 2. Main Content (Scrollable) ---
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    // padding bottom 120 เพื่อกันพื้นที่ให้ Navbar
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                    child: Column(
                      children: [
                        // Stats Grid (Safety Score & Total Alerts)
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                title: "คะแนนขับขี่", // Safety Score
                                value: "92",
                                suffix: "/100",
                                icon: Icons.shield_outlined,
                                iconColor: primaryColor, 
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildSummaryCard(
                                title: "แจ้งเตือนทั้งหมด", // Total Alerts
                                value: "12",
                                suffix: " ครั้ง",
                                icon: Icons.warning_amber_rounded,
                                iconColor: warningColor,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Section Title (Recent Trips)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "การเดินทางล่าสุด", // Recent Trips
                              style: GoogleFonts.kanit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            Text(
                              "ดูทั้งหมด", // View All
                              style: GoogleFonts.kanit(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: accentColor,
                                decoration: TextDecoration.underline,
                                decorationColor: accentColor,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // --- Trip Cards ---
                        _buildTripCard(
                          title: "บ้าน ไป ที่ทำงาน",
                          date: "จันทร์, 23 ต.ค. • 08:45 น.",
                          status: "ความเสี่ยงสูง",
                          statusColor: dangerColor,
                          statusIcon: Icons.warning_amber_rounded,
                          icon: Icons.directions_car_filled_outlined,
                          distance: "15.4 กม.",
                          duration: "42 นาที",
                          alerts: "5",
                        ),
                        _buildTripCard(
                          title: "ซื้อของเข้าบ้าน",
                          date: "อาทิตย์, 22 ต.ค. • 14:15 น.",
                          status: "ปลอดภัย",
                          statusColor: successColor,
                          statusIcon: Icons.verified_user_outlined,
                          icon: Icons.storefront_outlined,
                          distance: "3.2 กม.",
                          duration: "12 นาที",
                          alerts: "0",
                        ),
                        _buildTripCard(
                          title: "ไปพบลูกค้า",
                          date: "เสาร์, 21 ต.ค. • 10:30 น.",
                          status: "ปานกลาง",
                          statusColor: warningColor,
                          statusIcon: Icons.error_outline_rounded,
                          icon: Icons.work_outline_rounded,
                          distance: "28.5 กม.",
                          duration: "55 นาที",
                          alerts: "2",
                        ),
                        _buildTripCard(
                          title: "เดินทางไปยิม",
                          date: "ศุกร์, 20 ต.ค. • 18:15 น.",
                          status: "ปลอดภัย",
                          statusColor: successColor,
                          statusIcon: Icons.verified_user_outlined,
                          icon: Icons.fitness_center_rounded,
                          distance: "5.1 กม.",
                          duration: "18 นาที",
                          alerts: "0",
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

  // --- Helper Widgets ---

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [primaryColor, secondaryColor],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
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
                  const Text("9:41", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  Row(
                    children: const [
                      Icon(Icons.signal_cellular_alt, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Icon(Icons.wifi, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Icon(Icons.battery_full, color: Colors.white, size: 16),
                    ],
                  )
                ],
              ),
            ),
            
            // App Bar Content
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "ประวัติการขับขี่", // Driving History
                        style: GoogleFonts.kanit(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {},
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Date Selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70),
                          onPressed: () {},
                        ),
                        Column(
                          children: [
                            Text(
                              "ตุลาคม 2023", // October 2023
                              style: GoogleFonts.kanit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              "ระยะทางรวม 1,245 กม.", // 1,245 km total
                              style: GoogleFonts.kanit(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                          onPressed: () {},
                        ),
                      ],
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

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String suffix,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded( // Wrap with Expanded to prevent overflow
                child: Text(
                  title.toUpperCase(),
                  style: GoogleFonts.kanit(
                    color: iconColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: GoogleFonts.kanit(
                    color: textLight,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (suffix.isNotEmpty)
                  TextSpan(
                    text: suffix,
                    style: GoogleFonts.kanit(
                      color: subTextLight,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard({
    required String title,
    required String date,
    required String status,
    required Color statusColor,
    required IconData statusIcon,
    required IconData icon,
    required String distance,
    required String duration,
    required String alerts,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HistoryDetailScreen(
                  title: title,
                  date: date,
                  distance: distance,
                  duration: duration,
                  alerts: alerts,
                  status: status,
                  statusColor: statusColor,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: subTextLight, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.kanit(
                                color: textLight,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              date,
                              style: GoogleFonts.kanit(
                                color: subTextLight,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            status,
                            style: GoogleFonts.kanit(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade100),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    _buildTripStatItem("ระยะทาง", distance, false),
                    Container(width: 1, height: 24, color: Colors.grey.shade100),
                    _buildTripStatItem("เวลาที่ใช้", duration, false),
                    Container(width: 1, height: 24, color: Colors.grey.shade100),
                    _buildTripStatItem("แจ้งเตือน", alerts, true, valueColor: statusColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripStatItem(String label, String value, bool isAlert, {Color? valueColor}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.kanit(
              color: isAlert && valueColor != null ? valueColor : subTextLight,
              fontSize: 12,
              fontWeight: isAlert ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.kanit(
              color: isAlert && valueColor != null ? valueColor : textLight,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}