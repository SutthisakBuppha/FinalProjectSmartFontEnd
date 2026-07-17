import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

// --- External Packages ---
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart'; // ใช้เปิดแอป Google Maps เพื่อนำทางจริง

// --- Internal Imports ---
import 'menu/custom_bottom_nav_bar.dart';
import 'main_layout.dart';

/// โมเดลข้อมูลสถานที่ใกล้เคียง (ปั๊มน้ำมัน / จุดพักรถ) ที่ได้จาก Overpass API
class NearbyPlace {
  final String id;
  final String name;
  final LatLng location;
  final bool isGasStation; // true = ปั๊มน้ำมัน, false = จุดพักรถ
  double distanceMeters;

  NearbyPlace({
    required this.id,
    required this.name,
    required this.location,
    required this.isGasStation,
    this.distanceMeters = 0,
  });

  String get distanceLabel {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toStringAsFixed(0)} ม.';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} กม.';
  }
}

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
  static const Color dangerRed = Color(0xFFDC2626);

  late AnimationController _pulseController;
  final MapController _mapController = MapController();

  // ── GPS / ตำแหน่งปัจจุบัน ──────────────────────────────────────────────
  LatLng? _currentLatLng;
  StreamSubscription<Position>? _positionStream;
  bool _isResolvingLocation = true; // กำลังเช็ค GPS / ขอ permission / ดึงตำแหน่งแรก
  String? _locationError; // ข้อความ error ถ้าเปิด GPS ไม่ได้ / โดนปฏิเสธสิทธิ์

  // ── สถานที่ใกล้เคียง ────────────────────────────────────────────────────
  List<NearbyPlace> _nearbyPlaces = [];
  bool _isLoadingPlaces = false;
  String? _placesError;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _initLocationFlow(); // ← เริ่ม flow ทั้งหมดตั้งแต่เช็ค GPS จนถึงหาสถานที่ใกล้เคียง
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _positionStream?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ข้อ 3-6: เช็ค GPS -> ขอ permission -> ดึงตำแหน่งปัจจุบัน -> ติดตาม real-time
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _initLocationFlow() async {
    setState(() {
      _isResolvingLocation = true;
      _locationError = null;
    });

    // ── ข้อ 3: เช็คว่า GPS (Location Service) เปิดอยู่ไหม ──────────────
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _isResolvingLocation = false;
        _locationError = 'กรุณาเปิดสัญญาณ GPS ของเครื่องก่อนใช้งานแผนที่';
      });
      return;
    }

    // ── ข้อ 4: ขอสิทธิ์การเข้าถึงตำแหน่ง ─────────────────────────────
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _isResolvingLocation = false;
          _locationError = 'แอปต้องการสิทธิ์เข้าถึงตำแหน่งเพื่อค้นหาจุดพักรถที่ใกล้ที่สุด';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _isResolvingLocation = false;
        _locationError =
            'สิทธิ์เข้าถึงตำแหน่งถูกปิดถาวร กรุณาไปเปิดในตั้งค่าแอปด้วยตนเอง';
      });
      return;
    }

    // ── ข้อ 5: ดึงตำแหน่งปัจจุบัน (ใช้แทนค่า hardcode เดิม) ────────────
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final latLng = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() {
        _currentLatLng = latLng;
        _isResolvingLocation = false;
      });

      // 🔴 [แก้] เดิมเรียก _mapController.move(latLng, 15.0) ตรงนี้ทันทีหลัง setState()
      // แต่ setState() แค่ "ขอให้ build ใหม่" เท่านั้น ไม่ได้ build แบบ synchronous
      // ตอนที่โค้ดรันมาถึงบรรทัดนี้ FlutterMap widget (เจ้าของ MapController จริง)
      // ยังไม่ทัน mount / attach controller เข้ากับ widget เลย
      // ทำให้เกิด LateInitializationError: Field '_internalController' has not been initialized
      //
      // วิธีแก้: รอให้เฟรมปัจจุบัน build เสร็จสมบูรณ์ก่อน (post frame callback)
      // ถึงจะเรียก .move() ได้อย่างปลอดภัย
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(latLng, 15.0);
        }
      });

      // ── ข้อ 7: ค้นหาปั๊ม/จุดพักรถใกล้เคียงจากตำแหน่งจริง ─────────────
      _fetchNearbyPlaces(latLng);

      // ── ข้อ 6: เริ่มติดตามตำแหน่งแบบ real-time ───────────────────────
      _startLiveTracking();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResolvingLocation = false;
        _locationError = 'ไม่สามารถดึงตำแหน่งปัจจุบันได้: $e';
      });
    }
  }

  void _startLiveTracking() {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // อัปเดตทุกๆ 10 เมตรที่เคลื่อนที่
      ),
    ).listen((Position pos) {
      if (!mounted) return;
      final updated = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentLatLng = updated;
        // อัปเดตระยะทางของสถานที่ใกล้เคียงตามตำแหน่งใหม่ทุกครั้ง
        for (final place in _nearbyPlaces) {
          place.distanceMeters = Geolocator.distanceBetween(
            updated.latitude,
            updated.longitude,
            place.location.latitude,
            place.location.longitude,
          );
        }
        _nearbyPlaces.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      });
    }, onError: (_) {
      // ไม่ต้อง block UI ถ้า stream error ระหว่างทาง แค่เงียบไว้
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ข้อ 7: หาปั๊ม/จุดพักรถใกล้เคียงจริง ผ่าน Overpass API (OpenStreetMap)
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _fetchNearbyPlaces(LatLng center, {double radiusMeters = 5000}) async {
    setState(() {
      _isLoadingPlaces = true;
      _placesError = null;
    });

    final query = '''
      [out:json][timeout:25];
      (
        node["amenity"="fuel"](around:$radiusMeters,${center.latitude},${center.longitude});
        node["highway"="rest_area"](around:$radiusMeters,${center.latitude},${center.longitude});
        node["highway"="services"](around:$radiusMeters,${center.latitude},${center.longitude});
      );
      out body;
    ''';

    final url = Uri.parse(
      'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('เซิร์ฟเวอร์แผนที่ตอบกลับผิดพลาด (${response.statusCode})');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final elements = (data['elements'] as List<dynamic>? ?? []);

      final places = elements.map((el) {
        final tags = (el['tags'] as Map<String, dynamic>? ?? {});
        final isGas = tags['amenity'] == 'fuel';
        final name = tags['name'] as String? ?? (isGas ? 'ปั๊มน้ำมัน' : 'จุดพักรถ');

        final loc = LatLng(
          (el['lat'] as num).toDouble(),
          (el['lon'] as num).toDouble(),
        );

        return NearbyPlace(
          id: el['id'].toString(),
          name: name,
          location: loc,
          isGasStation: isGas,
          distanceMeters: Geolocator.distanceBetween(
            center.latitude,
            center.longitude,
            loc.latitude,
            loc.longitude,
          ),
        );
      }).toList();

      // ── ข้อ 9: เรียงลำดับตามระยะทางใกล้สุดก่อน ──────────────────────
      places.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

      if (!mounted) return;
      setState(() {
        _nearbyPlaces = places.take(20).toList(); // เอามาแสดง 20 อันดับแรกพอ
        _isLoadingPlaces = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingPlaces = false;
        _placesError = 'ค้นหาสถานที่ใกล้เคียงไม่สำเร็จ: $e';
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ข้อ 8: กดปุ่ม "นำทาง" -> เปิดแอป Google Maps จริงเพื่อนำทางแบบ
  // turn-by-turn (ปลอดภัยกว่าการคำนวณ/วาดเส้นทางเองในแอป)
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _navigateTo(NearbyPlace place) async {
    final destination =
        '${place.location.latitude},${place.location.longitude}';

    // ใช้ Google Maps URL scheme แบบเป็นทางการ (api=1) ซึ่งรองรับทั้ง Android/iOS
    // ถ้าเครื่องมีแอป Google Maps ติดตั้งอยู่จะเปิดแอปโดยตรง
    // ถ้าไม่มีจะ fallback ไปเปิดผ่านเบราว์เซอร์แทนโดยอัตโนมัติ
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$destination'
      '&travelmode=driving',
    );

    try {
      final launched = await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('ไม่สามารถเปิด Google Maps ได้');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เปิด Google Maps ไม่สำเร็จ: $e')),
      );
    }
  }

  Future<void> _recenterToCurrentLocation() async {
    if (_currentLatLng == null) return;
    // จุดนี้ปลอดภัยอยู่แล้ว ไม่ต้องแก้ เพราะ user กดปุ่มนี้ได้ก็ต่อเมื่อ
    // แผนที่ build เสร็จและแสดงผลอยู่แล้วเท่านั้น
    _mapController.move(_currentLatLng!, 16.0);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // กำลังเช็ค GPS / ขอ permission / ดึงตำแหน่งครั้งแรก
    if (_isResolvingLocation) {
      return Scaffold(
        backgroundColor: backgroundDark,
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: accent),
              SizedBox(height: 16),
              Text('กำลังค้นหาตำแหน่งของคุณ...', style: TextStyle(color: subtextDark)),
            ],
          ),
        ),
      );
    }

    // เปิด GPS ไม่ได้ / โดนปฏิเสธ permission -> แสดงหน้าขอให้แก้ไขก่อน
    if (_locationError != null) {
      return Scaffold(
        backgroundColor: backgroundDark,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off_rounded, color: dangerRed, size: 56),
                const SizedBox(height: 16),
                Text(
                  _locationError!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: textDark, fontSize: 15),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _initLocationFlow,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('ลองอีกครั้ง'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final center = _currentLatLng!;

    return Scaffold(
      backgroundColor: backgroundDark,
      extendBody: true,
      body: Stack(
        children: [
          // --- 1. Real Map Layer ---
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              // 1.1 Tile Layer (OpenStreetMap Standard)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.savedriveai.app',
              ),

              // 1.2 Marker Layer
              MarkerLayer(
                markers: [
                  // ตำแหน่งปัจจุบัน (จาก GPS จริง)
                  Marker(
                    point: center,
                    width: 120,
                    height: 120,
                    child: _buildCurrentLocationPin(),
                  ),

                  // สถานที่ใกล้เคียงทั้งหมดที่ดึงมาจาก Overpass API
                  ..._nearbyPlaces.map(
                    (place) => Marker(
                      point: place.location,
                      width: 60,
                      height: 80,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () => _navigateTo(place),
                        child: _buildMapMarker(
                          icon: place.isGasStation
                              ? Icons.local_gas_station_rounded
                              : Icons.chair_rounded,
                          label: place.name,
                          isGas: place.isGasStation,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // 1.4 Attribution (เครดิต OSM - จำเป็นต้องมี)
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
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
                _buildFab(Icons.layers_rounded, onTap: () {}),
                const SizedBox(height: 12),
                _buildFab(Icons.my_location_rounded, onTap: _recenterToCurrentLocation),
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
                _isLoadingPlaces ? "กำลังค้นหาจุดพักรถ..." : "ค้นหาจุดพักรถ...",
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

  Widget _buildFab(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
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
          constraints: const BoxConstraints(maxWidth: 90),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
      constraints: const BoxConstraints(maxHeight: 320),
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
            child: Row(
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
          ),
          const SizedBox(height: 12),

          Flexible(
            child: _buildPlacesListContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesListContent() {
    if (_isLoadingPlaces) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: accent),
          ),
        ),
      );
    }

    if (_placesError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            Text(
              _placesError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: subtextDark, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                if (_currentLatLng != null) _fetchNearbyPlaces(_currentLatLng!);
              },
              child: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      );
    }

    if (_nearbyPlaces.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'ไม่พบปั๊มน้ำมันหรือจุดพักรถในระยะ 5 กม.',
          style: GoogleFonts.inter(color: subtextDark, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _nearbyPlaces.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final place = _nearbyPlaces[index];
        return _buildLocationCard(place);
      },
    );
  }

  Widget _buildLocationCard(NearbyPlace place) {
    final iconColor = place.isGasStation ? Colors.blue.shade400 : Colors.indigo.shade400;
    final iconBg = place.isGasStation
        ? Colors.blue.shade900.withOpacity(0.4)
        : Colors.indigo.shade900.withOpacity(0.4);

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
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    place.isGasStation ? Icons.local_gas_station_rounded : Icons.chair_rounded,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.near_me, size: 12, color: subtextDark),
                          const SizedBox(width: 4),
                          Text(
                            place.distanceLabel,
                            style: const TextStyle(
                              color: subtextDark,
                              fontSize: 12,
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
          const SizedBox(width: 8),

          // Right: Button
          GestureDetector(
            onTap: () => _navigateTo(place),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
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