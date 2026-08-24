import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_theme.dart';
import 'main_layout.dart';
import 'device_setting.dart';
import 'device_registration_screen.dart';
import '/services/api_service.dart';
import 'utils/device_status.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key, this.onDevicesEmpty});

  final VoidCallback? onDevicesEmpty;

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  List<Map<String, dynamic>> _deviceList = [];
  bool _isLoading = true;
  String? _deletingDeviceId;
  Timer? _pollTimer;

  // ตัวกรองสถานะอุปกรณ์ (ทั้งหมด / ออนไลน์ / ออฟไลน์)
  String _selectedFilter = 'ทั้งหมด';

  // ระยะเวลาที่จะ auto-refresh สถานะอุปกรณ์
  static const Duration _pollInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      _loadDevices(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDevices({bool silent = false}) async {
    try {
      final list = await ApiService.instance.devices();

      if (!mounted) return;

      if (list.isEmpty) {
        setState(() {
          _deviceList = [];
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _deviceList = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent) {
        debugPrint("Silent poll โหลดข้อมูลอุปกรณ์ล้มเหลว: $e");
        return;
      }
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("โหลดข้อมูลอุปกรณ์ล้มเหลว: $e")));
    }
  }

  // Helper ตรวจสอบสถานะออนไลน์
  bool _isOnline(Map<String, dynamic> device) {
    return isDeviceOnline(device);
  }

  Future<void> _confirmRemoveDevice(Map<String, dynamic> device) async {
    final deviceId = device['device_id']?.toString();
    if (deviceId == null || deviceId.isEmpty) return;

    final deviceName = device['device_name']?.toString() ?? 'อุปกรณ์นี้';
    final ipAddress = device['ip_address']?.toString().trim() ?? '';
    final canResetWifi = !kIsWeb && _isOnline(device) && ipAddress.isNotEmpty;
    var resetWifi = false;

    final resetWifiRequested = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('ลบอุปกรณ์'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ต้องการลบ “$deviceName” ออกจากบัญชีหรือไม่?'),
              const SizedBox(height: 14),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: resetWifi,
                onChanged: canResetWifi
                    ? (value) =>
                          setDialogState(() => resetWifi = value ?? false)
                    : null,
                title: const Text('ล้างการตั้งค่า Wi-Fi ของอุปกรณ์ด้วย'),
                subtitle: Text(
                  canResetWifi
                      ? 'บอร์ดจะรีสตาร์ตและเข้าสู่โหมดเชื่อมต่อผ่าน BLE'
                      : kIsWeb
                      ? 'คำสั่งล้าง Wi-Fi ใช้จากแอปบนมือถือเท่านั้น'
                      : 'ใช้ไม่ได้ขณะอุปกรณ์ออฟไลน์ กรุณาใช้ปุ่ม Factory Reset บนบอร์ด',
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'หากไม่เลือกล้าง Wi-Fi คุณสามารถลงทะเบียนอุปกรณ์กลับมาใหม่ได้ทันที',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(resetWifi),
              child: const Text('ลบอุปกรณ์'),
            ),
          ],
        ),
      ),
    );

    if (resetWifiRequested == null || !mounted) return;

    setState(() => _deletingDeviceId = deviceId);
    try {
      if (resetWifiRequested) {
        await ApiService.instance.resetDeviceWifi(ipAddress);
      }

      await ApiService.instance.removeDevice(deviceId);
      if (!mounted) return;

      final remainingDevices = await ApiService.instance.devices();
      if (!mounted) return;

      if (remainingDevices.isEmpty) {
        widget.onDevicesEmpty?.call();
        if (widget.onDevicesEmpty == null && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => DeviceRegistrationScreen(
                onRegistered: () {
                  if (!mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const DeviceManagementScreen(),
                    ),
                  );
                },
              ),
            ),
          );
        }
        return;
      }

      setState(() => _deviceList = remainingDevices);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resetWifiRequested
                ? 'ลบอุปกรณ์และล้าง Wi-Fi แล้ว บอร์ดกำลังเข้าสู่โหมด BLE'
                : 'ลบอุปกรณ์ออกจากบัญชีแล้ว',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ลบอุปกรณ์ไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _deletingDeviceId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    double scale = (screenWidth / 375.0).clamp(0.85, 1.25);
    final horizontalPadding = (screenWidth * 0.05).clamp(16.0, 24.0);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.surfaceMuted,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.cFF0F2647),
        ),
      );
    }

    final totalCount = _deviceList.length;
    final onlineCount = _deviceList.where(_isOnline).length;
    final offlineCount = totalCount - onlineCount;

    // กรองลิสต์ตามตัวเลือก Filter
    final filteredDevices = _deviceList.where((d) {
      final isOnline = _isOnline(d);
      if (_selectedFilter == 'ออนไลน์') return isOnline;
      if (_selectedFilter == 'ออฟไลน์') return !isOnline;
      return true; // 'ทั้งหมด'
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: RefreshIndicator(
        onRefresh: _loadDevices,
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
                  // 1. Header พื้นหลังสีน้ำเงิน Gradient
                  _buildHeader(
                    scale,
                    horizontalPadding,
                    onlineCount,
                    totalCount,
                  ),

                  // 2. เนื้อหาซ้อนทับ Header (Overlap Layout)
                  Padding(
                    padding: EdgeInsets.only(top: 170 * scale),
                    child: Column(
                      children: [
                        // การ์ดสรุปสถานะอุปกรณ์ (3 การ์ดเล็ก)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  title: "ทั้งหมด",
                                  value: "$totalCount",
                                  icon: Icons.developer_board_rounded,
                                  color: AppColors.cFF0F2647,
                                  scale: scale,
                                ),
                              ),
                              SizedBox(width: 8 * scale),
                              Expanded(
                                child: _buildSummaryCard(
                                  title: "ออนไลน์",
                                  value: "$onlineCount",
                                  icon: Icons.wifi_rounded,
                                  color: const Color(0xFF10B981),
                                  scale: scale,
                                ),
                              ),
                              SizedBox(width: 8 * scale),
                              Expanded(
                                child: _buildSummaryCard(
                                  title: "ออฟไลน์",
                                  value: "$offlineCount",
                                  icon: Icons.wifi_off_rounded,
                                  color: const Color(0xFF6B7280),
                                  scale: scale,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 20 * scale),

                        // ปุ่ม Filter Chips (ทั้งหมด / ออนไลน์ / ออฟไลน์)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                          ),
                          child: Row(
                            children: [
                              _buildFilterChip('ทั้งหมด', scale),
                              SizedBox(width: 8 * scale),
                              _buildFilterChip('ออนไลน์', scale),
                              SizedBox(width: 8 * scale),
                              _buildFilterChip('ออฟไลน์', scale),
                            ],
                          ),
                        ),

                        SizedBox(height: 16 * scale),

                        // รายการอุปกรณ์
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                          ),
                          child: filteredDevices.isEmpty
                              ? _buildEmptyState(scale)
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filteredDevices.length,
                                  itemBuilder: (context, index) {
                                    final device = filteredDevices[index];
                                    return _buildDeviceCard(device, scale);
                                  },
                                ),
                        ),

                        SizedBox(height: 40 * scale),
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

  // --- Header ---
  Widget _buildHeader(
    double scale,
    double padding,
    int onlineCount,
    int totalCount,
  ) {
    return Container(
      height: 230 * scale,
      padding: EdgeInsets.fromLTRB(padding, 56 * scale, padding, 0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cFF0F2647, AppColors.cFF1E3A66],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const MainLayout(initialIndex: 0),
                ),
                (route) => false,
              );
            },
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 18 * scale,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.12),
              padding: EdgeInsets.all(10 * scale),
            ),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "รายการอุปกรณ์",
                  style: GoogleFonts.prompt(
                    color: Colors.white,
                    fontSize: 24 * scale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2 * scale),
                Text(
                  "เชื่อมต่อแล้ว $onlineCount จาก $totalCount อุปกรณ์",
                  style: GoogleFonts.prompt(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 13 * scale,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Summary Card ---
  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double scale,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 14 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.prompt(
                  color: AppColors.cFF6B7280,
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: color, size: 16 * scale),
            ],
          ),
          SizedBox(height: 6 * scale),
          Text(
            value,
            style: GoogleFonts.prompt(
              color: color,
              fontSize: 22 * scale,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  // --- Filter Chip ---
  Widget _buildFilterChip(String label, double scale) {
    final bool isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: 16 * scale,
          vertical: 8 * scale,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cFF0F2647 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.cFF0F2647 : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.cFF0F2647.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.prompt(
            fontSize: 13 * scale,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.cFF6B7280,
          ),
        ),
      ),
    );
  }

  // --- Device Item Card ---
  Widget _buildDeviceCard(Map<String, dynamic> device, double scale) {
    final isOnline = _isOnline(device);
    final statusColor = isOnline
        ? const Color(0xFF10B981)
        : const Color(0xFF9CA3AF);

    return Container(
      margin: EdgeInsets.only(bottom: 12 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20 * scale),
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
        borderRadius: BorderRadius.circular(20 * scale),
        child: InkWell(
          borderRadius: BorderRadius.circular(20 * scale),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    DeviceCustomizationScreen(deviceData: device),
              ),
            ).then((_) => _loadDevices());
          },
          child: Padding(
            padding: EdgeInsets.all(16 * scale),
            child: Row(
              children: [
                // Icon Box พร้อมไฟจุดสถานะออนไลน์/ออฟไลน์
                Stack(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12 * scale),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.developer_board_rounded,
                        color: statusColor,
                        size: 26 * scale,
                      ),
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 12 * scale,
                        height: 12 * scale,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 14 * scale),

                // รายละเอียดอุปกรณ์
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device['device_name'] ?? 'ไม่ระบุชื่ออุปกรณ์',
                        style: GoogleFonts.prompt(
                          fontSize: 16 * scale,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cFF1F2937,
                        ),
                      ),
                      SizedBox(height: 2 * scale),
                      Text(
                        "S/N: ${device['serial_number'] ?? '-'}",
                        style: GoogleFonts.prompt(
                          fontSize: 12 * scale,
                          color: AppColors.cFF6B7280,
                        ),
                      ),
                    ],
                  ),
                ),

                // ป้ายสถานะ และลูกศร
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10 * scale,
                        vertical: 4 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isOnline ? "ออนไลน์" : "ออฟไลน์",
                        style: GoogleFonts.prompt(
                          fontSize: 11 * scale,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    SizedBox(width: 8 * scale),
                    if (_deletingDeviceId == device['device_id']?.toString())
                      SizedBox(
                        width: 22 * scale,
                        height: 22 * scale,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.redAccent,
                        ),
                      )
                    else
                      IconButton(
                        tooltip: 'ลบอุปกรณ์',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: 30 * scale,
                          minHeight: 30 * scale,
                        ),
                        onPressed: () => _confirmRemoveDevice(device),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                          size: 20 * scale,
                        ),
                      ),
                    SizedBox(width: 4 * scale),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.cFF9CA3AF,
                      size: 20 * scale,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Empty State ---
  Widget _buildEmptyState(double scale) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: 40 * scale,
        horizontal: 20 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20 * scale),
      ),
      child: Column(
        children: [
          Icon(
            Icons.devices_other_rounded,
            size: 48 * scale,
            color: AppColors.cFF9CA3AF,
          ),
          SizedBox(height: 12 * scale),
          Text(
            "ไม่พบอุปกรณ์ในหมวดหมู่นี้",
            style: GoogleFonts.prompt(
              fontSize: 15 * scale,
              color: AppColors.cFF6B7280,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
