import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'services/api_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool isLoading = true;
  bool isError = false;
  bool isAuthError = false; // 💡 เช็กว่าเป็น Error เรื่อง Token หรือไม่
  String errorMessage = '';

  // ตัวแปรเก็บข้อมูลสรุป (ดึงตรงจาก backend)
  int todayEventsCount = 0;
  int maxRiskLevel = 1;

  // รายการแจ้งเตือนทั้งหมด (ล่าสุดก่อน)
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    fetchNotificationData();
  }

  // ดึงข้อมูลจาก backend ผ่าน ApiService (ใช้ token/driver_id ชุดเดียวกับทั้งแอป
  // แทนการอ่าน SharedPreferences ตรงๆ ซึ่งใช้คนละ key กับที่ ApiService บันทึกไว้)
  Future<void> fetchNotificationData() async {
    setState(() {
      isLoading = true;
      isError = false;
      isAuthError = false;
    });

    // ❌ ยังไม่ได้ login หรือ session หลุดไปแล้ว
    if (!ApiService.instance.isLoggedIn) {
      setState(() {
        isError = true;
        isAuthError = true;
        errorMessage = 'ไม่พบข้อมูลการเข้าสู่ระบบ กรุณาล็อกอินใหม่อีกครั้ง';
        isLoading = false;
      });
      return;
    }

    try {
      // 📡 ยิงพร้อมกัน: รายการแจ้งเตือนทั้งหมด + สรุปวันนี้
      final results = await Future.wait([
        ApiService.instance.notifications(),
        ApiService.instance.notificationsSummary(),
      ]);

      final list = results[0] as List<Map<String, dynamic>>;
      final summary = results[1] as Map<String, dynamic>;

      setState(() {
        notifications = list;
        todayEventsCount = (summary['today_events'] as num?)?.toInt() ?? 0;
        maxRiskLevel = (summary['max_risk'] as num?)?.toInt() ?? 1;
        isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        isError = true;
        isAuthError = e.statusCode == 401 || e.statusCode == 403;
        errorMessage = isAuthError
            ? 'เซสชันหมดอายุ กรุณาล็อกอินใหม่อีกครั้ง'
            : e.message;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isError = true;
        isAuthError = false;
        errorMessage = 'ไม่สามารถเชื่อมต่อระบบได้ กรุณาลองใหม่อีกครั้ง';
        isLoading = false;
      });
    }
  }

  // ฟังก์ชันจัดการเมื่อกดปุ่ม "ลองใหม่" / "เข้าสู่ระบบใหม่"
  Future<void> handleRetryOrLogout() async {
    if (isAuthError) {
      // 🔒 ถ้า Token มีปัญหา -> เคลียร์ session แล้วส่งกลับหน้า Login
      ApiService.instance.clearSession();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      // 🔄 ถ้าแค่เน็ตหลุด/ระบบขัดข้อง -> ลองดึงข้อมูลใหม่อีกรอบ
      fetchNotificationData();
    }
  }

  String _formatDate(String? raw) {
    final dt = DateTime.tryParse(raw ?? '');
    if (dt == null) return '-';
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Column(
        children: [
          // ==================== ส่วน Header สีน้ำเงิน ====================
          Container(
            padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 30),
            decoration: const BoxDecoration(
              color: Color(0xFF1B3258),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ประวัติการแจ้งเตือน',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: isLoading ? null : fetchNotificationData,
                    ),
                  ],
                ),
                const Text(
                  'ตรวจสอบระดับความเสี่ยงย้อนหลัง',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 20),

                // Cards แสดงสถิติด้านบน
                Row(
                  children: [
                    // การ์ดวันนี้
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text('วันนี้', style: TextStyle(color: Colors.black54, fontSize: 13)),
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Color(0xFFE8ECEF),
                                  child: Icon(Icons.notifications, size: 14, color: Colors.black87),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '$todayEventsCount ',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1B3258),
                                    ),
                                  ),
                                  const TextSpan(
                                    text: 'เหตุการณ์',
                                    style: TextStyle(color: Colors.black87, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // การ์ดความเสี่ยงสูงสุด
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text('ความเสี่ยงสูงสุด', style: TextStyle(color: Colors.black54, fontSize: 13)),
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Color(0xFFFFF3E0),
                                  child: Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            RichText(
                              text: TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'ระดับ ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '$maxRiskLevel ',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ==================== ส่วนแสดงเนื้อหา / Error / List ====================
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : isError
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                errorMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1B3258),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
                                ),
                                onPressed: handleRetryOrLogout,
                                child: Text(
                                  isAuthError ? 'เข้าสู่ระบบใหม่' : 'ลองใหม่',
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : notifications.isEmpty
                        ? const Center(child: Text('ยังไม่มีการแจ้งเตือน'))
                        : RefreshIndicator(
                            onRefresh: fetchNotificationData,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: notifications.length,
                              itemBuilder: (context, index) {
                                final n = notifications[index];
                                final bool isRead = n['is_read'] == true || n['is_read'] == 1;
                                final String message = n['message']?.toString() ?? '';
                                final alertData = n['alert'];
                                final String type = alertData is Map
                                    ? (alertData['type']?.toString() ?? '')
                                    : '';
                                final String time = _formatDate(n['created_at']?.toString());
                                final String notiId = n['noti_id']?.toString() ?? '';

                                return InkWell(
                                  onTap: isRead || notiId.isEmpty
                                      ? null
                                      : () async {
                                          try {
                                            await ApiService.instance
                                                .markNotificationRead(notiId);
                                            if (!mounted) return;
                                            setState(() {
                                              n['is_read'] = true;
                                            });
                                          } catch (_) {
                                            // เงียบไว้ ไม่ต้อง block UI ถ้า mark read ไม่สำเร็จ
                                          }
                                        },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isRead ? Colors.transparent : Colors.orange.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: isRead
                                              ? const Color(0xFFE8ECEF)
                                              : const Color(0xFFFFF3E0),
                                          child: Icon(
                                            Icons.warning_amber_rounded,
                                            size: 18,
                                            color: isRead ? Colors.black45 : Colors.orange,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (type.isNotEmpty)
                                                Text(
                                                  type,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              const SizedBox(height: 4),
                                              Text(
                                                message,
                                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                time,
                                                style: const TextStyle(fontSize: 11, color: Colors.black45),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}