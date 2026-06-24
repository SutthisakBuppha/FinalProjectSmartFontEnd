import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'custom_bottom_nav_bar.dart'; // เรียกใช้ Navbar ของคุณ

class RiskTrendsScreen extends StatefulWidget {
  const RiskTrendsScreen({super.key});

  @override
  State<RiskTrendsScreen> createState() => _RiskTrendsScreenState();
}

class _RiskTrendsScreenState extends State<RiskTrendsScreen> {
  // สีตาม Tailwind Theme
  static const Color primary = Color(0xFF0F2557);
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color backgroundOffwhite = Color(0xFFF6F8FA);
  
  int _currentIndex = 1; // สมมติว่าหน้านี้คือ index 1 (Report/History)

  // ตัวแปรสำหรับ Dropdown Filter
  String _selectedFilter = 'รายเดือน'; 
  final List<String> _filterOptions = ['รายสัปดาห์', 'รายเดือน', 'รายปี'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundOffwhite,
      appBar: AppBar(
        backgroundColor: backgroundLight,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "แนวโน้มความเสี่ยง", // เปลี่ยนเป็นภาษาไทย
          style: GoogleFonts.prompt( // แนะนำให้ใช้ GoogleFonts.prompt หรือ sarabun สำหรับภาษาไทยจะสวยกว่า
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded, color: primary),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTrendChart(),
            const SizedBox(height: 24),
            _buildRiskBreakdownHeader(),
            const SizedBox(height: 16),
            _buildRiskBreakdownGrid(),
            const SizedBox(height: 32), // Padding ด้านล่าง
          ],
        ),
      ),
      // เรียกใช้ Custom Bottom Nav Bar ของคุณตรงนี้
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // นำทางไปยังหน้าอื่นตามต้องการ
        },
      ),
    );
  }

  // ฟังก์ชันสำหรับกำหนด Label แกน X ตาม Filter ที่เลือก
  List<String> _getChartLabels() {
    switch (_selectedFilter) {
      case 'รายสัปดาห์':
        return ["จ.", "พ.", "ศ.", "ส.", "อา."];
      case 'รายปี':
        return ["ม.ค.", "เม.ย.", "ก.ค.", "ต.ค.", "ธ.ค."];
      case 'รายเดือน':
      default:
        return ["สัปดาห์ 1", "สัปดาห์ 2", "สัปดาห์ 3", "สัปดาห์ 4", "วันนี้"];
    }
  }

  // 1. Trend Chart Section (อัปเดตใส่ Dropdown)
  Widget _buildTrendChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: backgroundLight,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ภาพรวมแนวโน้ม", // เปลี่ยนเป็นภาษาไทย
                style: GoogleFonts.prompt(fontSize: 16, fontWeight: FontWeight.bold, color: primary),
              ),
              // Dropdown สำหรับกรองข้อมูล
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: backgroundOffwhite,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isDense: true,
                    value: _selectedFilter,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: primary),
                    style: GoogleFonts.prompt(
                      fontSize: 12, 
                      fontWeight: FontWeight.w600, 
                      color: primary
                    ),
                    dropdownColor: backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedFilter = newValue;
                        });
                        // TODO: ใส่ Logic ดึงข้อมูลกราฟใหม่จาก API ตาม newValue ตรงนี้
                      }
                    },
                    items: _filterOptions.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Custom Chart พื้นที่สูง 160
          SizedBox(
            height: 160,
            width: double.infinity,
            child: Stack(
              children: [
                // เส้น Grid แนวนอน
                CustomPaint(
                  size: const Size(double.infinity, 160),
                  painter: GridPainter(),
                ),
                // เส้นกราฟและจุด
                CustomPaint(
                  size: const Size(double.infinity, 140),
                  painter: ChartPainter(color: primary),
                ),
                // X-Axis Labels (ปรับเปลี่ยนตาม Dropdown แบบอัตโนมัติ)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _getChartLabels()
                        .map((text) => Text(
                              text,
                              style: GoogleFonts.prompt(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Risk Breakdown Header
  Widget _buildRiskBreakdownHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          "รายละเอียดความเสี่ยง", // เปลี่ยนเป็นภาษาไทย
          style: GoogleFonts.prompt(fontSize: 16, fontWeight: FontWeight.bold, color: primary),
        ),
        Text(
          "ดูทั้งหมด", // เปลี่ยนเป็นภาษาไทย
          style: GoogleFonts.prompt(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  // 3. Risk Breakdown Grid
  Widget _buildRiskBreakdownGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildBreakdownCard(
                title: "หลับใน", // Drowsiness
                events: "4 ครั้ง",
                icon: Icons.hotel_rounded,
                iconColor: Colors.red,
                iconBgColor: Colors.red.shade50,
                badgeText: "+2",
                badgeColor: Colors.red,
                badgeBgColor: Colors.red.shade50,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildBreakdownCard(
                title: "เสียสมาธิ", // Distraction
                events: "2 ครั้ง",
                icon: Icons.phone_iphone_rounded,
                iconColor: Colors.orange,
                iconBgColor: Colors.orange.shade50,
                badgeText: "-1",
                badgeColor: Colors.grey.shade600,
                badgeBgColor: backgroundOffwhite,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildBreakdownCard(
                title: "ขับรถเร็ว", // Speeding
                events: "5 ครั้ง",
                icon: Icons.speed_rounded,
                iconColor: Colors.blue,
                iconBgColor: Colors.blue.shade50,
                badgeText: "0",
                badgeColor: Colors.grey.shade600,
                badgeBgColor: backgroundOffwhite,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildBreakdownCard(
                title: "เบรกกะทันหัน", // Hard Braking
                events: "1 ครั้ง",
                icon: Icons.priority_high_rounded,
                iconColor: Colors.purple,
                iconBgColor: Colors.purple.shade50,
                badgeText: "-3",
                badgeColor: Colors.green,
                badgeBgColor: Colors.green.shade50,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBreakdownCard({
    required String title,
    required String events,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String badgeText,
    required Color badgeColor,
    required Color badgeBgColor,
  }) {
    return Container(
      height: 130,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.prompt(
                    color: badgeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.prompt(fontSize: 14, fontWeight: FontWeight.bold, color: primary),
              ),
              const SizedBox(height: 2),
              Text(
                events,
                style: GoogleFonts.prompt(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// Custom Painters สำหรับวาดกราฟแบบใน HTML
// ==========================================

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // วาดเส้นประ 3 เส้น
    _drawDashedLine(canvas, size, size.height - 30, paint); // ล่าง
    _drawDashedLine(canvas, size, size.height - 80, paint); // กลาง
    _drawDashedLine(canvas, size, size.height - 130, paint); // บน
  }

  void _drawDashedLine(Canvas canvas, Size size, double y, Paint paint) {
    double dashWidth = 5, dashSpace = 5, startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ChartPainter extends CustomPainter {
  final Color color;
  ChartPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // จุดกะระยะเลียนแบบ SVG Curve
    final points = [
      Offset(0, size.height * 0.8),
      Offset(size.width * 0.16, size.height * 0.5),
      Offset(size.width * 0.5, size.height * 0.65),
      Offset(size.width * 0.83, size.height * 0.45),
      Offset(size.width, size.height * 0.2),
    ];

    // สร้าง Path
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    
    // ใช้ Cubic Bezier เลียนแบบความโค้ง
    path.quadraticBezierTo(size.width * 0.08, size.height * 0.7, points[1].dx, points[1].dy);
    path.quadraticBezierTo(size.width * 0.33, size.height * 0.3, points[2].dx, points[2].dy);
    path.quadraticBezierTo(size.width * 0.66, size.height * 1.0, points[3].dx, points[3].dy);
    path.quadraticBezierTo(size.width * 0.9, size.height * 0.35, points[4].dx, points[4].dy);

    // 1. วาด Gradient ใต้กราฟ
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withOpacity(0.2), color.withOpacity(0.0)],
    );
    final fillPaint = Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // 2. วาดเส้นกราฟ
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    // 3. วาดจุดบนกราฟ (วงกลมขาว ขอบน้ำเงิน)
    final dotPaintWhite = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final dotPaintBorder = Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(points[i], 4, dotPaintWhite);
      canvas.drawCircle(points[i], 4, dotPaintBorder);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true; // ให้ Paint ใหม่เวลา state เปลี่ยน (ถ้ามีการวาดกราฟใหม่)
}