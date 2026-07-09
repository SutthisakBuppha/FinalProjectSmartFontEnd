import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'devices_screen.dart';
import '/services/api_service.dart';
import '/services/media_upload_service.dart';

class DeviceCustomizationScreen extends StatefulWidget {
  final Map<String, dynamic> deviceData;
  const DeviceCustomizationScreen({super.key, required this.deviceData});

  @override
  State<DeviceCustomizationScreen> createState() => _DeviceCustomizationScreenState();
}

class _DeviceCustomizationScreenState extends State<DeviceCustomizationScreen> {
  static const Color primaryColor = Color(0xFF0F2557);
  static const Color bgLight = Color(0xFFFFFFFF);
  static const Color bgOffwhite = Color(0xFFF6F8FA);
  static const Color accentBlue = Color(0xFFE8EFFD);
  static const Color accentBlueDark = Color(0xFF1A3A75);

  bool _soundEnabled = true;
  double _volumeLevel = 75.0;
  String _activeTone = 'เสียงคลาสสิก (Classic)';
  bool _isLoadingSetting = true;
  bool _isSavingSetting = false;

  // ---- ส่วนอัปโหลดไฟล์เสียง (เสียงที่ผู้ใช้อัปโหลดเอง เพิ่มเป็นตัวเลือกควบคู่กับเสียงสำเร็จรูป) ----
  List<UploadedMedia> _audioTones = [];
  bool _isLoadingAudio = true;
  bool _isUploadingAudio = false;

  String get _deviceId => widget.deviceData['device_id'].toString();

  @override
  void initState() {
    super.initState();
    _fetchDeviceConfig();
    _fetchAudioTones();
  }

