import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main_layout.dart';
import 'device_setting.dart';
import '/services/api_service.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  static const Color primaryColor = Color(0xFF0F2646);
  static const Color backgroundColor = Color(0xFFF3F4F6);
  static const Color cardColor = Colors.white;
  static const Color textMain = Color(0xFF1F2937);
  static const Color textSub = Color(0xFF6B7280);
  static const Color successGreen = Color(0xFF4ADE80);
  static const Color offlineGrey = Color(0xFF9CA3AF);

  List<Map<String, dynamic>> _deviceList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      final list = await ApiService.instance.devices();
      setState(() {
        _deviceList = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ดึงรายการอุปกรณ์ผิดพลาด: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          _buildTopBanner(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryColor))
                : _deviceList.isEmpty
                    ? Center(child: Text("ไม่พบอุปกรณ์ที่เชื่อมต่อ", style: GoogleFonts.prompt(color: textSub)))
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        itemCount: _deviceList.length,
                        itemBuilder: (context, index) {
                          final dev = _deviceList[index];
                          final isOnline = dev['status'] == 'ออนไลน์' || dev['status'] == 'online';
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
                                child: Icon(Icons.videocam_rounded, color: primaryColor, size: 28),
                              ),
                              title: Text(
                                dev['device_name'] ?? 'กล้องตรวจจับ',
                                style: GoogleFonts.prompt(fontSize: 16, fontWeight: FontWeight.bold, color: textMain),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('S/N: ${dev['serial_number'] ?? '-'}', style: GoogleFonts.prompt(color: textSub, fontSize: 13)),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: isOnline ? successGreen : offlineGrey,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: offlineGrey),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DeviceCustomizationScreen(deviceData: dev),
                                  ),
                                ).then((_) => _loadDevices());
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBanner() {
    final onlineCount = _deviceList.where((d) => d['status'] == 'ออนไลน์' || d['status'] == 'online').length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
      decoration: const BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const MainLayout(initialIndex: 3)),
                    (route) => false,
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                "รายการอุปกรณ์",
                style: GoogleFonts.prompt(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 4),
            child: Text(
              "เชื่อมต่อ $onlineCount อุปกรณ์ออนไลน์",
              style: GoogleFonts.prompt(color: Colors.blue.shade100, fontSize: 14),
            ),
          )
        ],
      ),
    );
  }
}