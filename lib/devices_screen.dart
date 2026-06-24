import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- 1. Import MainLayout เหมือนเดิม ---
import 'main_layout.dart';
import 'device_setting.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  // --- Theme Colors ---
  static const Color primaryColor = Color(0xFF0F2646);
  static const Color secondaryColor = Color(
    0xFFE63946,
  ); // สีแดงเดิม (ไม่ได้ใช้กับสถานะแล้ว)
  static const Color backgroundColor = Color(0xFFF3F4F6);
  static const Color cardColor = Colors.white;
  static const Color textMain = Color(0xFF1F2937);
  static const Color textSub = Color(0xFF6B7280);
  static const Color successGreen = Color(
    0xFF4ADE80,
  ); // สีเขียวสำหรับสถานะทำงาน
  static const Color offlineGrey = Color(
    0xFF9CA3AF,
  ); // สีเทาสำหรับสถานะไม่ทำงาน

  // --- Mock Data ---
  List<Map<String, dynamic>> devices = [
    {
      "id": "CAM-001",
      "name": "กล้องหน้า (DMS)",
      "type": "Camera",
      "icon": Icons.videocam_rounded,
      "isOnline": true, // สถานะทำงาน (จุดเขียว)
      "isEnabled": true,
      "battery": null,
      "lastActive": "กำลังทำงาน",
    },
    {
      "id": "CAM-001",
      "name": "กล้องหน้า (DMS)",
      "type": "Camera",
      "icon": Icons.videocam_rounded,
      "isOnline": false, // สถานะไม่ทำงาน (จุดเทา)
      "isEnabled": false,
      "battery": "0%",
      "lastActive": "10 นาทีที่แล้ว",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // 1. Header
          _buildHeader(context),

          // 2. Device List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return _buildDeviceCard(device, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- ส่วนที่แก้ไขหลัก: เปลี่ยน Switch เป็นจุดแสดงสถานะ ---
  Widget _buildDeviceCard(Map<String, dynamic> device, int index) {
    bool isOnline = device['isOnline'];

    // กำหนดสีและข้อความตามสถานะ
    Color statusColor = isOnline ? successGreen : offlineGrey;
    String statusText = isOnline ? "ทำงานปกติ" : "ออฟไลน์";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // --- เพิ่ม Material และ InkWell ตรงนี้ ---
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // เมื่อกดให้ Navigate ไปยังหน้า Device Setting
            // และส่งข้อมูล device ไปด้วย
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DeviceCustomizationScreen(deviceData: device),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Icon Box
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? primaryColor.withOpacity(0.1)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        device['icon'],
                        color: isOnline ? primaryColor : Colors.grey,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Device Name & ID
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device['name'],
                            style: GoogleFonts.prompt(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textMain,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "ID: ${device['id']}",
                            style: GoogleFonts.prompt(
                              fontSize: 12,
                              color: textSub,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          // จุดสี (Dot)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColor,
                              boxShadow: isOnline
                                  ? [
                                      BoxShadow(
                                        color: successGreen.withOpacity(0.4),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : [],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // ข้อความสถานะ
                          Text(
                            statusText,
                            style: GoogleFonts.prompt(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),

                // Bottom Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "สถานะการเชื่อมต่อ",
                      style: GoogleFonts.prompt(fontSize: 12, color: textSub),
                    ),
                    Text(
                      isOnline
                          ? "กำลังส่งข้อมูล..."
                          : "ใช้งานล่าสุด: ${device['lastActive']}",
                      style: GoogleFonts.prompt(
                        fontSize: 12,
                        color: textSub,
                        fontStyle: isOnline
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [primaryColor, Color(0xFF1A3B66)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const MainLayout(initialIndex: 3),
                        ),
                        (route) => false,
                      );
                    },
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),

                  Text(
                    "รายการอุปกรณ์",
                    style: GoogleFonts.prompt(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Text(
                  "เชื่อมต่อ ${devices.where((d) => d['isOnline'] == true).length} อุปกรณ์",
                  style: GoogleFonts.prompt(
                    color: Colors.blue.shade100,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
