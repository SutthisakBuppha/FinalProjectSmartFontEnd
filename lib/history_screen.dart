import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Import Navbar ที่คุณมีอยู่แล้ว
import 'custom_bottom_nav_bar.dart';
// Import หน้า Detail เพื่อให้ลิงก์ไปหาได้
import 'history_detail_screen.dart';
// Import ApiService เพื่อเชื่อมต่อข้อมูลจริง
import '/services/api_service.dart';

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

  // --- API State Variables ---
  List<Map<String, dynamic>> _trips = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // --- Summary Variables ---
  int _safetyScore = 100;
  int _totalAlerts = 0;
  double _totalDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchHistoryData();
  }

  // ฟังก์ชันดึงข้อมูลจาก API
  Future<void> _fetchHistoryData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final fetchedTrips = await ApiService.instance.trips();
      
      int alertsSum = 0;
      double distanceSum = 0.0;

      for (var trip in fetchedTrips) {
        alertsSum += (trip['alerts_count'] as num?)?.toInt() ?? 0;
        distanceSum += (trip['distance'] as num?)?.toDouble() ?? 0.0;
      }

      // คำนวณคะแนนขับขี่แบบจำลองอ้างอิงจากยอด Alert (เช่น เริ่มต้น 100 หักครั้งละ 5 คะแนน)
      int calculatedScore = 100 - (alertsSum * 5);
      if (calculatedScore < 0) calculatedScore = 0;

      setState(() {
        _trips = fetchedTrips;
        _totalAlerts = alertsSum;
        _totalDistance = distanceSum;
        _safetyScore = fetchedTrips.isEmpty ? 100 : calculatedScore;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // ฟังก์ชันแปลงรูปแบบวันที่แบบอ่านง่าย (ภาษาไทย)
  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '-';
    final dateTime = DateTime.tryParse(dateStr);
    if (dateTime == null) return dateStr;

    final months = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];
    final days = ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'];

    String dayName = days[dateTime.weekday % 7];
    String monthName = months[dateTime.month - 1];
    String hour = dateTime.hour.toString().padLeft(2, '0');
    String minute = dateTime.minute.toString().padLeft(2, '0');

    return '$dayName, ${dateTime.day} $monthName • $hour:$minute น.';
  }

  // ประเมินระดับความปลอดภัยตามจำนวนครั้งที่แจ้งเตือน
  Map<String, dynamic> _getSafetyStatus(int alertsCount) {
    if (alertsCount == 0) {
      return {
        'text': 'ปลอดภัย',
        'color': successColor,
        'icon': Icons.verified_user_outlined,
      };
    } else if (alertsCount <= 3) {
      return {
        'text': 'ปานกลาง',
        'color': warningColor,
        'icon': Icons.error_outline_rounded,
      };
    } else {
      return {
        'text': 'ความเสี่ยงสูง',
        'color': dangerColor,
        'icon': Icons.warning_amber_rounded,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      extendBody: true,
      body: Stack(
        children: [
          Column(
            children: [
              // --- 1. Header Section (Gradient + Total Distance Summary) ---
              _buildHeader(),

              // --- 2. Main Content (Scrollable or Loading) ---
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      )
                    : _errorMessage.isNotEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, color: dangerColor, size: 48),
                                  const SizedBox(height: 16),
                                  Text(
                                    _errorMessage,
                                    style: GoogleFonts.kanit(color: textLight),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _fetchHistoryData,
                                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                                    child: Text("ลองใหม่อีกครั้ง", style: GoogleFonts.kanit(color: Colors.white)),
                                  )
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchHistoryData,
                            color: primaryColor,
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                                child: Column(
                                  children: [
                                    // Stats Grid (Safety Score & Total Alerts)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildSummaryCard(
                                            title: "คะแนนขับขี่",
                                            value: "$_safetyScore",
                                            suffix: "/100",
                                            icon: Icons.shield_outlined,
                                            iconColor: primaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _buildSummaryCard(
                                            title: "แจ้งเตือนทั้งหมด",
                                            value: "$_totalAlerts",
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
                                          "การเดินทางล่าสุด",
                                          style: GoogleFonts.kanit(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        ),
                                        Text(
                                          "ดูทั้งหมด",
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

                                    // --- Trip Cards (Dynamic from API) ---
                                    if (_trips.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 40),
                                        child: Center(
                                          child: Text(
                                            "ไม่พบประวัติการเดินทางของท่าน",
                                            style: GoogleFonts.kanit(color: subTextLight, fontSize: 16),
                                          ),
                                        ),
                                      )
                                    else
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: _trips.length,
                                        itemBuilder: (context, index) {
                                          final trip = _trips[index];
                                          final alertsCount = (trip['alerts_count'] as num?)?.toInt() ?? 0;
                                          final statusData = _getSafetyStatus(alertsCount);

                                          // **จุดที่แก้ไข:** ดึงค่า tripId และแปลงให้เป็นตัวเลข (int) อย่างปลอดภัย
                                          final int tripIdInt = (trip['trip_id'] as num?)?.toInt() ?? 
                                                                (trip['id'] as num?)?.toInt() ?? 0;

                                          // กำหนดชื่อ Title ของทริปให้ยืดหยุ่นตามข้อมูลที่มี
                                          final startLoc = trip['start_location']?.toString() ?? '';
                                          final endLoc = trip['end_location']?.toString() ?? '';
                                          String tripTitle = "การเดินทาง #$tripIdInt";
                                          
                                          if (startLoc.isNotEmpty && endLoc.isNotEmpty) {
                                            tripTitle = "$startLoc ไป $endLoc";
                                          } else if (endLoc.isNotEmpty) {
                                            tripTitle = "มุ่งสู่ $endLoc";
                                          }

                                          final distanceVal = (trip['distance'] as num?)?.toDouble() ?? 0.0;
                                          
                                          // จัดการเรื่องข้อความของเวลาที่ใช้ไป
                                          String durationText = '-';
                                          if (trip['duration'] != null) {
                                            durationText = trip['duration'].toString();
                                            if (!durationText.contains('นาที') && !durationText.contains('ชม.')) {
                                              durationText = "$durationText นาที";
                                            }
                                          } else if (trip['start_time'] != null && trip['end_time'] != null) {
                                            final start = DateTime.tryParse(trip['start_time'].toString());
                                            final end = DateTime.tryParse(trip['end_time'].toString());
                                            if (start != null && end != null) {
                                              durationText = "${end.difference(start).inMinutes} นาที";
                                            }
                                          }

                                          return _buildTripCard(
                                            tripId: tripIdInt, // ส่งพารามิเตอร์แบบ int
                                            title: tripTitle,
                                            date: _formatDateTime(trip['start_time']),
                                            status: statusData['text'],
                                            statusColor: statusData['color'],
                                            statusIcon: statusData['icon'],
                                            icon: Icons.directions_car_filled_outlined,
                                            distance: "${distanceVal.toStringAsFixed(1)} กม.",
                                            duration: durationText,
                                            alerts: alertsCount.toString(),
                                          );
                                        },
                                      ),
                                  ],
                                ),
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
                        "ประวัติการขับขี่",
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
                            onTap: _fetchHistoryData,
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
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
                              "ประวัติทั้งหมด",
                              style: GoogleFonts.kanit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              "ระยะทางรวม ${_totalDistance.toStringAsFixed(1)} กม.",
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
              Expanded(
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
    required int tripId, // **จุดที่แก้ไข:** กำหนดให้รับค่า id เป็นประเภทตัวเลข (int)
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
                  tripId: tripId, // ส่งค่า int ที่ถูกต้องไปยังหน้า HistoryDetailScreen
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
                    Expanded(
                      child: Row(
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: GoogleFonts.kanit(
                                    color: textLight,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
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
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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