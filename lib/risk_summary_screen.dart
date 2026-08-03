import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

import 'menu/custom_bottom_nav_bar.dart';
import 'services/api_service.dart';

class RiskTrendsScreen extends StatefulWidget {
  const RiskTrendsScreen({super.key});

  @override
  State<RiskTrendsScreen> createState() => _RiskTrendsScreenState();
}

class _RiskTrendsScreenState extends State<RiskTrendsScreen> {
  static const primary = AppColors.cFF0F2557;
  static const backgroundLight = Colors.white;
  static const backgroundOffwhite = AppColors.cFFF6F8FA;

  int _currentIndex = 1;
  String _selectedFilter = 'รายเดือน';
  final _filterOptions = const ['รายสัปดาห์', 'รายเดือน', 'รายปี'];
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

  DateTime? _alertTime(Map<String, dynamic> alert) {
    final value = alert['timestamp'] ?? alert['created_at'];
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  DateTime _day(DateTime time) => DateTime(time.year, time.month, time.day);

  _ChartData _chartData() {
    final now = DateTime.now();
    final labels = <String>[];
    final starts = <DateTime>[];
    final ends = <DateTime>[];
    if (_selectedFilter == 'รายสัปดาห์') {
      final today = _day(now);
      for (var i = 6; i >= 0; i--) {
        final start = today.subtract(Duration(days: i));
        starts.add(start); ends.add(start.add(const Duration(days: 1)));
        labels.add(const ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'][start.weekday - 1]);
      }
    } else if (_selectedFilter == 'รายเดือน') {
      final end = _day(now).add(const Duration(days: 1));
      for (var i = 4; i >= 0; i--) {
        final start = end.subtract(Duration(days: (i + 1) * 7));
        starts.add(start); ends.add(start.add(const Duration(days: 7)));
        labels.add('สัปดาห์ ${5 - i}');
      }
    } else {
      for (var i = 11; i >= 0; i--) {
        final start = DateTime(now.year, now.month - i, 1);
        starts.add(start); ends.add(DateTime(start.year, start.month + 1, 1));
        labels.add('${start.month}/${(start.year % 100).toString().padLeft(2, '0')}');
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
    for (final alert in _alerts) {
      final time = _alertTime(alert);
      if (time == null || time.isBefore(data.start) || !time.isBefore(data.end)) continue;
      final type = (alert['type']?.toString().trim().isNotEmpty ?? false)
          ? alert['type'].toString() : 'ไม่ระบุประเภท';
      result[type] = (result[type] ?? 0) + 1;
    }
    final entries = result.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries);
  }

  @override
  Widget build(BuildContext context) {
    final chart = _chartData();
    return Scaffold(
      backgroundColor: backgroundOffwhite,
      appBar: AppBar(
        backgroundColor: backgroundLight, elevation: 0, centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: primary), onPressed: () => Navigator.pop(context)),
        title: Text('แนวโน้มความเสี่ยง', style: GoogleFonts.prompt(fontSize: 18, fontWeight: FontWeight.bold, color: primary)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded, color: primary), onPressed: _isLoading ? null : _loadAlerts)],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAlerts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildTrendChart(chart), const SizedBox(height: 24),
            _buildRiskBreakdownHeader(), const SizedBox(height: 16),
            if (_isLoading) const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_error != null) _buildError()
            else _buildRiskBreakdownGrid(_breakdown(chart)),
            const SizedBox(height: 32),
          ]),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(currentIndex: _currentIndex, onTap: (index) => setState(() => _currentIndex = index)),
    );
  }

  Widget _buildTrendChart(_ChartData data) => Container(
    padding: const EdgeInsets.all(24), decoration: _cardDecoration(24),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('ภาพรวมแนวโน้ม', style: GoogleFonts.prompt(fontSize: 16, fontWeight: FontWeight.bold, color: primary)),
        DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: _selectedFilter, isDense: true, icon: const Icon(Icons.keyboard_arrow_down_rounded, color: primary),
          style: GoogleFonts.prompt(fontSize: 12, fontWeight: FontWeight.w600, color: primary),
          onChanged: (value) => value == null ? null : setState(() => _selectedFilter = value),
          items: _filterOptions.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
        )),
      ]),
      const SizedBox(height: 20),
      if (_isLoading) const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())) else SizedBox(height: 180, width: double.infinity, child: CustomPaint(painter: _TrendPainter(data.values, primary))),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: data.labels.map((label) => Flexible(child: Text(label, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: GoogleFonts.prompt(fontSize: 10, color: Colors.grey.shade600)))).toList()),
    ]),
  );

  Widget _buildRiskBreakdownHeader() => Text('รายละเอียดความเสี่ยง', style: GoogleFonts.prompt(fontSize: 16, fontWeight: FontWeight.bold, color: primary));

  Widget _buildRiskBreakdownGrid(Map<String, int> types) {
    if (types.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('ไม่พบ Alert ในช่วงเวลานี้', style: GoogleFonts.prompt(color: Colors.grey.shade600))));
    return GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.2,
      children: types.entries.map((entry) => _buildBreakdownCard(entry.key, entry.value)).toList());
  }

  Widget _buildBreakdownCard(String type, int count) {
    final meta = _alertMeta(type);
    return Container(padding: const EdgeInsets.all(16), decoration: _cardDecoration(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: (meta.color as Color).withOpacity(.12), borderRadius: BorderRadius.circular(10)), child: Icon(meta.icon as IconData, color: meta.color as Color)),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(type, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.prompt(fontSize: 14, fontWeight: FontWeight.bold, color: primary)), const SizedBox(height: 2), Text('$count ครั้ง', style: GoogleFonts.prompt(fontSize: 12, color: Colors.grey.shade600))]),
    ]));
  }

  Widget _buildError() => Center(child: Column(children: [Text(_error!, style: GoogleFonts.prompt(color: Colors.red.shade700)), TextButton(onPressed: _loadAlerts, child: const Text('ลองใหม่'))]));

  BoxDecoration _cardDecoration(double radius) => BoxDecoration(color: backgroundLight, borderRadius: BorderRadius.circular(radius), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 10, offset: const Offset(0, 2))]);

  _AlertMeta _alertMeta(String type) {
    switch (type) {
      case 'ง่วงนอน': return const _AlertMeta(Icons.bedtime_rounded, Colors.red);
      case 'เสียสมาธิ': case 'ไม่มองถนน': return const _AlertMeta(Icons.visibility_off_rounded, Colors.orange);
      case 'ใช้โทรศัพท์': return const _AlertMeta(Icons.phone_android_rounded, Colors.deepPurple);
      case 'ขับรถเร็ว': return const _AlertMeta(Icons.speed_rounded, Colors.blue);
      case 'เบรกกะทันหัน': return const _AlertMeta(Icons.warning_rounded, Colors.amber);
      default: return const _AlertMeta(Icons.warning_amber_rounded, Colors.grey);
    }
  }
}

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

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.values, this.color);
  final List<int> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = Colors.grey.shade300..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) { final y = size.height * i / 4; canvas.drawLine(Offset(0, y), Offset(size.width, y), grid); }
    if (values.isEmpty) return;
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final maxY = maxValue == 0 ? 1 : maxValue;
    final points = <Offset>[for (var i = 0; i < values.length; i++) Offset(values.length == 1 ? size.width / 2 : size.width * i / (values.length - 1), size.height - (values[i] / maxY) * (size.height - 16) - 8)];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) { path.lineTo(point.dx, point.dy); }
    final fill = Path.from(path)..lineTo(points.last.dx, size.height)..lineTo(points.first.dx, size.height)..close();
    canvas.drawPath(fill, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withOpacity(.22), color.withOpacity(0)]).createShader(Offset.zero & size));
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    for (final point in points) { canvas.drawCircle(point, 4, Paint()..color = Colors.white); canvas.drawCircle(point, 4, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2); }
  }
  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.values != values || old.color != color;
}
