import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// import 'dart:math' as math; 

// --- External Packages ---
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
// import 'package:url_launcher/url_launcher.dart'; // เปิดบรรทัดนี้ถ้าลง package แล้วเพื่อให้กดลิงก์เครดิตได้

// --- Internal Imports ---
import 'menu/custom_bottom_nav_bar.dart';
import 'main_layout.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  // --- Theme Colors ---
  static const Color primary = Color(0xFF0F2647);
  static const Color accent = Color(0xFF3B82F6);
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color textDark = Color(0xFFF8FAFC);
  static const Color subtextDark = Color(0xFF94A3B8);

  late AnimationController _pulseController;

  // พิกัดตัวอย่าง (อนุสาวรีย์ชัยสมรภูมิ)
  final LatLng _center = const LatLng(13.765, 100.538);
  final LatLng _shellStation = const LatLng(13.768, 100.542);
  final LatLng _restArea = const LatLng(13.760, 100.532);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      extendBody: true, 
      body: Stack(
        children: [
          // --- 1. Real Map Layer (แก้ไขส่วนนี้) ---
          FlutterMap(
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              // 1.1 Tile Layer (OpenStreetMap Standard)
              TileLayer(
                // URL มาตรฐานของ OpenStreetMap
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.savedriveai.app', // ควรใส่เพื่อป้องกันการโดนบล็อก
              ),

              // 1.2 Marker Layer
              MarkerLayer(
                markers: [
                  // Current Location
                  Marker(
                    point: _center,
                    width: 120,
                    height: 120,
                    child: _buildCurrentLocationPin(),
                  ),

                  // Shell Station
                  Marker(
                    point: _shellStation,
                    width: 60,
                    height: 80,
                    alignment: Alignment.topCenter,
                    child: _buildMapMarker(
                      icon: Icons.local_gas_station_rounded,
                      label: "ปั๊มเชลล์",
                      isGas: true,
                    ),
                  ),

                  // Rest Area
                  Marker(
                    point: _restArea,
                    width: 60,
                    height: 80,
                    alignment: Alignment.topCenter,
                    child: _buildMapMarker(
                      icon: Icons.chair_rounded,
                      label: "จุดพักรถ A",
                      isGas: false,
                    ),
                  ),
                ],
              ),

              // 1.3 Attribution (เครดิต OSM - จำเป็นต้องมี)
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    // ใส่ onTap: null เพื่อป้องกัน error หากยังไม่ได้ลง url_launcher
                    // ถ้าลงแล้วให้ใช้: onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                    onTap: null, 
                  ),
                ],
              ),
            ],
          ),

          // --- 2. Top UI (Header & Search) ---
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
              ],
            ),
          ),

          // --- 3. Floating Action Buttons ---
          Positioned(
            top: 120,
            right: 16,
            child: Column(
              children: [
                _buildFab(Icons.layers_rounded),
                const SizedBox(height: 12),
                _buildFab(Icons.my_location_rounded),
              ],
            ),
          ),

          // --- 4. Bottom Sheet (Nearest Locations) ---
          Positioned(
            bottom: 85, 
            left: 0,
            right: 0,
            child: _buildBottomSheet(),
          ),

          // --- 5. Custom Bottom Navigation Bar ---
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomBottomNavBar(
              currentIndex: -1, 
              onTap: (index) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MainLayout(), 
                  ),
                  (route) => false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: cardDark.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.search, color: subtextDark),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "ค้นหาจุดพักรถ...", 
                style: GoogleFonts.inter( 
                  color: subtextDark,
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: cardDark,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }

  Widget _buildCurrentLocationPin() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing Ring
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 60 + (_pulseController.value * 50),
              height: 60 + (_pulseController.value * 50),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(0.25 * (1 - _pulseController.value)),
              ),
            );
          },
        ),
        // Glow
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withOpacity(0.3),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.6),
                blurRadius: 15,
              )
            ],
          ),
        ),
        // White Core
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: accent, width: 3),
          ),
        ),
      ],
    );
  }

  Widget _buildMapMarker({
    required IconData icon,
    required String label,
    required bool isGas,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pin Head
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: primary, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: primary, size: 20),
        ),
        // Arrow (Triangle)
        Transform.translate(
          offset: const Offset(0, -1),
          child: ClipPath(
            clipper: TriangleClipper(),
            child: Container(width: 12, height: 8, color: primary),
          ),
        ),
        const SizedBox(height: 4),
        // Label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSheet() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardDark.withOpacity(0.98),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
          bottom: Radius.circular(24),
        ),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "สถานที่ใกล้เคียง", 
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "ในระยะ 5 กม.", 
                      style: TextStyle(color: subtextDark, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLocationCard(
                  name: "ปั๊มเชลล์",
                  distance: "1.2 กม. • 4 นาที",
                  icon: Icons.local_gas_station_rounded,
                  iconColor: Colors.blue.shade400,
                  iconBg: Colors.blue.shade900.withOpacity(0.4),
                ),
                const SizedBox(height: 12),
                _buildLocationCard(
                  name: "จุดพักรถ A",
                  distance: "2.5 กม. • 8 นาที",
                  icon: Icons.chair_rounded,
                  iconColor: Colors.indigo.shade400,
                  iconBg: Colors.indigo.shade900.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard({
    required String name,
    required String distance,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Info
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.near_me, size: 12, color: subtextDark),
                      const SizedBox(width: 4),
                      Text(
                        distance,
                        style: const TextStyle(
                          color: subtextDark,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Right: Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: const [
                Icon(Icons.directions, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  "นำทาง",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TriangleClipper extends CustomClipper<ui.Path> {
  @override
  ui.Path getClip(Size size) {
    final path = ui.Path(); 
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<ui.Path> oldClipper) => false;
}