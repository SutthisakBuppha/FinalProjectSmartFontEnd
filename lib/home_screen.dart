import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

// Import ส่วนประกอบต่างๆ ของแอปพลิเคชันคุณ
import '/services/api_service.dart';
import 'utils/device_status.dart';
import '/services/rest_mode_service.dart';
import '/services/trip_tracking_service.dart';
import 'main_layout.dart';

void main() {
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: HomeScreen()),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isMonitoring = false;
  bool _isStartingTrip = false;
  bool _isEndingTrip = false;

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
  bool _isWakeUpDialogVisible = false;

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
    _restoreTripAndCheckDevice();
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
    RestModeService.instance.wakeUpAlarmActive.addListener(
      _onWakeUpAlarmChanged,
    );
  }

  Future<void> _restoreTripAndCheckDevice() async {
    await TripTrackingService.instance.restore();
    if (mounted) setState(() {});
    await _checkDeviceStatus();
  }

  void _onRestModeChanged() {
    if (mounted) setState(() {});
    _syncRestCountdownTicker();
  }

  void _onWakeUpAlarmChanged() {
    if (!mounted ||
        !RestModeService.instance.wakeUpAlarmActive.value ||
        _isWakeUpDialogVisible) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showWakeUpAlarmDialog();
    });
  }

  Future<void> _showWakeUpAlarmDialog() async {
    if (_isWakeUpDialogVisible ||
        !RestModeService.instance.wakeUpAlarmActive.value) {
      return;
    }
    _isWakeUpDialogVisible = true;
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    try {
      await showDialog<void>(
        context: rootNavigator.context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: const Icon(
            Icons.alarm_rounded,
            color: AppColors.primary,
            size: 48,
          ),
          title: Text(
            'หมดเวลาพักรถแล้ว',
            textAlign: TextAlign.center,
            style: GoogleFonts.prompt(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'ถึงเวลากลับมาเดินทางต่อ กดปุ่มด้านล่างเพื่อปิดเสียงปลุก',
            textAlign: TextAlign.center,
            style: GoogleFonts.prompt(),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext, rootNavigator: true).pop();
                await RestModeService.instance.stopWakeUpAlarm();
              },
              icon: const Icon(Icons.volume_off_rounded),
              label: Text(
                'ปิดเสียงปลุก',
                style: GoogleFonts.prompt(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    } finally {
      _isWakeUpDialogVisible = false;
    }
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
    RestModeService.instance.wakeUpAlarmActive.removeListener(
      _onWakeUpAlarmChanged,
    );
    _controller.dispose();
    super.dispose();
  }

  // 🔌 ตรวจสอบสถานะไฟเลี้ยงของอุปกรณ์ (heartbeat จาก backend) แล้ว sync ปุ่มตรวจจับให้ตรงกันอัตโนมัติ
  Future<void> _checkDeviceStatus() async {
    if (_isCheckingDeviceStatus) return;
    _isCheckingDeviceStatus = true;

    try {
      final devices = await ApiService.instance.devices();
      final bool isAnyDeviceOnline = devices.any(isDeviceOnline);

      if (!mounted) return;

      if (isAnyDeviceOnline != _isMonitoring) {
        _setMonitoring(isAnyDeviceOnline);
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

  Future<void> _startTrip() async {
    if (_isStartingTrip || TripTrackingService.instance.isTracking) return;
    _isStartingTrip = true;
    if (mounted) setState(() {});
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await TripTrackingService.instance.start(
        initialPosition: position,
        destinationName: 'การเดินทางปัจจุบัน',
      );
      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('Trip start failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เริ่มบันทึกทริปไม่สำเร็จ: $error')),
        );
      }
    } finally {
      _isStartingTrip = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _handleTripButton() async {
    if (_isStartingTrip || _isEndingTrip) return;

    if (!TripTrackingService.instance.isTracking) {
      await _startTrip();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ยืนยันจบทริป'),
        content: const Text(
          'ระบบจะหยุดบันทึกตำแหน่งและสรุประยะทางของทริปนี้ลงใน History',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('เดินทางต่อ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ยืนยันจบทริป'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _isEndingTrip = true;
    setState(() {});
    try {
      final trip = await TripTrackingService.instance.finish();
      if (!mounted) return;
      final distance =
          num.tryParse(trip?['distance']?.toString() ?? '')?.toDouble() ?? 0;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'จบทริปและบันทึกลง History แล้ว ระยะทาง ${distance.toStringAsFixed(2)} กม.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('จบทริปไม่สำเร็จ: $error')),
        );
      }
    } finally {
      _isEndingTrip = false;
      if (mounted) setState(() {});
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // โหมดพักรถ: เปิด bottom sheet ให้เลือกระยะเวลา แล้วสั่ง activate
  // ─────────────────────────────────────────────────────────────────────
  String _restReasonLabel(String? reason) {
    if (reason == null || reason.isEmpty) return '';
    if (reason.startsWith('other:')) {
      return reason.substring('other:'.length).trim();
    }
    return const {
          'sleep': 'นอนพักในรถ',
          'break': 'จอดพักผ่อน',
          'pickup': 'หยิบของหรือทำธุระ',
          'temporary': 'จอดรถชั่วคราว',
        }[reason] ??
        reason;
  }

  String _formatRestChoice(int minutes) {
    if (minutes >= 60 && minutes % 60 == 0) {
      return '${minutes ~/ 60} ชั่วโมง';
    }
    return '$minutes นาที';
  }

  Future<Map<String, dynamic>?> _showCustomRestDialog() async {
    final reasonController = TextEditingController();
    final durationController = TextEditingController();
    String unit = 'minutes';
    String? errorText;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('กำหนดเหตุผลและเวลา', style: GoogleFonts.prompt(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: reasonController,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'เหตุผลที่พักรถ',
                    hintText: 'เช่น รอรับผู้โดยสาร',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: durationController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'ระยะเวลา',
                          errorText: errorText,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 115,
                      child: DropdownButtonFormField<String>(
                        value: unit,
                        decoration: const InputDecoration(labelText: 'หน่วย', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'minutes', child: Text('นาที')),
                          DropdownMenuItem(value: 'hours', child: Text('ชั่วโมง')),
                        ],
                        onChanged: (value) {
                          if (value != null) setDialogState(() => unit = value);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('ยกเลิก')),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(durationController.text.trim());
                final minutes = value == null ? null : (unit == 'hours' ? value * 60 : value);
                if (reasonController.text.trim().isEmpty || minutes == null || minutes < 1 || minutes > 480) {
                  setDialogState(() => errorText = 'กำหนดเวลา 1–480 นาที (สูงสุด 8 ชั่วโมง)');
                  return;
                }
                Navigator.pop(dialogContext, {
                  'reason': 'other:${reasonController.text.trim()}',
                  'minutes': minutes,
                });
              },
              child: const Text('เปิดโหมดพักรถ'),
            ),
          ],
        ),
      ),
    );
    reasonController.dispose();
    durationController.dispose();
    return result;
  }

  Future<void> _showRestModeSheet() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(
          'เลือกเหตุผลที่พักรถ',
          style: GoogleFonts.prompt(fontWeight: FontWeight.bold),
        ),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, 'sleep'), child: const Text('นอนพักในรถ')),
          SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, 'break'), child: const Text('จอดพักผ่อน')),
          SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, 'pickup'), child: const Text('หยิบของหรือทำธุระ')),
          SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, 'temporary'), child: const Text('จอดรถชั่วคราว')),
          SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, 'other'), child: const Text('เหตุผลอื่น')),
        ],
      ),
    );
    if (reason == null || !mounted) return;

    var activationReason = reason;
    int? customMinutes;
    if (reason == 'other') {
      final custom = await _showCustomRestDialog();
      if (custom == null || !mounted) return;
      activationReason = custom['reason'] as String;
      customMinutes = custom['minutes'] as int;
    }

    final durationOptions = <String, List<int>>{
      'temporary': [5, 10, 15],
      'pickup': [5, 10, 20],
      'break': [15, 30, 60],
      'sleep': [60, 120, 180],
    };

    final selected = customMinutes ?? await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final screenHeight = MediaQuery.sizeOf(sheetContext).height;

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
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
                        child: const Icon(
                          Icons.bedtime_rounded,
                          color: AppColors.cFF0F2557,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "เปิดโหมดพักรถ",
                              style: GoogleFonts.prompt(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.cFF1E293B,
                              ),
                            ),
                            Text(
                              "ระบบจะไม่แจ้งเตือนชั่วคราวตามเวลาที่เลือก",
                              style: GoogleFonts.prompt(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...(durationOptions[reason] ?? [10, 15, 30]).map(
                    (minutes) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.pop(sheetContext, minutes),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 11,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cFFECF0F3,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 20,
                                color: AppColors.cFF1E293B.withOpacity(0.7),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _formatRestChoice(minutes),
                                style: GoogleFonts.prompt(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.cFF1E293B,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.cFFFFF7ED,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AppColors.cFF9A3412,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "AI จะหยุดสั่ง Buzzer และไม่บันทึกเหตุการณ์ใหม่จนกว่าโหมดพักจะสิ้นสุด",
                            softWrap: true,
                            style: GoogleFonts.prompt(
                              fontSize: 11,
                              color: AppColors.cFF9A3412,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected != null) {
      try {
        await RestModeService.instance.activate(
          Duration(minutes: selected),
          reason: activationReason,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("เปิดโหมดพักรถแล้ว $selected นาที")),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เปิดโหมดพักรถไม่สำเร็จ: $e')),
        );
      }
    }
  }

  Future<void> _cancelRestMode() async {
    try {
      await RestModeService.instance.cancel();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("ยกเลิกโหมดพักรถแล้ว กลับมาแจ้งเตือนตามปกติ"),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ยกเลิกโหมดพักรถไม่สำเร็จ: $e')),
      );
    }
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
    final screenHeight = mediaQuery.size.height;
    final isCompact = screenHeight < 760;
    final heightScale = (screenHeight / 850).clamp(0.72, 1.0);
    final scale = isLandscape ? 0.72 : heightScale;
    final statusColor = _isMonitoring ? AppColors.cFF059669 : Colors.grey;
    final bool isResting = RestModeService.instance.isActive;

    return Scaffold(
      backgroundColor: AppColors.cFFECF0F3,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, isCompact ? 8 : 14, 20, 0),
                child: _buildHeader(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, isCompact ? 12 : 22, 20, 0),
                child: _buildStatusCard(scale, statusColor),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, isCompact ? 10 : 16, 20, 0),
                child: _buildInfoRow(statusColor),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, isCompact ? 8 : 12, 20, 0),
                child: _buildRestModeCard(isResting),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  isCompact ? 10 : 18,
                  20,
                  isCompact ? 8 : 16,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildTripButton(scale),
                    const SizedBox(height: 10),
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
              style: GoogleFonts.prompt(
                color: AppColors.cFF1E293B.withOpacity(0.55),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "ผู้ขับขี่ปลอดภัย",
              style: GoogleFonts.prompt(
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
            child: const Icon(
              Icons.person_pin,
              size: 28,
              color: AppColors.cFF0F2557,
            ),
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
            color:
                (_isMonitoring || isResting
                        ? AppColors.cFF0F2557
                        : Colors.black)
                    .withOpacity(0.12),
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
                        width:
                            (140 * scale) * (0.75 + 0.25 * _controller.value),
                        height:
                            (140 * scale) * (0.75 + 0.25 * _controller.value),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(
                            0.15 * (1 - _controller.value),
                          ),
                        ),
                      ),
                    Container(
                      width: 96 * scale,
                      height: 96 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_isMonitoring || isResting)
                            ? Colors.white.withOpacity(0.15)
                            : AppColors.cFFECF0F3,
                      ),
                      child: Icon(
                        isResting
                            ? Icons.bedtime_rounded
                            : (_isMonitoring
                                  ? Icons.security_rounded
                                  : Icons.shield_moon_rounded),
                        size: 48 * scale,
                        color: (_isMonitoring || isResting)
                            ? Colors.white
                            : Colors.grey,
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
                : (_isMonitoring
                      ? "ระบบ AI กำลังคุ้มครองคุณ"
                      : "ระบบปิดการทำงานอยู่"),
            textAlign: TextAlign.center,
            style: GoogleFonts.prompt(
              color: (_isMonitoring || isResting)
                  ? Colors.white
                  : AppColors.cFF1E293B,
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
            style: GoogleFonts.prompt(
              color: (_isMonitoring || isResting)
                  ? Colors.white.withOpacity(0.8)
                  : Colors.grey[600],
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
                  style: GoogleFonts.prompt(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.prompt(
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
              color: (isResting ? AppColors.cFF6B7280 : AppColors.cFF0F2557)
                  .withOpacity(0.1),
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
                  style: GoogleFonts.prompt(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cFF1E293B,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isResting
                      ? "${_restReasonLabel(RestModeService.instance.restReason.value)} • เหลือ ${_formatRemaining(RestModeService.instance.remaining)}"
                      : "จอดพัก/นอน/หยิบของ? กดเปิดเพื่อไม่ให้ระบบรบกวน",
                  style: GoogleFonts.prompt(
                    fontSize: 11.5,
                    color: Colors.grey[500],
                  ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                "ยกเลิก",
                style: GoogleFonts.prompt(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: _showRestModeSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cFF0F2557,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                "เปิด",
                style: GoogleFonts.prompt(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- Control Button ----------
  Widget _buildTripButton(double scale) {
    final hasActiveTrip = TripTrackingService.instance.isTracking;
    return Container(
      width: double.infinity,
      height: (64 * scale).clamp(56.0, 72.0),
      decoration: BoxDecoration(
        color: hasActiveTrip ? AppColors.cFFFF4D4D : AppColors.cFF059669,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: (hasActiveTrip ? Colors.red : AppColors.cFF059669)
                .withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTripButton,
          borderRadius: BorderRadius.circular(22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                TripTrackingService.instance.isTracking
                    ? Icons.stop_circle_rounded
                    : Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 28 * scale,
              ),
              const SizedBox(width: 10),
              Text(
                _isEndingTrip
                    ? "กำลังจบทริป..."
                    : _isStartingTrip
                    ? "กำลังเริ่มทริป..."
                    : TripTrackingService.instance.isTracking
                    ? "จบทริป"
                    : "เริ่มทริป",
                style: GoogleFonts.prompt(
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

  Widget _buildControlButton(double scale) {
    return Container(
      width: double.infinity,
      height: (64 * scale).clamp(56.0, 72.0),
      decoration: BoxDecoration(
        color: _isMonitoring ? AppColors.cFFFF4D4D : AppColors.cFF059669,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: (_isMonitoring ? Colors.red : AppColors.cFF059669)
                .withOpacity(0.28),
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
                _isMonitoring
                    ? Icons.stop_circle_rounded
                    : Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 28 * scale,
              ),
              const SizedBox(width: 10),
              Text(
                _isMonitoring ? "หยุดการตรวจจับ" : "เริ่มตรวจจับ",
                style: GoogleFonts.prompt(
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
