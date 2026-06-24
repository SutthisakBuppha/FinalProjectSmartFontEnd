import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- Import สำหรับแผนที่ ---
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class HistoryDetailScreen extends StatelessWidget {
  // 1. รับข้อมูลจากหน้า List
  final String title;
  final String date;
  final String distance;
  final String duration;
  final String alerts;
  final String status;
  final Color statusColor;

  const HistoryDetailScreen({
    super.key,
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
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
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // แผนที่
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
                                  color: primaryColor,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "แจ้งเตือน $alerts ครั้ง",
                                  style: GoogleFonts.prompt(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Mockup Details List
                          if (alerts != "0") ...[
                            _buildRiskCard(
                              title: "ตรวจพบความง่วง",
                              desc: "ระยะเวลาการหลับตาเกินกำหนดความปลอดภัย",
                              time: "08:52 น.",
                              icon: Icons.bedtime_rounded,
                              color: dangerColor,
                            ),
                            const SizedBox(height: 12),
                          ] else
                            Center(
                                child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Text(
                                "ไม่พบเหตุการณ์ความเสี่ยงในการเดินทางนี้",
                                style: GoogleFonts.prompt(color: subTextLight),
                              ),
                            )),

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
          colors: [primaryColor, secondaryColor],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
              color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
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
                child: Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 24),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.prompt(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                Text(
                  date,
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
                child: Icon(Icons.ios_share_rounded,
                    color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Stats Card ---
  Widget _buildStatsCard() {
    int score = 100 - ((int.tryParse(alerts) ?? 0) * 5);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
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
                "ระยะทาง", distance.replaceAll(" km", ""), "กม.", textLight),
            VerticalDivider(color: Colors.grey.shade200, width: 1, thickness: 1),
            _buildStatItem(
                "ระยะเวลา", duration.replaceAll(" min", ""), "นาที", textLight),
            VerticalDivider(color: Colors.grey.shade200, width: 1, thickness: 1),
            _buildStatItem("คะแนนขับขี่", "$score", "/100", statusColor),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, String unit, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.prompt(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: subTextLight,
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
                  color: subTextLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskCard(
      {required String title,
      required String desc,
      required String time,
      required IconData icon,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
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
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
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
                        color: textLight)),
                const SizedBox(height: 2),
                Text(desc,
                    style: GoogleFonts.prompt(
                        fontSize: 12, color: subTextLight)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4)),
            child: Text(time,
                style: GoogleFonts.prompt(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textLight)),
          ),
        ],
      ),
    );
  }

  // --- Real Map Section (ใช้ OpenStreetMap) ---
  Widget _buildRealMapSection() {
    // พิกัดจำลองเส้นทาง
    final routePoints = [
      const LatLng(13.765, 100.538), // Start
      const LatLng(13.760, 100.535),
      const LatLng(13.755, 100.534),
      const LatLng(13.750, 100.532),
      const LatLng(13.746, 100.532), // End
    ];

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
            initialCenter: const LatLng(13.755, 100.535), // จุดกึ่งกลาง
            initialZoom: 14.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            // 1. Tile Layer (OpenStreetMap Standard)
            TileLayer(
              // URL มาตรฐานของ OpenStreetMap
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              // สำคัญ: ต้องระบุ userAgentPackageName ตามกฎของ OSM
              userAgentPackageName: 'com.savedriveai.app',
            ),

            // 2. Polyline Layer (เส้นทาง)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
                  strokeWidth: 5.0,
                  color: primaryColor,
                ),
              ],
            ),

            // 3. Marker Layer (จุดเริ่ม/จบ)
            MarkerLayer(
              markers: [
                Marker(
                  point: routePoints.first,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.trip_origin,
                      color: primaryColor, size: 30),
                ),
                Marker(
                  point: routePoints.last,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on_rounded,
                      color: Colors.red, size: 36),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}