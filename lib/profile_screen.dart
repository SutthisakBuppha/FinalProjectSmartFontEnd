import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Import หน้า Edit Profile
import 'profile_edit_screen.dart';
// Import Navbar เดิมของคุณ
import 'custom_bottom_nav_bar.dart';
// --- 1. Import หน้า Login เพื่อใช้ตอน Logout ---
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // --- Theme Colors ---
  static const Color primaryDark = Color(0xFF0D2140);
  static const Color primaryLight = Color(0xFF1E3A8A);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color successGreen = Color(0xFF10B981);
  static const Color textDark = Color(0xFF0F172A);

  // --- ฟังก์ชันสำหรับ Logout ---
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("ยืนยันการออกจากระบบ", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text("คุณต้องการออกจากระบบใช่หรือไม่?", style: GoogleFonts.inter()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("ยกเลิก", style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // ปิด Dialog
              // ไปหน้า Login และล้าง Stack เก่าทิ้งทั้งหมด (กด Back กลับมาไม่ได้)
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: Text("ออกจากระบบ", style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      extendBody: true,
      body: Stack(
        children: [
          Column(
            children: [
              // --- 1. Header Section ---
              _buildHeader(),

              // --- 2. Scrollable Content (Logs) ---
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                    child: Column(
                      children: [
                        // Section Title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "ประวัติการขับขี่ล่าสุด",
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            Text(
                              "ดูทั้งหมด",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: accentBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // --- Log Cards ---
                        _buildLogCard(
                          icon: Icons.commute_rounded,
                          iconColor: const Color(0xFF60A5FA),
                          iconBg: const Color(0xFFEFF6FF),
                          title: "เดินทางไปทำงาน",
                          tag: "ยอดเยี่ยม",
                          tagColor: const Color(0xFF047857),
                          tagBg: const Color(0xFFD1FAE5),
                          subtitle: "วันนี้ • 20 กม. • 28 นาที",
                        ),
                        _buildLogCard(
                          icon: Icons.shopping_bag_rounded,
                          iconColor: const Color(0xFF818CF8),
                          iconBg: const Color(0xFFEEF2FF),
                          title: "ซื้อของเข้าบ้าน",
                          tag: "ดีมาก",
                          tagColor: const Color(0xFF1D4ED8),
                          tagBg: const Color(0xFFDBEAFE),
                          subtitle: "เมื่อวาน • 6.7 กม. • 15 นาที",
                        ),
                        _buildLogCard(
                          icon: Icons.map_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          iconBg: const Color(0xFFFFFBEB),
                          title: "เที่ยววันหยุด",
                          tag: "ควรระวัง",
                          tagColor: const Color(0xFFB45309),
                          tagBg: const Color(0xFFFEF3C7),
                          subtitle: "24 ต.ค. • 235 กม. • 2 ชม. 45 นาที",
                        ),
                         _buildLogCard(
                          icon: Icons.restaurant_rounded,
                          iconColor: const Color(0xFFA78BFA),
                          iconBg: const Color(0xFFF5F3FF),
                          title: "ทานข้าวนอกบ้าน",
                          tag: "ยอดเยี่ยม",
                          tagColor: const Color(0xFF047857),
                          tagBg: const Color(0xFFD1FAE5),
                          subtitle: "23 ต.ค. • 13 กม. • 20 นาที",
                        ),

                        // --- 3. ส่วนปุ่ม Logout ที่เพิ่มเข้ามา ---
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _handleLogout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red.shade600,
                              elevation: 0,
                              side: BorderSide(color: Colors.red.shade100),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.logout_rounded),
                                const SizedBox(width: 8),
                                Text(
                                  "ออกจากระบบ",
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
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
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
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
        child: Stack(
          children: [
            // Settings Button
            Positioned(
              top: 50,
              right: 24,
              child: IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileEditScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 24),
              ),
            ),
            
            Column(
              children: [
                // Status Bar Mockup
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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

                const SizedBox(height: 16),

                // Profile Info
                Column(
                  children: [
                    // Avatar
                    Stack(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.2), width: 3),
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey,
                              image: DecorationImage(
                                image: AssetImage("images/image.png"),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        // Online Dot
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: successGreen,
                              shape: BoxShape.circle,
                              border: Border.all(color: primaryDark, width: 4),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Name
                    Text(
                      "สมชาย รักดี", 
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    
                    // Badge
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_rounded, color: Colors.blue.shade200, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          "ผู้ขับขี่ปลอดภัย ระดับ 4",
                          style: GoogleFonts.inter(
                            color: Colors.blue.shade100,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Stats Grid
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Row(
                        children: [
                          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
                          _buildStatItem("ระยะทาง (กม.)", "1,995"),
                          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
                          _buildStatItem("เที่ยวเดินทาง", "42"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.blue.shade200,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String tag,
    required Color tagColor,
    required Color tagBg,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF0F172A),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: tagBg,
                        borderRadius: BorderRadius.circular(999), 
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.inter(
                          color: tagColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}