import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

// --- Import สำหรับแผนที่ ---
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// สมมติว่ามี ApiService สำหรับดึง baseUrl หรือ Token ของระบบอยู่แล้ว
import '/services/api_service.dart'; 

class HistoryDetailScreen extends StatefulWidget {
  // 1. รับข้อมูลจากหน้า List (เพิ่ม tripId เข้ามาเพื่อดึงข้อมูลจุดพิกัดและการแจ้งเตือนเฉพาะของทริปนี้)
  final int tripId; 
  final String title;
  final String date;
  final String distance;
  final String duration;
  final String alerts;
  final String status;
  final Color statusColor;

  const HistoryDetailScreen({
    super.key,
    required this.tripId,
    required this.title,
    required this.date,
    required this.distance,
    required this.duration,
    required this.alerts,
    required this.status,
    required this.statusColor,
  });

  // --- Theme Colors ---
  static const Color primaryColor = Color(0xFF0F2647);
  static const Color secondaryColor = Color(0xFF1E3A66);
  static const Color backgroundColor = Color(0xFFF3F4F6);
  static const Color cardColor = Colors.white;
  static const Color dangerColor = Color(0xFFEF4444);
  static const Color textLight = Color(0xFF1F2937);
  static const Color subTextLight = Color(0xFF6B7280);

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  // เก็บข้อมูลจริงที่ดึงมาจาก API หลังบ้าน
  List<LatLng> routePoints = [];
  List<dynamic> alertsList = [];
  
  bool isLoadingMap = true;
  bool isLoadingAlerts = true;
  String? mapError;
  String? alertsError;

  @override
  void initState() {
    super.initState();
    _fetchRoutePoints();
    _fetchTripAlerts();
  }

  // 1. ดึงพิกัดเส้นทางการเดินทางจาก TripLocationController
  Future<void> _fetchRoutePoints() async {
    try {
      final baseUrl = ApiService.instance.baseUrl; 
      final response = await http.get(
        Uri.parse('$baseUrl/trips/${widget.tripId}/locations'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          final List<dynamic> locations = decoded['data'];
          
          setState(() {
            routePoints = locations.map((item) {
              return LatLng(
                double.parse(item['latitude'].toString()),
                double.parse(item['longitude'].toString()),
              );
            }).toList();
            isLoadingMap = false;
          });
          return;
        }
      }
      setState(() {
        mapError = "ไม่สามารถโหลดข้อมูลพิกัดได้";
        isLoadingMap = false;
      });
    } catch (e) {
      setState(() {
        mapError = "เกิดข้อผิดพลาดในการเชื่อมต่อเครือข่าย";
        isLoadingMap = false;
      });
    }
  }

  // 2. ดึงรายการแจ้งเตือนความเสี่ยงเฉพาะของทริปนี้
  Future<void> _fetchTripAlerts() async {
    try {
      final baseUrl = ApiService.instance.baseUrl;
      // เรียกจุดเชื่อมต่อ API ที่กรองตาม trip_id หรือจุดที่ระบุไว้ของหลังบ้านคุณ
      final response = await http.get(
        Uri.parse('$baseUrl/alerts?trip_id=${widget.tripId}'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          final List<dynamic> allAlerts = decoded['data'];
          
          // ทำการกรองเอาเฉพาะ alert_id ที่ตรงกับทริปนี้ (กรณี API ดึงรวมมาทั้งหมด)
          final filteredAlerts = allAlerts.where((alert) => alert['trip_id'] == widget.tripId).toList();

          setState(() {
            alertsList = filteredAlerts;
            isLoadingAlerts = false;
          });
          return;
        }
      }
      setState(() {
        alertsError = "ไม่สามารถโหลดข้อมูลความเสี่ยงได้";
        isLoadingAlerts = false;
      });
    } catch (e) {
      setState(() {
        alertsError = "เกิดข้อผิดพลาดในการเชื่อมต่อ";
        isLoadingAlerts = false;
      });
    }
  }

