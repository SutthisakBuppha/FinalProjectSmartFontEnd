import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

// --- External Packages ---
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart'; // ใช้เปิดแอป Google Maps เพื่อนำทางจริง
import 'package:permission_handler/permission_handler.dart';

// --- Internal Imports ---
import 'menu/custom_bottom_nav_bar.dart';
import 'main_layout.dart';
import '/services/api_service.dart';
import '/services/rest_mode_service.dart';
import '/services/trip_tracking_service.dart';

enum _PostNavigationAction { rest, continueTrip, finishTrip }

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

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // --- Theme Colors ---
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
  bool _navigationWasBackgrounded = false;
  bool _isStartingNavigation = false;
  bool _isShowingFinishDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _initLocationFlow(); // ← เริ่ม flow ทั้งหมดตั้งแต่เช็ค GPS จนถึงหาสถานที่ใกล้เคียง
    TripTrackingService.instance.restore().then((_) {
      if (mounted) setState(() {});
    });
    // 🔴 หมายเหตุ: ระบบ polling alert ถูกย้ายไปไว้ที่ main_layout.dart แล้ว
    // (ให้ทำงานได้ทุกหน้าในแอป ไม่ใช่แค่ตอนอยู่หน้า MapScreen เท่านั้น)
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        TripTrackingService.instance.isRestStopTracking) {
      _navigationWasBackgrounded = true;
      return;
    }

    if (state == AppLifecycleState.resumed &&
        _navigationWasBackgrounded &&
        TripTrackingService.instance.isRestStopTracking) {
      _navigationWasBackgrounded = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _askToFinishTrip();
      });
    }
  }

  Future<void> _askToFinishTrip() async {
    if (_isShowingFinishDialog ||
        !TripTrackingService.instance.isRestStopTracking) {
      return;
    }
    _isShowingFinishDialog = true;

    final action = await showDialog<_PostNavigationAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('คุณถึงจุดพักรถแล้วหรือยัง?'),
        content: Text(
          'กำลังบันทึกเส้นทางไปยัง '
          '${TripTrackingService.instance.destinationName ?? 'จุดหมาย'}\n'
          'ปุ่มจบด้านล่างจะจบเฉพาะเส้นทางไปจุดพัก ทริปหลักยังเดินทางต่อ',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              _PostNavigationAction.continueTrip,
            ),
            child: const Text('เดินทางต่อ'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              _PostNavigationAction.rest,
            ),
            child: const Text('เปิดโหมดพักรถ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              _PostNavigationAction.finishTrip,
            ),
            child: const Text('จบทริป'),
          ),
        ],
      ),
    );
    _isShowingFinishDialog = false;

    if (!mounted || action == null) return;
    if (action == _PostNavigationAction.continueTrip) return;

    if (action == _PostNavigationAction.rest) {
      final minutes = await _selectRestDuration();
      if (!mounted || minutes == null) return;
      try {
        await TripTrackingService.instance.finishRestStopTrip();
        await RestModeService.instance.activate(
          Duration(minutes: minutes),
          reason: 'break',
        );
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainLayout(initialIndex: 0)),
          (route) => false,
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เปิดโหมดพักรถไม่สำเร็จ: $error')),
        );
      }
      return;
    }

    try {
      final trip = await TripTrackingService.instance.finishRestStopTrip();
      if (!mounted) return;
      final distance =
          num.tryParse(trip?['distance']?.toString() ?? '')?.toDouble() ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'จบเฉพาะเส้นทางไปจุดพักแล้ว ระยะทาง ${distance.toStringAsFixed(2)} กม. ทริปหลักยังทำงานอยู่',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('จบทริปไม่สำเร็จ กรุณาลองใหม่: $error')),
      );
    }
  }

  Future<int?> _selectRestDuration() {
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'เลือกระยะเวลาพักรถ',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              for (final minutes in const [5, 10, 15])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(minutes),
                    child: Text('พัก $minutes นาที'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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

  // 🆕 เปลี่ยนจากยิง Overpass API ตรงๆ จากมือถือ มาเรียกผ่าน backend
  // (Laravel: NearbyPlacesController) แทน เพราะ:
  //   - overpass-api.de เป็นเซิร์ฟเวอร์สาธารณะที่คนใช้ทั่วโลก มักตอบ 504
  //     บ่อยเวลาโหลดหนัก การยิงตรงจาก client จึงไม่เสถียร
  //   - ฝั่ง backend ทำ retry ข้ามหลาย mirror + แคชผลลัพธ์ไว้ได้
  //     (ปั๊ม/จุดพักรถไม่ค่อยเปลี่ยนตำแหน่ง) ลดโอกาสเจอ error แบบนี้ได้มาก
  //   - ระยะทางถูกคำนวณและเรียงลำดับมาจาก backend แล้ว ไม่ต้องคำนวณซ้ำที่นี่
  Future<void> _fetchNearbyPlaces(LatLng center, {double radiusMeters = 5000}) async {
    setState(() {
      _isLoadingPlaces = true;
      _placesError = null;
    });

    try {
      final results = await ApiService.instance.nearbyPlaces(
        latitude: center.latitude,
        longitude: center.longitude,
        radiusMeters: radiusMeters,
      );

      final places = results.map((item) {
        final lat = (item['latitude'] as num).toDouble();
        final lng = (item['longitude'] as num).toDouble();

        return NearbyPlace(
          id: item['id'].toString(),
          name: item['name'] as String? ?? 'จุดพักรถ',
          location: LatLng(lat, lng),
          isGasStation: item['is_gas_station'] == true,
          // backend คำนวณระยะทางมาให้แล้ว ถ้าไม่มีค่อยคำนวณสำรองที่นี่
          distanceMeters: (item['distance_meters'] as num?)?.toDouble() ??
              Geolocator.distanceBetween(
                center.latitude,
                center.longitude,
                lat,
                lng,
              ),
        );
      }).toList();

      // backend เรียงลำดับใกล้สุดก่อนมาให้แล้ว แต่ sort ซ้ำไว้เผื่อกันเหนียว
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
    if (_isStartingNavigation) return;
    _isStartingNavigation = true;
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
      final initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!TripTrackingService.instance.isTracking) {
        if (Theme.of(context).platform == TargetPlatform.android) {
          final backgroundStatus = await Permission.locationAlways.status;
          if (!backgroundStatus.isGranted) {
            await Permission.locationAlways.request();
          }
        }

        await TripTrackingService.instance.start(
          initialPosition: initialPosition,
          destinationName: place.name,
        );
        if (mounted) setState(() {});
      }

      await TripTrackingService.instance.startRestStopTrip(
        initialPosition: initialPosition,
        destinationName: place.name,
      );
      final launched = await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await TripTrackingService.instance.finishRestStopTrip();
        throw Exception('ไม่สามารถเปิด Google Maps ได้');
      }
    } catch (e) {
      await TripTrackingService.instance.endRestStopNavigation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เปิด Google Maps ไม่สำเร็จ: $e')),
      );
    } finally {
      _isStartingNavigation = false;
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
        backgroundColor: Colors.grey.shade100,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.secondary),
              const SizedBox(height: 16),
              Text(
                'กำลังค้นหาตำแหน่งของคุณ...',
                style: GoogleFonts.prompt(color: AppColors.cFF1E293B, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    // เปิด GPS ไม่ได้ / โดนปฏิเสธ permission -> แสดงหน้าขอให้แก้ไขก่อน
    if (_locationError != null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade100,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_off_rounded, color: AppColors.cFFDC2626, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    _locationError!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.prompt(color: AppColors.cFF1E293B, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _initLocationFlow,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('ลองอีกครั้ง'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final center = _currentLatLng!;

    return Scaffold(
      backgroundColor: AppColors.text,
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

          if (TripTrackingService.instance.isRestStopTracking)
            Positioned(
              top: 120,
              left: 16,
              child: FilledButton.icon(
                onPressed: _askToFinishTrip,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.cFFDC2626,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('จบเส้นทางไปจุดพัก'),
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
      child: Row(
        children: [
          // ปุ่มปิด/กลับ ทรงกลมขาว ตามดีไซน์ใหม่ (มุมบนซ้าย)
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.close_rounded, color: AppColors.cFF1E293B, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          // แถบค้นหาแบบเรียบ พื้นขาว ตามโทนดีไซน์ใหม่
          Expanded(
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.cFF94A3B8, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isLoadingPlaces ? "กำลังค้นหาจุดพักรถ..." : "ค้นหาจุดพักรถ...",
                      style: GoogleFonts.prompt(
                        color: AppColors.cFF94A3B8,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Icon(Icons.mic, color: AppColors.cFF94A3B8, size: 20),
                ],
              ),
            ),
          ),
        ],
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
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: AppColors.cFF1E293B, size: 22),
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
                color: AppColors.secondary.withOpacity(0.25 * (1 - _pulseController.value)),
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
            color: AppColors.secondary.withOpacity(0.3),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withOpacity(0.6),
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
            border: Border.all(color: AppColors.secondary, width: 3),
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
            border: Border.all(color: AppColors.cFF0F2647, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.cFF0F2647, size: 20),
        ),
        // Arrow (Triangle)
        Transform.translate(
          offset: const Offset(0, -1),
          child: ClipPath(
            clipper: TriangleClipper(),
            child: Container(width: 12, height: 8, color: AppColors.cFF0F2647),
          ),
        ),
        const SizedBox(height: 4),
        // Label
        Container(
          constraints: const BoxConstraints(maxWidth: 90),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.cFF0F2647,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.prompt(
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
      constraints: const BoxConstraints(maxHeight: 340),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
          bottom: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
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
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "สถานที่ใกล้เคียง",
                  style: GoogleFonts.prompt(
                    color: AppColors.cFF1E293B,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "ในระยะ 5 กม.",
                  style: GoogleFonts.prompt(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w500),
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
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary),
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
              style: GoogleFonts.prompt(color: Colors.grey.shade500, fontSize: 12),
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
          style: GoogleFonts.prompt(color: Colors.grey.shade500, fontSize: 13),
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
    final iconColor = place.isGasStation ? AppColors.secondary : Colors.indigo.shade400;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ระยะทาง (มุมซ้าย เหมือนเวลาใน RouteDetails ของดีไซน์ใหม่)
          SizedBox(
            width: 40,
            child: Text(
              place.distanceLabel,
              style: GoogleFonts.prompt(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade400,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Timeline dot
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 12),
          // Icon + ชื่อสถานที่
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    place.isGasStation ? Icons.local_gas_station_rounded : Icons.chair_rounded,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    place.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.prompt(
                      color: AppColors.cFF1E293B,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ปุ่มนำทาง สไตล์ปุ่ม action หลักของดีไซน์ใหม่ (พื้นน้ำเงิน)
          GestureDetector(
            onTap: () => _navigateTo(place),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.secondary,
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
