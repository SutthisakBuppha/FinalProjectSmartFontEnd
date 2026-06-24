import 'dart:ui'; // สำหรับ ImageFilter
import 'package:flutter/material.dart';

// Import หน้า MapScreen
import 'map_screen.dart'; 

class AlertScreen extends StatelessWidget {
  const AlertScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // กำหนดสีตาม Tailwind config
    const Color backgroundDark = Color(0xFF161022);
    const Color alertRed = Color(0xFFFF4D4D);
    
    return Scaffold(
      backgroundColor: backgroundDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- Layer 1: Background UI (Map & Dashboard) ---
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // ส่วนข้อความ Header (ชื่อแอปมักทับศัพท์ แต่ถ้าอยากเปลี่ยนก็เปลี่ยนตรงนี้ได้ครับ)
                      const Expanded(
                        child: Text(
                          "SaveDriveAi",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Manrope',
                          ),
                        ),
                      ),
                      // ปุ่มขวา (Profile)
                      _buildIconButton(Icons.account_circle),
                    ],
                  ),
                ),
                
                // Map Placeholder Area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                            image: const DecorationImage(
                              image: NetworkImage("https://via.placeholder.com/400x700/333333/666666?text=Map+View"),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 24,
                          left: 16,
                          right: 16,
                          child: Row(
                            children: [
                              // แปล: ความเร็วปัจจุบัน
                              Expanded(child: _buildInfoCard("ความเร็ว", "65 กม./ชม.")),
                              const SizedBox(width: 16),
                              // แปล: เวลาขับขี่
                              Expanded(child: _buildInfoCard("เวลาขับขี่", "2 ชม. 15 น.")),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                // Bottom Indicator
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    height: 6,
                    width: 128,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- Layer 2: Blur Overlay ---
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: backgroundDark.withOpacity(0.6),
              ),
            ),
          ),

          // --- Layer 3: Modal Alert ---
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Warning Icon
                    const PulseWarningIcon(color: alertRed),
                    
                    const SizedBox(height: 24),
                    
                    // Title (แปลไทย)
                    const Text(
                      "ตรวจพบความเสี่ยงง่วงนอน",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF120D1B),
                        fontSize: 24,
                        height: 1.2, // ปรับความสูงบรรทัดเล็กน้อยให้อ่านง่ายขึ้น
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Subtitle (แปลไทย)
                    const Text(
                      "ระบบแจ้งเตือนความปลอดภัยทำงาน โปรดหาที่จอดพักที่ปลอดภัยทันที",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Status Icons (แปลไทย)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStatusIndicator(Icons.volume_up, "เสียงเตือน"),
                        const SizedBox(width: 16),
                        _buildStatusIndicator(Icons.vibration, "ระบบสั่น"),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ปุ่ม Navigate (แปลไทย)
                    _buildFilledButton(
                      text: "นำทางไปจุดพักรถใกล้ฉัน", 
                      icon: Icons.navigation, 
                      color: alertRed,
                      onPressed: () {
                        // สั่งให้เปลี่ยนหน้าไป MapScreen
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MapScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161022).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFDBEAFE)),
          ),
          child: Icon(icon, color: const Color(0xFF3B82F6), size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF60A5FA),
            fontSize: 12, // เพิ่มขนาดเล็กน้อยให้อ่านภาษาไทยชัดขึ้น
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFilledButton({
    required String text, 
    required IconData icon, 
    required Color color, 
    required VoidCallback onPressed
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed, 
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 5,
          shadowColor: Colors.red[200],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PulseWarningIcon extends StatefulWidget {
  final Color color;
  const PulseWarningIcon({super.key, required this.color});

  @override
  State<PulseWarningIcon> createState() => _PulseWarningIconState();
}

class _PulseWarningIconState extends State<PulseWarningIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: const BoxDecoration(
        color: Color(0xFFFEF2F2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Icon(
            Icons.warning_rounded,
            color: widget.color,
            size: 60,
          ),
        ),
      ),
    );
  }
}