import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

// Import ส่วนประกอบต่างๆ ของแอปพลิเคชันคุณ
import '/services/api_service.dart';
import '/services/rest_mode_service.dart';
import 'main_layout.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HomeScreen(),
  ));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isMonitoring = false;

  // Polling สถานะไฟเลี้ยงของอุปกรณ์ (ออนไลน์/ออฟไลน์) เพื่อเริ่ม/หยุดการตรวจจับอัตโนมัติ
  Timer? _deviceStatusTimer;
  bool _isCheckingDeviceStatus = false;
  static const Duration _deviceStatusPollInterval = Duration(seconds: 5);

  // ─────────────────────────────────────────────────────────────────────
  // โหมดพักรถ (Rest Mode): ตัวนับถอยหลังสำหรับอัปเดต UI ทุกวินาที
  // (RestModeService เก็บสถานะจริงไว้ แต่ ValueNotifier จะไม่ tick เองทุกวิ
  // จึงต้องมี Timer ท้องถิ่นของหน้านี้ไว้ refresh ข้อความนับถอยหลังเฉยๆ)
  // ─────────────────────────────────────────────────────────────────────
  Timer? _restCountdownTicker;

  // ---------------------------------------------------------------------
  // หมายเหตุ: ลอจิกทั้งหมดด้านล่างนี้ "ไม่ถูกแก้ไข" ตามที่ขอ (คงความสามารถเดิม)
  // ที่เปลี่ยนคือเฉพาะส่วน UI (build methods) เท่านั้น โดยยังใช้ชุดสี
  // จาก AppColors เดิมทั้งหมด
  // ---------------------------------------------------------------------
  @override
  void initState() {
    super.initState();

    // 🆕 จำไว้ว่าผู้ใช้อยู่หน้านี้ล่าสุด เพื่อให้ SplashScreen พาไปหน้าเดิม
    // ตอน refresh (เว็บ) หรือปิด-เปิดแอปใหม่ (มือถือ)
    ApiService.instance.saveLastRoute('home');

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // เริ่ม polling สถานะอุปกรณ์ทันที: พอจ่ายไฟ (ออนไลน์) ให้เริ่มตรวจจับเอง
    // พอถอดไฟ/บอร์ดขาดการเชื่อมต่อ (ออฟไลน์) ให้หยุดตรวจจับเองเช่นกัน
    _checkDeviceStatus();
    _deviceStatusTimer = Timer.periodic(_deviceStatusPollInterval, (_) {
      _checkDeviceStatus();
    });

    // โหลดสถานะโหมดพักรถที่เคย persist ไว้ (เผื่อผู้ใช้ปิด-เปิดแอประหว่างพัก)
    RestModeService.instance.ensureInitialized().then((_) {
      if (mounted) setState(() {});
      _syncRestCountdownTicker();
    });

    // อัปเดต UI ทุกครั้งที่สถานะโหมดพักรถเปลี่ยน (เปิด/ยกเลิก/หมดอายุเอง)
    RestModeService.instance.restUntil.addListener(_onRestModeChanged);
  }

  void _onRestModeChanged() {
    if (mounted) setState(() {});
    _syncRestCountdownTicker();
  }

  // เปิด/ปิด ticker นับถอยหลังให้ตรงกับสถานะโหมดพักรถปัจจุบัน
  void _syncRestCountdownTicker() {
    _restCountdownTicker?.cancel();
    if (RestModeService.instance.isActive) {
      _restCountdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (!RestModeService.instance.isActive) {
          _restCountdownTicker?.cancel();
        }
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _deviceStatusTimer?.cancel();
    _restCountdownTicker?.cancel();
    RestModeService.instance.restUntil.removeListener(_onRestModeChanged);
    _controller.dispose();
    super.dispose();
  }

  // 🔌 ตรวจสอบสถานะไฟเลี้ยงของอุปกรณ์ (heartbeat จาก backend) แล้ว sync ปุ่มตรวจจับให้ตรงกันอัตโนมัติ
  Future<void> _checkDeviceStatus() async {
    if (_isCheckingDeviceStatus) return;
    _isCheckingDeviceStatus = true;

    try {
      final devices = await ApiService.instance.devices();
      final bool isDeviceOnline = devices.any(
        (d) => d['status'] == 'ออนไลน์' || d['status'] == 'online',
      );

      if (!mounted) return;

      if (isDeviceOnline != _isMonitoring) {
        _setMonitoring(isDeviceOnline);
      }
    } catch (e) {
      debugPrint("Device status poll error: $e");
    } finally {
      _isCheckingDeviceStatus = false;
    }
  }

  void _setMonitoring(bool shouldMonitor) {
    if (!mounted) return;
    setState(() {
      _isMonitoring = shouldMonitor;
      if (_isMonitoring) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    });
  }

  void _toggleMonitoring() {
    _setMonitoring(!_isMonitoring);
  }

  // ─────────────────────────────────────────────────────────────────────
  // โหมดพักรถ: เปิด bottom sheet ให้เลือกระยะเวลา แล้วสั่ง activate
  // ─────────────────────────────────────────────────────────────────────
  Future<void> _showRestModeSheet() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.cFF0F2557.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.bedtime_rounded, color: AppColors.cFF0F2557),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "เปิดโหมดพักรถ",
                          style: GoogleFonts.kanit(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.cFF1E293B),
                        ),
                        Text(
                          "ระบบจะไม่แจ้งเตือนชั่วคราวตามเวลาที่เลือก",
                          style: GoogleFonts.kanit(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...[10, 15, 30, 60].map((minutes) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(sheetContext, minutes),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.cFFECF0F3,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.timer_outlined, size: 20, color: AppColors.cFF1E293B.withOpacity(0.7)),
                            const SizedBox(width: 12),
                            Text(
                              minutes < 60 ? "$minutes นาที" : "1 ชั่วโมง",
                              style: GoogleFonts.kanit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.cFF1E293B),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cFFFFF7ED,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.cFF9A3412),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "ระบบยังคงเก็บบันทึกเหตุการณ์ตามปกติ เพียงแต่จะไม่ส่งเสียง/แจ้งเตือนรบกวนในช่วงเวลานี้",
                        style: GoogleFonts.kanit(fontSize: 11.5, color: AppColors.cFF9A3412, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      await RestModeService.instance.activate(Duration(minutes: selected));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("เปิดโหมดพักรถแล้ว $selected นาที")),
      );
    }
  }

  Future<void> _cancelRestMode() async {
    await RestModeService.instance.cancel();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("ยกเลิกโหมดพักรถแล้ว กลับมาแจ้งเตือนตามปกติ")),
    );
  }

  String _formatRemaining(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return "${d.inHours}:$m:$s";
    }
    return "$m:$s";
  }

  // =======================================================================
  // UI ด้านล่างนี้คือส่วนที่ออกแบบใหม่ทั้งหมด — ใช้เฉพาะสีจาก AppColors เดิม
  // =======================================================================

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final scale = isLandscape ? 0.85 : 1.0;
    final statusColor = _isMonitoring ? AppColors.cFF059669 : Colors.grey;
    final bool isResting = RestModeService.instance.isActive;

    return Scaffold(
      backgroundColor: AppColors.cFFECF0F3,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _buildHeader(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: _buildStatusCard(scale, statusColor),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _buildInfoRow(statusColor),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _buildRestModeCard(isResting),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildControlButton(scale),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Header ----------
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "ยินดีต้อนรับกลับมา",
              style: GoogleFonts.kanit(
                color: AppColors.cFF1E293B.withOpacity(0.55),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "ผู้ขับขี่ปลอดภัย",
              style: GoogleFonts.kanit(
                color: AppColors.cFF1E293B,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: () {
            // ⚠️ เดิม push ProfileScreen() เดี่ยวๆ ทำให้หลุดออกจาก MainLayout
            // (ไม่มีเมนูด้านล่างให้กด) แก้เป็นสลับไป tab โปรไฟล์ (index 5)
            // ภายใน MainLayout แทน เพื่อให้เมนูด้านล่างยังอยู่ครบ
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const MainLayout(initialIndex: 5),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.person_pin, size: 28, color: AppColors.cFF0F2557),
          ),
        ),
      ],
    );
  }

  // ---------- Status Card ----------
  Widget _buildStatusCard(double scale, Color statusColor) {
    final bool isResting = RestModeService.instance.isActive;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 36 * scale, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isResting
              ? [AppColors.cFF6B7280, AppColors.cFF6B7280.withOpacity(0.85)]
              : _isMonitoring
                  ? [AppColors.cFF0F2557, AppColors.cFF0F2557.withOpacity(0.85)]
                  : [Colors.white, Colors.white],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (_isMonitoring || isResting ? AppColors.cFF0F2557 : Colors.black).withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 140 * scale,
            height: 140 * scale,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isMonitoring && !isResting)
                      Container(
                        width: (140 * scale) * (0.75 + 0.25 * _controller.value),
                        height: (140 * scale) * (0.75 + 0.25 * _controller.value),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15 * (1 - _controller.value)),
                        ),
                      ),
                    Container(
                      width: 96 * scale,
                      height: 96 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_isMonitoring || isResting) ? Colors.white.withOpacity(0.15) : AppColors.cFFECF0F3,
                      ),
                      child: Icon(
                        isResting
                            ? Icons.bedtime_rounded
                            : (_isMonitoring ? Icons.security_rounded : Icons.shield_moon_rounded),
                        size: 48 * scale,
                        color: (_isMonitoring || isResting) ? Colors.white : Colors.grey,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: 20 * scale),
          Text(
            isResting
                ? "กำลังอยู่ในโหมดพักรถ"
                : (_isMonitoring ? "ระบบ AI กำลังคุ้มครองคุณ" : "ระบบปิดการทำงานอยู่"),
            textAlign: TextAlign.center,
            style: GoogleFonts.kanit(
              color: (_isMonitoring || isResting) ? Colors.white : AppColors.cFF1E293B,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isResting
                ? "ระงับการแจ้งเตือนชั่วคราว เหลือเวลา ${_formatRemaining(RestModeService.instance.remaining)}"
                : (_isMonitoring
                    ? "กำลังตรวจสอบพฤติกรรมการขับขี่แบบเรียลไทม์..."
                    : "ระบบจะเริ่มทำงานอัตโนมัติเมื่อจ่ายไฟเข้าอุปกรณ์"),
            textAlign: TextAlign.center,
            style: GoogleFonts.kanit(
              color: (_isMonitoring || isResting) ? Colors.white.withOpacity(0.8) : Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Info Row (สถานะย่อย) ----------
  Widget _buildInfoRow(Color statusColor) {
    return Row(
      children: [
        Expanded(
          child: _infoChip(
            icon: Icons.bolt_rounded,
            label: "สถานะไฟเลี้ยง",
            value: _isMonitoring ? "ออนไลน์" : "ออฟไลน์",
            color: statusColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _infoChip(
            icon: Icons.wifi_tethering_rounded,
            label: "การเชื่อมต่อ",
            value: _isCheckingDeviceStatus ? "กำลังตรวจสอบ" : "ปกติ",
            color: AppColors.cFF0F2557,
          ),
        ),
      ],
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.kanit(fontSize: 11, color: Colors.grey[500]),
                ),
                Text(
                  value,
                  style: GoogleFonts.kanit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cFF1E293B,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Rest Mode Card (ใหม่) ----------
  // การ์ดสำหรับเปิด/ยกเลิกโหมดพักรถ: ใช้เมื่อจอดรถนอนพัก/พักผ่อน/หยิบของ
  // โดยติดเครื่องยนต์ทิ้งไว้ เพื่อไม่ให้ระบบแจ้งเตือนรบกวนโดยไม่จำเป็น
  Widget _buildRestModeCard(bool isResting) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isResting ? AppColors.cFF6B7280 : AppColors.cFF0F2557).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.bedtime_rounded,
              size: 22,
              color: isResting ? AppColors.cFF6B7280 : AppColors.cFF0F2557,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "โหมดพักรถ",
                  style: GoogleFonts.kanit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cFF1E293B,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isResting
                      ? "ระงับแจ้งเตือนอีก ${_formatRemaining(RestModeService.instance.remaining)}"
                      : "จอดพัก/นอน/หยิบของ? กดเปิดเพื่อไม่ให้ระบบรบกวน",
                  style: GoogleFonts.kanit(fontSize: 11.5, color: Colors.grey[500]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isResting)
            TextButton(
              onPressed: _cancelRestMode,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.cFFFEF2F2,
                foregroundColor: Colors.red.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text("ยกเลิก", style: GoogleFonts.kanit(fontSize: 12.5, fontWeight: FontWeight.bold)),
            )
          else
            ElevatedButton(
              onPressed: _showRestModeSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cFF0F2557,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text("เปิด", style: GoogleFonts.kanit(fontSize: 12.5, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // ---------- Control Button ----------
  Widget _buildControlButton(double scale) {
    return Container(
      width: double.infinity,
      height: (64 * scale).clamp(56.0, 72.0),
      decoration: BoxDecoration(
        color: _isMonitoring ? AppColors.cFFFF4D4D : AppColors.cFF059669,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: (_isMonitoring ? Colors.red : AppColors.cFF059669).withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleMonitoring,
          borderRadius: BorderRadius.circular(22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isMonitoring ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 28 * scale,
              ),
              const SizedBox(width: 10),
              Text(
                _isMonitoring ? "หยุดการตรวจจับ" : "เริ่มตรวจจับ",
                style: GoogleFonts.kanit(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}