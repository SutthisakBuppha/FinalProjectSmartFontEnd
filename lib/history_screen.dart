import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

import 'menu/custom_bottom_nav_bar.dart';
import 'history_detail_screen.dart';
import '/services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // --- API State Variables ---
  List<Map<String, dynamic>> _trips = [];
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // --- Summary Variables ---
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
      final results = await Future.wait([
        ApiService.instance.trips(),
        ApiService.instance.alerts(),
      ]);
      final fetchedTrips = results[0] as List<Map<String, dynamic>>;
      final fetchedAlerts = results[1] as List<Map<String, dynamic>>;

      double distanceSum = 0.0;

      for (var trip in fetchedTrips) {
        final distance =
            num.tryParse(trip['distance']?.toString() ?? '')?.toDouble() ?? 0.0;
        distanceSum += distance;
      }

      setState(() {
        _trips = fetchedTrips;
        _totalAlerts = fetchedAlerts.length;
        _totalDistance = distanceSum;
        _alerts = fetchedAlerts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _alertsOfType(String type) {
    final result = _alerts.where((alert) {
      final alertType = alert['type']?.toString();

      // AI บันทึกอาการลืมตานานในฐานข้อมูลว่า
      // "ไม่กระพริบตาเป็นเวลานาน" แต่หน้า History แสดงเป็นหมวด "เหม่อลอย"
      if (type == 'เหม่อลอย') {
        return alertType == 'เหม่อลอย' ||
            alertType == 'ไม่กระพริบตาเป็นเวลานาน';
      }

      return alertType == type;
    }).toList();
    result.sort((a, b) {
      final aTime =
          DateTime.tryParse(
            (a['timestamp'] ?? a['created_at'] ?? '').toString(),
          ) ??
          DateTime(0);
      final bTime =
          DateTime.tryParse(
            (b['timestamp'] ?? b['created_at'] ?? '').toString(),
          ) ??
          DateTime(0);
      return bTime.compareTo(aTime);
    });
    return result;
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '-';
    final dateTime = DateTime.tryParse(dateStr);
    if (dateTime == null) return dateStr;

    final months = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];
    final days = [
      'อาทิตย์',
      'จันทร์',
      'อังคาร',
      'พุธ',
      'พฤหัสบดี',
      'ศุกร์',
      'เสาร์',
    ];

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
        'color': AppColors.success,
        'icon': Icons.verified_user_rounded,
      };
    } else if (alertsCount <= 3) {
      return {
        'text': 'ปานกลาง',
        'color': AppColors.warning,
        'icon': Icons.error_outline_rounded,
      };
    } else {
      return {
        'text': 'ความเสี่ยงสูง',
        'color': AppColors.danger,
        'icon': Icons.warning_rounded,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    double scale = screenWidth / 375.0;
    scale = scale.clamp(0.85, 1.25);
    final horizontalPadding = (screenWidth * 0.05).clamp(16.0, 24.0);

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      extendBody: true,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.cFF0F2647),
              ),
            )
          : _errorMessage.isNotEmpty
          ? _buildErrorState(scale)
          : RefreshIndicator(
              onRefresh: _fetchHistoryData,
              color: AppColors.cFF0F2647,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 1. ส่วน Header พื้นหลังสีน้ำเงินเข้ม
                        _buildModernHeader(),

                        // 2. ส่วนเนื้อหาที่เลื่อนได้และซ้อนทับ Header (Overlap)
                        Padding(
                          // ใช้ตำแหน่งคงที่เหมือน NotificationScreen
                          // ไม่ขยายตามความกว้างจนเกิดช่องว่างด้านบนมากเกินไป
                          padding: const EdgeInsets.only(top: 198),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // สถิติ AI แนวนอน
                              _buildHorizontalDetectionCards(
                                scale,
                                horizontalPadding,
                              ),
                              SizedBox(height: 24 * scale),

                              // ประวัติการเดินทางทั้งหมด
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: horizontalPadding,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "ประวัติการเดินทางล่าสุด",
                                      style: GoogleFonts.prompt(
                                        fontSize: 18 * scale,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.cFF0F2647,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16 * scale),

                              // รายการทริป
                              if (_trips.isEmpty)
                                Padding(
                                  padding: EdgeInsets.all(40 * scale),
                                  child: Center(
                                    child: Text(
                                      "ไม่พบประวัติการเดินทางของท่าน",
                                      style: GoogleFonts.prompt(
                                        color: AppColors.cFF6B7280,
                                        fontSize: 16 * scale,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    horizontalPadding,
                                    0,
                                    horizontalPadding,
                                    100 * scale,
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    padding: EdgeInsets.zero,
                                    itemCount: _trips.length,
                                    itemBuilder: (context, index) {
                                      return _buildModernTripCard(
                                        _trips[index],
                                        scale,
                                      );
                                    },
                                  ),
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

  // ---------------------------------------------------------
  // UI WIDGETS
  // ---------------------------------------------------------

  Widget _buildModernHeader() {
    return Container(
      height: 244,
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cFF0F2647, AppColors.cFF1E3A66],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ประวัติการขับขี่",
                style: GoogleFonts.prompt(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: _fetchHistoryData,
                tooltip: 'รีเฟรชข้อมูล',
                icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildHeaderStatWidget(
                  title: "ระยะทางรวม",
                  value: _totalDistance.toStringAsFixed(1),
                  unit: "กม.",
                  icon: Icons.route_rounded,
                  scale: 1,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.2),
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              Expanded(
                child: _buildHeaderStatWidget(
                  title: "แจ้งเตือนทั้งหมด",
                  value: "$_totalAlerts",
                  unit: "ครั้ง",
                  icon: Icons.warning_amber_rounded,
                  scale: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStatWidget({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required double scale,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10 * scale),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24 * scale),
        ),
        SizedBox(width: 12 * scale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.prompt(
                  color: Colors.white70,
                  fontSize: 13 * scale,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.prompt(
                      color: Colors.white,
                      fontSize: 22 * scale,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(width: 4 * scale),
                  Padding(
                    padding: EdgeInsets.only(bottom: 2 * scale),
                    child: Text(
                      unit,
                      style: GoogleFonts.prompt(
                        color: Colors.white70,
                        fontSize: 13 * scale,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalDetectionCards(double scale, double padding) {
    const detectionTypes = [
      ('ง่วงนอน', Icons.bedtime_rounded, AppColors.warning),
      ('เหม่อลอย', Icons.blur_on_rounded, Colors.purpleAccent),
      ('ไม่มองถนน', Icons.visibility_off_rounded, AppColors.danger),
    ];

    return SizedBox(
      height: 130 * scale,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: padding),
        itemCount: detectionTypes.length,
        itemBuilder: (context, index) {
          final item = detectionTypes[index];
          final alerts = _alertsOfType(item.$1);
          final latest = alerts.isEmpty
              ? null
              : alerts.first['timestamp'] ?? alerts.first['created_at'];

          return Container(
            width: 140 * scale,
            margin: EdgeInsets.only(right: 12 * scale),
            padding: EdgeInsets.all(16 * scale),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20 * scale),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8 * scale),
                      decoration: BoxDecoration(
                        color: item.$3.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.$2, color: item.$3, size: 20 * scale),
                    ),
                    Text(
                      '${alerts.length}',
                      style: GoogleFonts.prompt(
                        fontSize: 22 * scale,
                        fontWeight: FontWeight.bold,
                        color: AppColors.cFF1F2937,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$1,
                      style: GoogleFonts.prompt(
                        fontSize: 14 * scale,
                        fontWeight: FontWeight.w600,
                        color: AppColors.cFF1F2937,
                      ),
                    ),
                    SizedBox(height: 2 * scale),
                    Text(
                      latest == null
                          ? 'ไม่มีข้อมูล'
                          : 'ล่าสุด: ${_formatTimeOnly(latest.toString())}',
                      style: GoogleFonts.prompt(
                        fontSize: 11 * scale,
                        color: AppColors.cFF6B7280,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ฟังก์ชันแยกเวลาเพื่อแสดงผลสั้นๆ ในการ์ด AI
  String _formatTimeOnly(String dateStr) {
    final dateTime = DateTime.tryParse(dateStr);
    if (dateTime == null) return '-';
    String hour = dateTime.hour.toString().padLeft(2, '0');
    String minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute น.';
  }

  Widget _buildModernTripCard(Map<String, dynamic> trip, double scale) {
    final alertsCount =
        num.tryParse(trip['alerts_count']?.toString() ?? '')?.toInt() ?? 0;
    final statusData = _getSafetyStatus(alertsCount);

    final tripId = (trip['trip_id'] ?? trip['id'] ?? '').toString();
    final startLoc = trip['start_location']?.toString() ?? '';
    final endLoc = trip['end_location']?.toString() ?? '';

    String tripTitle = "การเดินทาง #$tripId";
    if (startLoc.isNotEmpty && endLoc.isNotEmpty) {
      tripTitle = "$startLoc  ➔  $endLoc";
    } else if (endLoc.isNotEmpty) {
      tripTitle = "มุ่งสู่ $endLoc";
    }

    final distanceVal =
        num.tryParse(trip['distance']?.toString() ?? '')?.toDouble() ?? 0.0;
    String durationText = '-';

    // Prefer calculating from start/end so old records affected by the
    // UTC/Asia-Bangkok 420-minute bug are displayed correctly too.
    if (trip['start_time'] != null && trip['end_time'] != null) {
      final start = DateTime.tryParse(trip['start_time'].toString());
      final end = DateTime.tryParse(trip['end_time'].toString());
      if (start != null && end != null) {
        durationText = "${end.difference(start).inMinutes.abs()} นาที";
      }
    } else if (trip['duration'] != null) {
      durationText = trip['duration'].toString();
      if (!durationText.contains('นาที') && !durationText.contains('ชม.')) {
        durationText = "$durationText นาที";
      }
    }

    final Color statusColor = statusData['color'];

    return Container(
      margin: EdgeInsets.only(bottom: 16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16 * scale),
        child: InkWell(
          borderRadius: BorderRadius.circular(16 * scale),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HistoryDetailScreen(
                  tripId: tripId,
                  title: tripTitle,
                  date: _formatDateTime(trip['start_time']),
                  distance: "${distanceVal.toStringAsFixed(1)} กม.",
                  duration: durationText,
                  alerts: alertsCount.toString(),
                  status: statusData['text'],
                  statusColor: statusColor,
                ),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(16 * scale),
            child: Column(
              children: [
                // Top Row: Date & Status Chip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 14 * scale,
                          color: AppColors.cFF6B7280,
                        ),
                        SizedBox(width: 6 * scale),
                        Text(
                          _formatDateTime(trip['start_time']),
                          style: GoogleFonts.prompt(
                            fontSize: 13 * scale,
                            color: AppColors.cFF6B7280,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8 * scale,
                        vertical: 4 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusData['icon'],
                            size: 12 * scale,
                            color: statusColor,
                          ),
                          SizedBox(width: 4 * scale),
                          Text(
                            statusData['text'],
                            style: GoogleFonts.prompt(
                              fontSize: 11 * scale,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12 * scale),

                // Middle Row: Title (Route)
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10 * scale),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.directions_car_filled_rounded,
                        color: AppColors.cFF0F2647,
                        size: 20 * scale,
                      ),
                    ),
                    SizedBox(width: 12 * scale),
                    Expanded(
                      child: Text(
                        tripTitle,
                        style: GoogleFonts.prompt(
                          fontSize: 16 * scale,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cFF1F2937,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16 * scale),

                // Bottom Row: Stats
                Container(
                  padding: EdgeInsets.symmetric(
                    vertical: 12 * scale,
                    horizontal: 16 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(
                      0.04,
                    ), // สีพื้นหลังอ่อนๆ ตามสถานะความปลอดภัย
                    borderRadius: BorderRadius.circular(12 * scale),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTripMetric(
                        "ระยะทาง",
                        "${distanceVal.toStringAsFixed(1)} กม.",
                        scale,
                      ),
                      _buildTripMetric("เวลา", durationText, scale),
                      _buildTripMetric(
                        "แจ้งเตือน",
                        "$alertsCount ครั้ง",
                        scale,
                        valueColor: alertsCount > 0
                            ? statusColor
                            : AppColors.success,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTripMetric(
    String label,
    String value,
    double scale, {
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.prompt(
            fontSize: 12 * scale,
            color: AppColors.cFF6B7280,
          ),
        ),
        SizedBox(height: 2 * scale),
        Text(
          value,
          style: GoogleFonts.prompt(
            fontSize: 14 * scale,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.cFF1F2937,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(double scale) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.0 * scale),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              color: AppColors.danger,
              size: 64 * scale,
            ),
            SizedBox(height: 16 * scale),
            Text(
              "เกิดข้อผิดพลาดในการดึงข้อมูล",
              style: GoogleFonts.prompt(
                color: AppColors.cFF1F2937,
                fontSize: 18 * scale,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8 * scale),
            Text(
              _errorMessage,
              style: GoogleFonts.prompt(
                color: AppColors.cFF6B7280,
                fontSize: 14 * scale,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24 * scale),
            ElevatedButton.icon(
              onPressed: _fetchHistoryData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cFF0F2647,
                padding: EdgeInsets.symmetric(
                  horizontal: 24 * scale,
                  vertical: 12 * scale,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 18 * scale,
              ),
              label: Text(
                "ลองใหม่อีกครั้ง",
                style: GoogleFonts.prompt(
                  color: Colors.white,
                  fontSize: 16 * scale,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
