import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme/app_theme.dart'; // ตรวจสอบ Path ให้ตรงกับโปรเจกต์ของคุณ
import 'menu/custom_bottom_nav_bar.dart'; // ตรวจสอบ Path
import 'services/api_service.dart'; // ตรวจสอบ Path

class RiskTrendsScreen extends StatefulWidget {
  const RiskTrendsScreen({super.key});

  @override
  State<RiskTrendsScreen> createState() => _RiskTrendsScreenState();
}

class _RiskTrendsScreenState extends State<RiskTrendsScreen> {
  static const primary = AppColors.cFF0F2647; // ใช้สีเดียวกับหน้า Device
  static const backgroundLight = Colors.white;
  static const backgroundOffwhite = AppColors.surfaceMuted;

  int _currentIndex = 1;
  String _selectedFilter = 'รายสัปดาห์';
  final _filterOptions = const ['รายสัปดาห์', 'รายเดือน', 'กำหนดเอง'];
  DateTimeRange? _customRange;
  
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final alerts = await ApiService.instance.alerts();
      if (!mounted) return;
      setState(() => _alerts = alerts);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'ไม่สามารถโหลดข้อมูลความเสี่ยงได้');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Logic การคำนวณข้อมูล (คงเดิม) ---
  DateTime? _alertTime(Map<String, dynamic> alert) {
    final value = alert['timestamp'] ?? alert['created_at'];
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  DateTime _day(DateTime time) => DateTime(time.year, time.month, time.day);

  String _shortDate(DateTime date) => '${date.day}/${date.month}';

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange:
          _customRange ?? DateTimeRange(start: _day(now), end: _day(now)),
      helpText: 'เลือกช่วงวันที่วิเคราะห์ความเสี่ยง',
      saveText: 'ใช้ตัวกรอง',
      cancelText: 'ยกเลิก',
      builder: (context, child) {
        final theme = Theme.of(context);
        final actionStyle = TextButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF2563EB),
          disabledForegroundColor: Colors.white,
          minimumSize: const Size(112, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          textStyle: GoogleFonts.prompt(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        );
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: const Color(0xFF2563EB),
              onPrimary: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(style: actionStyle),
            datePickerTheme: theme.datePickerTheme.copyWith(
              confirmButtonStyle: actionStyle,
              rangePickerHeaderBackgroundColor: const Color(0xFF2563EB),
              rangePickerHeaderForegroundColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (range == null || !mounted) return;
    setState(() {
      _customRange = range;
      _selectedFilter = 'กำหนดเอง';
    });
  }

  _ChartData _chartData() {
    final now = DateTime.now();
    final labels = <String>[];
    final starts = <DateTime>[];
    final ends = <DateTime>[];

    if (_selectedFilter == 'รายสัปดาห์') {
      final today = _day(now);
      final weekStart = today.subtract(Duration(days: now.weekday - 1));
      for (var i = 0; i < 7; i++) {
        final start = weekStart.add(Duration(days: i));
        starts.add(start);
        ends.add(start.add(const Duration(days: 1)));
        labels.add(const ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'][start.weekday - 1]);
      }
    } else if (_selectedFilter == 'รายเดือน') {
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 1);
      var start = monthStart;
      var weekNumber = 1;
      while (start.isBefore(monthEnd)) {
        final proposedEnd = start.add(const Duration(days: 7));
        final end = proposedEnd.isAfter(monthEnd) ? monthEnd : proposedEnd;
        starts.add(start);
        ends.add(end);
        labels.add('สัปดาห์\nที่ $weekNumber');
        weekNumber++;
        start = end;
      }
    } else {
      final range = _customRange;
      if (range == null) {
        final today = _day(now);
        starts.add(today);
        ends.add(today.add(const Duration(days: 1)));
        labels.add(_shortDate(today));
      } else {
        final rangeStart = _day(range.start);
        final rangeEnd = _day(range.end).add(const Duration(days: 1));
        final totalDays = rangeEnd.difference(rangeStart).inDays;
        final bucketDays = totalDays <= 14 ? 1 : (totalDays / 8).ceil();
        var start = rangeStart;
        while (start.isBefore(rangeEnd)) {
          final proposedEnd = start.add(Duration(days: bucketDays));
          final end = proposedEnd.isAfter(rangeEnd) ? rangeEnd : proposedEnd;
          starts.add(start);
          ends.add(end);
          labels.add(
            bucketDays == 1
                ? _shortDate(start)
                : '${_shortDate(start)}-${_shortDate(end.subtract(const Duration(days: 1)))}',
          );
          start = end;
        }
      }
    }

    final values = List<int>.filled(starts.length, 0);
    for (final alert in _alerts) {
      final time = _alertTime(alert);
      if (time == null) continue;
      for (var i = 0; i < starts.length; i++) {
        if (!time.isBefore(starts[i]) && time.isBefore(ends[i])) {
          values[i]++;
          break;
        }
      }
    }
    return _ChartData(labels, values, starts.first, ends.last);
  }

  Map<String, int> _breakdown(_ChartData data) {
    final result = <String, int>{};
    for (final alert in _alertsInRange(data)) {
      final type = (alert['type']?.toString().trim().isNotEmpty ?? false)
          ? alert['type'].toString()
          : 'ไม่ระบุประเภท';
      result[type] = (result[type] ?? 0) + 1;
    }
    final entries = result.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries);
  }

  List<Map<String, dynamic>> _alertsInRange(_ChartData data) {
    return _alerts.where((alert) {
      final time = _alertTime(alert);
      return time != null &&
          !time.isBefore(data.start) &&
          time.isBefore(data.end);
    }).toList();
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    final chart = _chartData();
    final screenWidth = MediaQuery.of(context).size.width;
    double scale = (screenWidth / 375.0).clamp(0.85, 1.25);
    final horizontalPadding = (screenWidth * 0.05).clamp(16.0, 24.0);

    return Scaffold(
      backgroundColor: backgroundOffwhite,
      body: RefreshIndicator(
        onRefresh: _loadAlerts,
        color: primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Header Gradient สีน้ำเงิน
                  _buildHeader(),

                  // 2. เนื้อหาหลัก Overlap ขึ้นไปบน Header
                  Padding(
                    padding: const EdgeInsets.only(top: 130),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // กราฟ
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                          child: _buildTrendChart(chart, scale),
                        ),
                        
                        SizedBox(height: 28 * scale),
                        
                        // หัวข้อรายละเอียด
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                          child: _buildRiskBreakdownHeader(chart, scale),
                        ),
                        
                        SizedBox(height: 16 * scale),

                        // Grid รายละเอียด
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                          child: _isLoading
                              ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: primary)))
                              : _error != null
                                  ? _buildError(scale)
                                  : _buildRiskBreakdownGrid(_breakdown(chart), scale),
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
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }

  // --- Widgets ---

  Widget _buildHeader() {
    return Container(
      height: 210,
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, Color(0xFF1E3A66)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'แนวโน้มความเสี่ยง',
                  style: GoogleFonts.prompt(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'กราฟสถิติและรายละเอียดความเสี่ยงจากการขับขี่',
                  style: GoogleFonts.prompt(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isLoading ? null : _loadAlerts,
            tooltip: 'รีเฟรชข้อมูล',
            icon: const Icon(
              Icons.refresh,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(_ChartData data, double scale) {
    return Container(
      padding: EdgeInsets.all(20 * scale),
      decoration: BoxDecoration(
        color: backgroundLight,
        borderRadius: BorderRadius.circular(24 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          // Filter แบบปุ่มแคปซูล
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: backgroundOffwhite,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: _filterOptions.map((option) {
                final isSelected = _selectedFilter == option;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (option == 'กำหนดเอง') {
                        _pickCustomRange();
                      } else {
                        setState(() => _selectedFilter = option);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(vertical: 8 * scale),
                      decoration: BoxDecoration(
                        color: isSelected ? primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isSelected
                            ? [BoxShadow(color: primary.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        option,
                        style: GoogleFonts.prompt(
                          fontSize: 12 * scale,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          SizedBox(height: 24 * scale),
          
          // Chart Area
          if (_isLoading)
            SizedBox(height: 180 * scale, child: const Center(child: CircularProgressIndicator(color: primary)))
          else
            SizedBox(
              height: 180 * scale,
              width: double.infinity,
              child: CustomPaint(painter: _TrendPainter(data.values, primary)),
            ),
            
          SizedBox(height: 12 * scale),
          
          // Labels
          Row(
            children: data.labels.map((label) {
              return Expanded(
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.prompt(
                      fontSize: 10 * scale,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 12 * scale),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(10 * scale),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'แกน X: ช่วงวันที่เกิดเหตุการณ์  •  แกน Y: จำนวนการแจ้งเตือน (ครั้ง)',
              textAlign: TextAlign.center,
              style: GoogleFonts.prompt(
                fontSize: 11 * scale,
                color: const Color(0xFF1D4ED8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskBreakdownHeader(_ChartData data, double scale) {
    final inclusiveEnd = data.end.subtract(const Duration(days: 1));
    final filteredCount = _alertsInRange(data).length;
    final rangeText =
        '${data.start.day}/${data.start.month}/${data.start.year + 543} - '
        '${inclusiveEnd.day}/${inclusiveEnd.month}/${inclusiveEnd.year + 543}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'รายละเอียดความเสี่ยง',
          style: GoogleFonts.prompt(
            fontSize: 18 * scale,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        SizedBox(height: 4 * scale),
        Text(
          'ข้อมูลตามตัวกรอง: $rangeText  •  รวม $filteredCount ครั้ง',
          style: GoogleFonts.prompt(
            fontSize: 12 * scale,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildRiskBreakdownGrid(Map<String, int> types, double scale) {
    if (types.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(32 * scale),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20 * scale),
        ),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 48 * scale, color: Colors.green),
            SizedBox(height: 12 * scale),
            Text(
              'ยอดเยี่ยม! ไม่พบความเสี่ยงในช่วงเวลานี้',
              textAlign: TextAlign.center,
              style: GoogleFonts.prompt(color: Colors.grey.shade600, fontSize: 14 * scale),
            ),
          ],
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12 * scale,
      crossAxisSpacing: 12 * scale,
      childAspectRatio: 1.15,
      padding: EdgeInsets.zero,
      children: types.entries.map((entry) => _buildBreakdownCard(entry.key, entry.value, scale)).toList(),
    );
  }

  Widget _buildBreakdownCard(String type, int count, double scale) {
    final meta = _alertMeta(type);
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: backgroundLight,
        borderRadius: BorderRadius.circular(20 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Icon Box
          Container(
            padding: EdgeInsets.all(10 * scale),
            decoration: BoxDecoration(
              color: meta.color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(meta.icon, color: meta.color, size: 24 * scale),
          ),
          
          // Texts
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                type,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.prompt(
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
              SizedBox(height: 2 * scale),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$count',
                    style: GoogleFonts.prompt(
                      fontSize: 20 * scale,
                      fontWeight: FontWeight.bold,
                      color: meta.color,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(width: 4 * scale),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      'ครั้ง',
                      style: GoogleFonts.prompt(
                        fontSize: 12 * scale,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError(double scale) {
    return Center(
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 48 * scale),
          SizedBox(height: 12 * scale),
          Text(_error!, style: GoogleFonts.prompt(color: Colors.red.shade700)),
          TextButton(
            onPressed: _loadAlerts,
            child: Text('ลองใหม่', style: GoogleFonts.prompt(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  _AlertMeta _alertMeta(String type) {
    switch (type) {
      case 'ง่วงนอน':
        return const _AlertMeta(Icons.bedtime_rounded, Color(0xFFEF4444));
      case 'เสียสมาธิ':
      case 'ไม่มองถนน':
        return const _AlertMeta(Icons.visibility_off_rounded, Color(0xFFF97316));
      case 'ใช้โทรศัพท์':
        return const _AlertMeta(Icons.phone_android_rounded, Color(0xFF8B5CF6));
      case 'ขับรถเร็ว':
        return const _AlertMeta(Icons.speed_rounded, Color(0xFF3B82F6));
      case 'เบรกกะทันหัน':
        return const _AlertMeta(Icons.warning_rounded, Color(0xFFEAB308));
      default:
        return const _AlertMeta(Icons.warning_amber_rounded, Colors.grey);
    }
  }
}

// --- Data Classes ---

class _ChartData {
  const _ChartData(this.labels, this.values, this.start, this.end);
  final List<String> labels;
  final List<int> values;
  final DateTime start;
  final DateTime end;
}

class _AlertMeta {
  const _AlertMeta(this.icon, this.color);
  final IconData icon;
  final Color color;
}

// --- Custom Painter for Chart ---

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.values, this.color);
  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // วาดเส้น Grid แนวนอน (พื้นหลัง)
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
      
    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      // วาดเป็นเส้นประ (Dashed line effect แบบง่ายๆ ทำโดยวาดเส้นตรงสีอ่อนบางๆ)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.isEmpty) return;

    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final maxY = maxValue == 0 ? 1 : maxValue;

    final slotWidth = size.width / values.length;
    final barWidth = (slotWidth * 0.56).clamp(6.0, 38.0).toDouble();
    const topSpace = 24.0;
    const bottomSpace = 4.0;
    final usableHeight = size.height - topSpace - bottomSpace;
    final barPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.82), color],
      ).createShader(Offset.zero & size);

    for (var i = 0; i < values.length; i++) {
      final centerX = slotWidth * i + slotWidth / 2;
      final height = values[i] == 0 ? 0.0 : (values[i] / maxY) * usableHeight;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - barWidth / 2,
          size.height - bottomSpace - height,
          barWidth,
          height,
        ),
        const Radius.circular(7),
      );
      canvas.drawRRect(rect, barPaint);

      final valueText = TextPainter(
        text: TextSpan(
          text: '${values[i]}',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      valueText.paint(
        canvas,
        Offset(
          centerX - valueText.width / 2,
          size.height - bottomSpace - height - valueText.height - 3,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => 
      old.values != values || old.color != color;
}
