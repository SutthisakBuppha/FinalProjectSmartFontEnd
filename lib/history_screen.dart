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
  static const Color backgroundColor = Color(0xFFF3F4F6);
  static const Color cardColor = Color(0xFFFFFFFF);
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
        // แก้ไขจุดนี้: ใช้ num.tryParse เพื่อป้องกัน Error ในกรณีที่ API คืนค่าเป็น String
        final alertsCount = num.tryParse(trip['alerts_count']?.toString() ?? '')?.toInt() ?? 0;
        final distance = num.tryParse(trip['distance']?.toString() ?? '')?.toDouble() ?? 0.0;

        alertsSum += alertsCount;
        distanceSum += distance;
      }

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
              _buildHeader(scale, horizontalPadding),
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
                              padding: EdgeInsets.all(24.0 * scale),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline, color: dangerColor, size: 48 * scale),
                                  SizedBox(height: 16 * scale),
                                  Text(
                                    _errorMessage,
                                    style: GoogleFonts.kanit(color: textLight, fontSize: 14 * scale),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 16 * scale),
                                  ElevatedButton(
                                    onPressed: _fetchHistoryData,
                                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                                    child: Text("ลองใหม่อีกครั้ง", style: GoogleFonts.kanit(color: Colors.white, fontSize: 14 * scale)),
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
                                padding: EdgeInsets.fromLTRB(horizontalPadding, 24 * scale, horizontalPadding, 120 * scale),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildSummaryCard(
                                            title: "คะแนนขับขี่",
                                            value: "$_safetyScore",
                                            suffix: "/100",
                                            icon: Icons.shield_outlined,
                                            iconColor: primaryColor,
                                            scale: scale,
                                          ),
                                        ),
                                        SizedBox(width: 16 * scale),
                                        Expanded(
                                          child: _buildSummaryCard(
                                            title: "แจ้งเตือนทั้งหมด",
                                            value: "$_totalAlerts",
                                            suffix: " ครั้ง",
                                            icon: Icons.warning_amber_rounded,
                                            iconColor: warningColor,
                                            scale: scale,
                                          ),
                                        ),
                                      ],
                                    ),

                                    SizedBox(height: 24 * scale),

                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "การเดินทางล่าสุด",
                                          style: GoogleFonts.kanit(
                                            fontSize: 18 * scale,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        ),
                                        Text(
                                          "ดูทั้งหมด",
                                          style: GoogleFonts.kanit(
                                            fontSize: 14 * scale,
                                            fontWeight: FontWeight.w500,
                                            color: accentColor,
                                            decoration: TextDecoration.underline,
                                            decorationColor: accentColor,
                                          ),
                                        ),
                                      ],
                                    ),

                                    SizedBox(height: 16 * scale),

                                    if (_trips.isEmpty)
                                      Padding(
                                        padding: EdgeInsets.symmetric(vertical: 40 * scale),
                                        child: Center(
                                          child: Text(
                                            "ไม่พบประวัติการเดินทางของท่าน",
                                            style: GoogleFonts.kanit(color: subTextLight, fontSize: 16 * scale),
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
                                          
                                          // แก้ไขจุดนี้เช่นกัน: ใช้การ parse ที่ปลอดภัยสำหรับแต่ละไอเทมในลิสต์
                                          final alertsCount = num.tryParse(trip['alerts_count']?.toString() ?? '')?.toInt() ?? 0;
                                          final statusData = _getSafetyStatus(alertsCount);

                                          final int tripIdInt = num.tryParse(trip['trip_id']?.toString() ?? '')?.toInt() ?? 
                                                                num.tryParse(trip['id']?.toString() ?? '')?.toInt() ?? 0;

                                          final startLoc = trip['start_location']?.toString() ?? '';
                                          final endLoc = trip['end_location']?.toString() ?? '';
                                          String tripTitle = "การเดินทาง #$tripIdInt";
                                          
                                          if (startLoc.isNotEmpty && endLoc.isNotEmpty) {
                                            tripTitle = "$startLoc ไป $endLoc";
                                          } else if (endLoc.isNotEmpty) {
                                            tripTitle = "มุ่งสู่ $endLoc";
                                          }

                                          final distanceVal = num.tryParse(trip['distance']?.toString() ?? '')?.toDouble() ?? 0.0;
                                          
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
                                            tripId: tripIdInt,
                                            title: tripTitle,
                                            date: _formatDateTime(trip['start_time']),
                                            status: statusData['text'],
                                            statusColor: statusData['color'],
                                            statusIcon: statusData['icon'],
                                            icon: Icons.directions_car_filled_outlined,
                                            distance: "${distanceVal.toStringAsFixed(1)} กม.",
                                            duration: durationText,
                                            alerts: alertsCount.toString(),
                                            scale: scale,
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

  Widget _buildHeader(double scale, double padding) {
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
            SizedBox(height: 16 * scale),
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 0, padding, 32 * scale),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "ประวัติการขับขี่",
                        style: GoogleFonts.kanit(
                          color: Colors.white,
                          fontSize: 24 * scale,
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
                            child: Padding(
                              padding: EdgeInsets.all(8.0 * scale),
                              child: Icon(Icons.refresh_rounded, color: Colors.white, size: 20 * scale),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24 * scale),
                  
                  Container(
                    padding: EdgeInsets.all(4 * scale),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 24 * scale),
                          onPressed: () {},
                        ),
                        Column(
                          children: [
                            Text(
                              "ประวัติทั้งหมด",
                              style: GoogleFonts.kanit(color: Colors.white, fontSize: 18 * scale, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              "ระยะทางรวม ${_totalDistance.toStringAsFixed(1)} กม.",
                              style: GoogleFonts.kanit(color: Colors.white60, fontSize: 12 * scale, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 24 * scale),
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
    required double scale,
  }) {
    return Container(
      padding: EdgeInsets.all(16 * scale),
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
              Icon(icon, color: iconColor, size: 20 * scale),
              SizedBox(width: 8 * scale),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: GoogleFonts.kanit(
                    color: iconColor,
                    fontSize: 10 * scale,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * scale),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: GoogleFonts.kanit(
                    color: textLight,
                    fontSize: 24 * scale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (suffix.isNotEmpty)
                  TextSpan(
                    text: suffix,
                    style: GoogleFonts.kanit(
                      color: subTextLight,
                      fontSize: 14 * scale,
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
    required int tripId,
    required String title,
    required String date,
    required String status,
    required Color statusColor,
    required IconData statusIcon,
    required IconData icon,
    required String distance,
    required String duration,
    required String alerts,
    required double scale,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16 * scale),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: statusColor, width: 4 * scale)),
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
                  tripId: tripId,
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
                padding: EdgeInsets.all(16 * scale),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8 * scale),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, color: subTextLight, size: 24 * scale),
                          ),
                          SizedBox(width: 12 * scale),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: GoogleFonts.kanit(
                                    color: textLight,
                                    fontSize: 16 * scale,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  date,
                                  style: GoogleFonts.kanit(
                                    color: subTextLight,
                                    fontSize: 12 * scale,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 4 * scale),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 14 * scale),
                          SizedBox(width: 4 * scale),
                          Text(
                            status,
                            style: GoogleFonts.kanit(
                              color: statusColor,
                              fontSize: 12 * scale,
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
                padding: EdgeInsets.symmetric(vertical: 12 * scale),
                child: Row(
                  children: [
                    _buildTripStatItem("ระยะทาง", distance, false, scale),
                    Container(width: 1, height: 24 * scale, color: Colors.grey.shade100),
                    _buildTripStatItem("เวลาที่ใช้", duration, false, scale),
                    Container(width: 1, height: 24 * scale, color: Colors.grey.shade100),
                    _buildTripStatItem("แจ้งเตือน", alerts, true, scale, valueColor: statusColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripStatItem(String label, String value, bool isAlert, double scale, {Color? valueColor}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.kanit(
              color: isAlert && valueColor != null ? valueColor : subTextLight,
              fontSize: 12 * scale,
              fontWeight: isAlert ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          SizedBox(height: 2 * scale),
          Text(
            value,
            style: GoogleFonts.kanit(
              color: isAlert && valueColor != null ? valueColor : textLight,
              fontSize: 14 * scale,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}