  // แปลงประเภท Alert ภาษาไทยจับคู่กับ Icon และสี
  Map<String, dynamic> _getAlertMeta(String type) {
    switch (type) {
      case 'ง่วงนอน':
        return {
          'title': 'ตรวจพบความง่วงนอน',
          'desc': 'ระยะเวลาการหลับตาเกินกำหนดความปลอดภัย',
          'icon': Icons.bedtime_rounded,
          'color': HistoryDetailScreen.dangerColor,
        };
      case 'ใช้โทรศัพท์':
        return {
          'title': 'ใช้โทรศัพท์ขณะขับขี่',
          'desc': 'ตรวจพบผู้ขับขี่ยกโทรศัพท์ขึ้นมาใช้ในสายตากล้อง',
          'icon': Icons.phone_android_rounded,
          'color': HistoryDetailScreen.dangerColor,
        };
      case 'เสียสมาธิ':
        return {
          'title': 'เสียสมาธิ / ไม่มองทาง',
          'desc': 'สายตาของผู้ขับขี่ไม่ได้จับจ้องที่พื้นผิวถนน',
          'icon': Icons.visibility_off_rounded,
          'color': Colors.orange,
        };
      case 'เหม่อลอย':
        return {
          'title': 'ตรวจพบอาการเหม่อลอย',
          'desc': 'ใบหน้าหรือสายตาหันเหออกจากทิศทางขับขี่เป็นเวลานาน',
          'icon': Icons.blur_on_rounded,
          'color': Colors.orange,
        };
      case 'หาว':
        return {
          'title': 'สัญญาณอาการล้า (หาว)',
          'desc': 'ผู้ขับขี่มีการอ้าปากหาว สัญญาณเริ่มต้นความง่วงนอน',
          'icon': Icons.sentiment_very_dissatisfied_rounded,
          'color': Colors.amber.shade700,
        };
      default:
        return {
          'title': 'แจ้งเตือนพฤติกรรมเสี่ยง ($type)',
          'desc': 'พบพฤติกรรมที่อาจทำให้เกิดความไม่ปลอดภัย',
          'icon': Icons.warning_amber_rounded,
          'color': Colors.grey,
        };
    }
  }

