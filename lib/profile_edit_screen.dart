import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  // --- Theme Colors ---
  static const Color primaryDark = Color(0xFF0D2140);
  static const Color primaryLight = Color(0xFF1E3A8A);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textGrey = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);
  
  // Input Controllers
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _vehicleController;

  @override
  void initState() {
    super.initState();
    // Initialize with dummy data (ปรับข้อมูลตัวอย่างเป็นบริบทไทย)
    _nameController = TextEditingController(text: "สมชาย รักดี");
    _emailController = TextEditingController(text: "somchai.r@savedrive.ai");
    _phoneController = TextEditingController(text: "089-123-4567");
    _vehicleController = TextEditingController(text: "Tesla Model 3");
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: Column(
        children: [
          // --- 1. Header Section ---
          _buildHeader(),

          // --- 2. Scrollable Form Content ---
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    // Avatar Section
                    _buildAvatarSection(),
                    
                    const SizedBox(height: 32),

                    // Form Fields (แปลภาษาไทย)
                    _buildInputField(
                      label: "ชื่อ-นามสกุล", // Full Name
                      controller: _nameController,
                      icon: Icons.person_rounded,
                      inputType: TextInputType.name,
                    ),
                    const SizedBox(height: 20),
                    
                    _buildInputField(
                      label: "อีเมล", // Email Address
                      controller: _emailController,
                      icon: Icons.email_rounded,
                      inputType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    
                    _buildInputField(
                      label: "เบอร์โทรศัพท์", // Phone Number
                      controller: _phoneController,
                      icon: Icons.phone_rounded,
                      inputType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // --- 3. Bottom Action Bar ---
          _buildBottomBar(),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryDark, primaryLight],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)), // 2rem
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
        child: Column(
          children: [
            // Status Bar Mockup
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "9:41",
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Row(
                    children: const [
                      Icon(Icons.signal_cellular_alt_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Icon(Icons.wifi_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Icon(Icons.battery_full_rounded, color: Colors.white, size: 18),
                    ],
                  )
                ],
              ),
            ),
            
            // Header Title Row
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                  
                  // Title (แปลไทย)
                  Text(
                    "แก้ไขโปรไฟล์", // Edit Profile
                    style: GoogleFonts.inter( // ถ้าต้องการฟอนต์ไทยสวยๆ แนะนำเปลี่ยนเป็น GoogleFonts.kanit หรือ prompt
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  
                  // Dummy spacer to center title
                  const SizedBox(width: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Stack(
        children: [
          // Dashed Border Container
          CustomPaint(
            painter: DashedCirclePainter(color: Colors.grey.shade300),
            child: Container(
              width: 112, // w-28 (28 * 4 = 112px)
              height: 112,
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey,
                  image: DecorationImage(
                    image: NetworkImage("https://i.pravatar.cc/300?img=11"), // Placeholder
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          
          // Camera Button
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: primaryDark,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required TextInputType inputType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label, // ไม่ต้อง .toUpperCase() แล้วเพราะภาษาไทยไม่มีตัวพิมพ์ใหญ่
            style: GoogleFonts.inter(
              color: textGrey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12), // rounded-xl
            boxShadow: const [
               BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.05), // shadow-input
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: inputType,
            style: GoogleFonts.inter(
              color: textDark,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryDark),
              ),
              suffixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  // Save Action
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  shadowColor: Colors.blue.shade900.withOpacity(0.2),
                ),
                child: Text(
                  "บันทึกการเปลี่ยนแปลง", // Save Changes
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Home indicator bar
            Container(
              width: 128,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter for the Dashed Border around Avatar
class DashedCirclePainter extends CustomPainter {
  final Color color;
  DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final double radius = size.width / 2;
    final double circumference = 2 * math.pi * radius;
    const double dashWidth = 6;
    const double dashSpace = 4;
    
    double startAngle = 0;
    while (startAngle < 2 * math.pi) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(radius, radius), radius: radius),
        startAngle,
        (dashWidth / circumference) * 2 * math.pi,
        false,
        paint,
      );
      startAngle += ((dashWidth + dashSpace) / circumference) * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}