  Future<void> _fetchDeviceConfig() async {
    try {
      final config = await ApiService.instance.deviceSetting(widget.deviceData['device_id']);
      if (config != null) {
        setState(() {
          _soundEnabled = config['sound_enabled'] == 1 || config['sound_enabled'] == true;
          _volumeLevel = (config['volume_level'] ?? 75).toDouble();
          _activeTone = config['active_tone'] ?? 'เสียงคลาสสิก (Classic)';
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ล้มเหลวในการอ่านการตั้งค่าปัจจุบัน: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoadingSetting = false);
    }
  }

  Future<void> _fetchAudioTones() async {
    setState(() => _isLoadingAudio = true);
    try {
      final list = await MediaUploadService.instance.fetchDeviceMedia(_deviceId);
      // กรองเอาเฉพาะไฟล์เสียงจากรายการสื่อทั้งหมดของอุปกรณ์
      if (mounted) {
        setState(() => _audioTones = list.where((m) => m.type == 'audio').toList());
      }
    } catch (e) {
      // ไม่ต้องโชว์ error รบกวนผู้ใช้ตอนโหลดครั้งแรก แค่ log ไว้พอ
      debugPrint('โหลดรายการไฟล์เสียงไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAudio = false);
    }
  }

  Future<void> _saveAllSettings() async {
    setState(() => _isSavingSetting = true);
    try {
      await ApiService.instance.saveDeviceSetting(
        deviceId: widget.deviceData['device_id'],
        volumeLevel: _volumeLevel.toInt(),
        soundEnabled: _soundEnabled,
        activeTone: _activeTone,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกปรับแต่งฮาร์ดแวร์สำเร็จแล้ว')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DeviceManagementScreen()),
        );
      }
    } catch (e) {
      setState(() => _isSavingSetting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถบันทึกได้: $e')),
      );
    }
  }

  // ---------------------------------------------------------------------
  // เลือกไฟล์เสียงจากเครื่อง -> อัปโหลด -> เพิ่มเป็นตัวเลือกเสียงเพิ่มเติม
  // หมายเหตุ: ปรับชื่อเมธอด pickAndUploadAudio ให้ตรงกับที่มีจริงใน
  // MediaUploadService ของโปรเจกต์คุณ (ยังไม่เห็นไฟล์ media_upload_service.dart
  // ตอนแก้ไขนี้ จึงอ้างอิงชื่อเมธอดตามรูปแบบเดียวกับ pickCompressAndUploadImage/Video เดิม)
  // ---------------------------------------------------------------------
  Future<void> _handleUploadAudio() async {
    setState(() => _isUploadingAudio = true);
    try {
      final result = await MediaUploadService.instance.pickAndUploadAudio(
        deviceId: _deviceId,
      );
      if (result != null) {
        setState(() => _audioTones.insert(0, result));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปโหลดไฟล์เสียงสำเร็จแล้ว')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อัปโหลดไฟล์เสียงไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAudio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgOffwhite,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: primaryColor, size: 22),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DeviceManagementScreen()),
            );
          },
        ),
        title: Text(
          "การตั้งค่าอุปกรณ์",
          style: GoogleFonts.notoSansThai(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
        ),
      ),
      body: _isLoadingSetting
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildActiveDeviceHeader(),
                  const SizedBox(height: 32),
                  _buildSoundPreferences(),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSavingSetting ? null : _saveAllSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSavingSetting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text("บันทึกการตั้งค่าทั้งหมด", style: GoogleFonts.notoSansThai(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                ],
              ),
            ),
    );
  }

  Widget _buildActiveDeviceHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.developer_board, color: primaryColor, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.deviceData['device_name'] ?? 'ไม่ระบุชื่อ', style: GoogleFonts.notoSansThai(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor)),
                Text('S/N: ${widget.deviceData['serial_number'] ?? '-'}', style: GoogleFonts.notoSansThai(color: Colors.grey, fontSize: 13)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSoundPreferences() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("เปิดใช้งานเสียงระบบ", style: GoogleFonts.notoSansThai(fontSize: 16, fontWeight: FontWeight.bold)),
              CupertinoSwitch(
                value: _soundEnabled,
                onChanged: (val) => setState(() => _soundEnabled = val),
              )
            ],
          ),
          if (_soundEnabled) ...[
            const Divider(height: 32),
            Text("ระดับเสียงแจ้งเตือน (${_volumeLevel.toInt()}%)", style: GoogleFonts.notoSansThai(fontSize: 14)),
            Slider(
              value: _volumeLevel,
              min: 0,
              max: 100,
              activeColor: primaryColor,
              onChanged: (val) => setState(() => _volumeLevel = val),
            ),
            const Divider(height: 32),
            Text("เลือกเสียงสัญญาณอินเตอร์คอม", style: GoogleFonts.notoSansThai(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildToneOption('เสียงคลาสสิก (Classic)'),
            _buildToneOption('เสียงสัญญาณสั้น (Beep)'),
            _buildToneOption('เสียงแจ้งเตือนไซเรน (Siren)'),

            // ── เสียงที่ผู้ใช้อัปโหลดเอง (เพิ่มเติมจากเสียงสำเร็จรูปด้านบน) ──
            if (_isLoadingAudio) ...[
              const SizedBox(height: 12),
              const Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                ),
              ),
            ] else
              ..._audioTones.map((audio) => _buildToneOption(audio.fileName)),

            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isUploadingAudio ? null : _handleUploadAudio,
                icon: _isUploadingAudio
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                      )
                    : const Icon(Icons.audiotrack_outlined, color: primaryColor, size: 20),
                label: Text(
                  "อัปโหลดไฟล์เสียงใหม่",
                  style: GoogleFonts.notoSansThai(color: primaryColor, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildToneOption(String title) {
    final isSelected = _activeTone == title;
    return RadioListTile<String>(
      title: Text(title, style: GoogleFonts.notoSansThai(fontSize: 14)),
      value: title,
      groupValue: _activeTone,
      activeColor: primaryColor,
      contentPadding: EdgeInsets.zero,
      onChanged: (val) {
        if (val != null) setState(() => _activeTone = val);
      },
    );
  }

}