  // ฟังก์ชันจัดรูปแบบเวลาดึงเฉพาะ HH:mm น.
  String _formatTime(String? timestampStr) {
    if (timestampStr == null) return "--:-- น.";
    try {
      final dateTime = DateTime.parse(timestampStr).toLocal();
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return "$hour:$minute น.";
    } catch (e) {
      return "--:-- น.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HistoryDetailScreen.backgroundColor,
      body: Column(
        children: [
          // --- 1. Header Section ---
          _buildHeader(context),

          // --- 2. Scrollable Content ---
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // --- Stats Card (เลื่อนขึ้นไปทับ Header นิดหน่อย) ---
                  Transform.translate(
                    offset: const Offset(0, -32),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildStatsCard(),
                    ),
                  ),

                  // Content
                  Transform.translate(
                    offset: const Offset(0, -16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ภาพรวมเส้นทาง",
                            style: GoogleFonts.prompt(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: HistoryDetailScreen.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ส่วนแสดงแผนที่ดึงจากหลังบ้าน
                          _buildRealMapSection(),

                          const SizedBox(height: 24),

                          // --- Risk Events ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "เหตุการณ์ความเสี่ยง",
                                style: GoogleFonts.prompt(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: HistoryDetailScreen.primaryColor,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: widget.statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isLoadingAlerts 
                                      ? "กำลังโหลด..." 
                                      : "แจ้งเตือน ${alertsList.length} ครั้ง",
                                  style: GoogleFonts.prompt(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: widget.statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // รายการความเสี่ยงแบบ Dynamic จาก API หลังบ้าน
                          _buildDynamicRiskEventsList(),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Header Widget ---
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 48,
        left: 24,
        right: 24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [HistoryDetailScreen.primaryColor, HistoryDetailScreen.secondaryColor],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Material(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(50),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(50),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.prompt(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                Text(
                  widget.date,
                  style: GoogleFonts.prompt(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(50),
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(50),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.ios_share_rounded, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Stats Card ---
  Widget _buildStatsCard() {
    int currentAlertCount = isLoadingAlerts ? (int.tryParse(widget.alerts) ?? 0) : alertsList.length;
    int score = 100 - (currentAlertCount * 5);
    if (score < 0) score = 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HistoryDetailScreen.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _buildStatItem(
                "ระยะทาง", widget.distance.replaceAll(" km", ""), "กม.", HistoryDetailScreen.textLight),
            VerticalDivider(color: Colors.grey.shade200, width: 1, thickness: 1),
            _buildStatItem(
                "ระยะเวลา", widget.duration.replaceAll(" min", ""), "นาที", HistoryDetailScreen.textLight),
            VerticalDivider(color: Colors.grey.shade200, width: 1, thickness: 1),
            _buildStatItem("คะแนนขับขี่", "$score", "/100", widget.statusColor),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String unit, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.prompt(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: HistoryDetailScreen.subTextLight,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.prompt(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.prompt(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: HistoryDetailScreen.subTextLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- ส่วนจัดการการแสดงผลรายการเหตุการณ์แจ้งเตือนความเสี่ยงจริง ---
  Widget _buildDynamicRiskEventsList() {
    if (isLoadingAlerts) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(color: HistoryDetailScreen.primaryColor),
        ),
      );
    }

    if (alertsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(alertsError!, style: GoogleFonts.prompt(color: HistoryDetailScreen.dangerColor)),
        ),
      );
    }

    if (alertsList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            "ไม่พบเหตุการณ์ความเสี่ยงในการเดินทางนี้ 🎉",
            style: GoogleFonts.prompt(color: HistoryDetailScreen.subTextLight),
          ),
        ),
      );
    }

    return Column(
      children: alertsList.map((alert) {
        final type = alert['type'] ?? '';
        final timestamp = alert['timestamp'] ?? alert['created_at'];
        final meta = _getAlertMeta(type);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildRiskCard(
            title: meta['title'],
            desc: meta['desc'],
            time: _formatTime(timestamp),
            icon: meta['icon'],
            color: meta['color'],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRiskCard({
    required String title,
    required String desc,
    required String time,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HistoryDetailScreen.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.prompt(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: HistoryDetailScreen.textLight)),
                const SizedBox(height: 2),
                Text(desc,
                    style: GoogleFonts.prompt(fontSize: 12, color: HistoryDetailScreen.subTextLight)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
            child: Text(time,
                style: GoogleFonts.prompt(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: HistoryDetailScreen.textLight)),
          ),
        ],
      ),
    );
  }

  // --- Real Map Section (ใช้ข้อมูลพิกัดจริง) ---
  Widget _buildRealMapSection() {
    if (isLoadingMap) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator(color: HistoryDetailScreen.primaryColor)),
      );
    }

    if (mapError != null) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Text(mapError!, style: GoogleFonts.prompt(color: HistoryDetailScreen.dangerColor)),
        ),
      );
    }

    if (routePoints.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Text("ไม่มีข้อมูลเส้นทางการเดินทางเก็บไว้", style: GoogleFonts.prompt(color: HistoryDetailScreen.subTextLight)),
        ),
      );
    }

    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: routePoints.first, // ตั้งจุดกลางเริ่มต้นที่พิกัดแรกของทริปจริง
            initialZoom: 15.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            // 1. Tile Layer (OpenStreetMap)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.savedriveai.app',
            ),

            // 2. Polyline Layer (วาดตามจุดพิกัดจริง)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
                  strokeWidth: 5.0,
                  color: HistoryDetailScreen.primaryColor,
                ),
              ],
            ),

            // 3. Marker Layer (ปักหมุด จุดเริ่ม / จุดจบ จริง)
            MarkerLayer(
              markers: [
                Marker(
                  point: routePoints.first,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.trip_origin, color: HistoryDetailScreen.primaryColor, size: 30),
                ),
                Marker(
                  point: routePoints.last,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on_rounded, color: Colors.red, size: 36),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}