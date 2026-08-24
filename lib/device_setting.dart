import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main_layout.dart';
import '/services/api_service.dart';
import '/services/media_upload_service.dart';
import 'utils/device_status.dart';

class DeviceCustomizationScreen extends StatefulWidget {
  final Map<String, dynamic> deviceData;
  const DeviceCustomizationScreen({super.key, required this.deviceData});

  @override
  State<DeviceCustomizationScreen> createState() =>
      _DeviceCustomizationScreenState();
}

class _DeviceCustomizationScreenState extends State<DeviceCustomizationScreen> {
  static const int _maxUploadedAudioTones = 5;

  // ── Theme (คงชุดสีเดิมของแอปไว้ทั้งหมด) ─────────────────────────────
  bool _soundEnabled = true;
  double _volumeLevel = 75.0;
  String _activeTone = 'เสียงคลาสสิก (Classic)';
  bool _isLoadingSetting = true;
  bool _isSavingSetting = false;

  List<UploadedMedia> _audioTones = [];
  bool _isLoadingAudio = true;
  bool _isUploadingAudio = false;
  String? _deletingAudioId;

  String get _deviceId => widget.deviceData['device_id'].toString();

  bool get _isOnline => isDeviceOnline(widget.deviceData);

  void _returnToDeviceList() {
    // The settings page was pushed from the device tab. Pop to preserve the
    // MainLayout and its bottom navigation instead of creating a bare screen.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainLayout(initialIndex: 3)),
      (route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchDeviceConfig();
    _fetchAudioTones();
  }

  Future<void> _fetchDeviceConfig() async {
    try {
      final config = await ApiService.instance.deviceSetting(
        widget.deviceData['device_id'],
      );
      if (config != null) {
        setState(() {
          _soundEnabled =
              config['sound_enabled'] == 1 || config['sound_enabled'] == true;
          final rawVolume = config['volume_level'];
          _volumeLevel = rawVolume is num
              ? rawVolume.toDouble()
              : double.tryParse(rawVolume?.toString() ?? '75') ?? 75.0;
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
      final list = await MediaUploadService.instance.fetchDeviceMedia(
        _deviceId,
      );
      if (mounted) {
        setState(
          () => _audioTones = list
              .where((m) => m.type == 'audio' && !m.isDefault)
              .toList(),
        );
      }
    } catch (e) {
      debugPrint('โหลดรายการไฟล์เสียงไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAudio = false);
    }
  }

  Future<void> _saveAllSettings() async {
    setState(() => _isSavingSetting = true);
    try {
      await ApiService.instance.updateDeviceSettings(
        deviceId: widget.deviceData['device_id'],
        volumeLevel: _volumeLevel.toInt(),
        soundEnabled: _soundEnabled,
        activeTone: _activeTone,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกปรับแต่งฮาร์ดแวร์สำเร็จแล้ว')),
        );
        _returnToDeviceList();
      }
    } catch (e) {
      setState(() => _isSavingSetting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ไม่สามารถบันทึกได้: $e')));
    }
  }

  Future<void> _handleUploadAudio() async {
    if (_audioTones.length >= _maxUploadedAudioTones) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'อัปโหลดเสียงได้สูงสุด 5 เสียงต่ออุปกรณ์ โดยไม่นับเสียงหลัก 3 เสียง',
          ),
        ),
      );
      return;
    }

    setState(() => _isUploadingAudio = true);
    try {
      final result = await MediaUploadService.instance.pickAndUploadAudio(
        deviceId: _deviceId,
      );
      if (result != null) {
        setState(() {
          _audioTones.insert(0, result);
          _activeTone = result.fileName;
        });
        try {
          await MediaUploadService.instance.selectMedia(result.mediaId);
        } catch (e) {
          debugPrint('ตั้งเสียงที่เพิ่งอัปโหลดเป็นเสียงใช้งานไม่สำเร็จ: $e');
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'อัปโหลดไฟล์เสียงสำเร็จแล้ว และตั้งเป็นเสียงที่ใช้งานให้อัตโนมัติ',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('อัปโหลดไฟล์เสียงไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingAudio = false);
    }
  }

  Future<void> _confirmDeleteAudio(UploadedMedia audio) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ลบไฟล์เสียง'),
        content: Text(
          'ต้องการลบ “${audio.fileName}” หรือไม่?\n\nไฟล์จะถูกลบออกจากฐานข้อมูลและ Supabase อย่างถาวร',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingAudioId = audio.mediaId);
    final wasSelected = _activeTone == audio.fileName || audio.isActive;

    try {
      await MediaUploadService.instance.deleteMedia(audio.mediaId);
      if (!mounted) return;

      setState(() {
        _audioTones.removeWhere((item) => item.mediaId == audio.mediaId);
        if (wasSelected) {
          _activeTone = 'เสียงคลาสสิก (Classic)';
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasSelected
                ? 'ลบไฟล์เสียงแล้ว และเปลี่ยนกลับเป็นเสียง Classic'
                : 'ลบไฟล์เสียงสำเร็จ',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ลบไฟล์เสียงไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _deletingAudioId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cFFF6F8FA,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.cFF0F2557,
            size: 22,
          ),
          onPressed: () {
            _returnToDeviceList();
          },
        ),
        title: Text(
          "การตั้งค่าอุปกรณ์",
          style: GoogleFonts.prompt(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.cFF0F2557,
          ),
        ),
      ),
      body: _isLoadingSetting
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.cFF0F2557),
            )
          : RefreshIndicator(
              color: AppColors.cFF0F2557,
              onRefresh: () async {
                await _fetchDeviceConfig();
                await _fetchAudioTones();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildActiveDeviceHeader(),
                    const SizedBox(height: 24),
                    _buildSectionTitle(
                      icon: Icons.graphic_eq_rounded,
                      title: "เสียงสัญญาณอินเตอร์คอม",
                      subtitle:
                          "เลือกเสียงที่จะใช้แจ้งเตือนเมื่อระบบตรวจพบความเสี่ยง",
                    ),
                    const SizedBox(height: 12),
                    _buildSoundPreferences(),
                    const SizedBox(height: 20),
                    _buildUploadCard(),
                    // const SizedBox(height: 20),
                    // _buildInfoNoteCard(),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSavingSetting ? null : _saveAllSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cFF0F2557,
                          elevation: 3,
                          shadowColor: AppColors.cFF0F2557.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSavingSetting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.save_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "บันทึกการตั้งค่าทั้งหมด",
                                    style: GoogleFonts.prompt(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
    );
  }

  // ── ส่วนหัว: การ์ดแสดงข้อมูลอุปกรณ์ + สถานะออนไลน์/ออฟไลน์ ─────────────
  Widget _buildActiveDeviceHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cFF0F2557, AppColors.cFF3B5998],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.cFF0F2557.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.developer_board_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.deviceData['device_name'] ?? 'ไม่ระบุชื่อ',
                  style: GoogleFonts.prompt(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'S/N: ${widget.deviceData['serial_number'] ?? '-'}',
                  style: GoogleFonts.prompt(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (_isOnline ? AppColors.cFF4ADE80 : AppColors.cFF9CA3AF)
                  .withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (_isOnline ? AppColors.cFF4ADE80 : AppColors.cFF9CA3AF)
                    .withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isOnline
                        ? AppColors.cFF4ADE80
                        : AppColors.cFF9CA3AF,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isOnline ? "ออนไลน์" : "ออฟไลน์",
                  style: GoogleFonts.prompt(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.cFFE8EFFD,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.cFF0F2557, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.prompt(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cFF0F2557,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.prompt(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── รายการเสียง: การ์ดเลือกได้ พร้อมไฮไลต์ตัวที่ถูกเลือก ──────────────
  Widget _buildSoundPreferences() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildToneOption(
            'เสียงคลาสสิก (Classic)',
            icon: Icons.music_note_rounded,
          ),
          const SizedBox(height: 10),
          _buildToneOption(
            'เสียงสัญญาณสั้น (Beep)',
            icon: Icons.notifications_active_rounded,
          ),
          const SizedBox(height: 10),
          _buildToneOption(
            'เสียงแจ้งเตือนไซเรน (Siren)',
            icon: Icons.warning_amber_rounded,
          ),

          if (_isLoadingAudio) ...[
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.cFF0F2557,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ] else if (_audioTones.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade200)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      "เสียงที่คุณอัปโหลดเอง",
                      style: GoogleFonts.prompt(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade200)),
                ],
              ),
            ),
            ..._audioTones.map(
              (audio) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildToneOption(
                  audio.fileName,
                  icon: Icons.audiotrack_rounded,
                  mediaId: audio.mediaId,
                  onDelete: _deletingAudioId == audio.mediaId
                      ? null
                      : () => _confirmDeleteAudio(audio),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToneOption(
    String title, {
    required IconData icon,
    String? mediaId,
    VoidCallback? onDelete,
  }) {
    final isSelected = _activeTone == title;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        setState(() => _activeTone = title);
        if (mediaId != null) {
          try {
            await MediaUploadService.instance.selectMedia(mediaId);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('เลือกไฟล์เสียงไม่สำเร็จ: $e')),
              );
            }
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cFFE8EFFD : AppColors.cFFF6F8FA,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.cFF0F2557 : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.cFF0F2557 : Colors.white,
                shape: BoxShape.circle,
                border: isSelected
                    ? null
                    : Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey.shade500,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.prompt(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? AppColors.cFF0F2557
                      : Colors.grey.shade800,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.cFF0F2557,
                size: 20,
              )
            else if (onDelete == null)
              Icon(
                Icons.circle_outlined,
                color: Colors.grey.shade300,
                size: 20,
              ),
            if (onDelete != null) ...[
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'ลบไฟล์เสียง',
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                  size: 21,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── การ์ดอัปโหลดเสียงใหม่ ──────────────────────────────────────────────
  Widget _buildUploadCard() {
    final hasReachedAudioLimit = _audioTones.length >= _maxUploadedAudioTones;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _isUploadingAudio ? null : _handleUploadAudio,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.cFF0F2557.withOpacity(0.3),
            width: 1.4,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isUploadingAudio
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.cFF0F2557,
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.cFFE8EFFD,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.upload_file_rounded,
                      color: AppColors.cFF0F2557,
                      size: 20,
                    ),
                  ),
            const SizedBox(width: 12),
            Text(
              _isUploadingAudio
                  ? "กำลังอัปโหลด..."
                  : hasReachedAudioLimit
                  ? "อัปโหลดครบ 5/5 เสียงแล้ว"
                  : "อัปโหลดเสียงใหม่ (${_audioTones.length}/$_maxUploadedAudioTones)",
              style: GoogleFonts.prompt(
                color: AppColors.cFF0F2557,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── การ์ดคำแนะนำ เติมพื้นที่ว่าง + ให้ข้อมูลที่เป็นประโยชน์กับผู้ใช้ ─────
  // Widget _buildInfoNoteCard() {
  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: AppColors.cFFE8EFFD.withOpacity(0.6),
  //       borderRadius: BorderRadius.circular(16),
  //     ),
  //     // child: Row(
  //     //   crossAxisAlignment: CrossAxisAlignment.start,
  //     //   children: [
  //     //     const Icon(Icons.info_outline_rounded, color: AppColors.cFF0F2557, size: 20),
  //     //     const SizedBox(width: 12),
  //     //     Expanded(
  //     //       child: Text(
  //     //         "เสียงที่เลือกไว้จะถูกเล่นจากตัวอุปกรณ์โดยตรงเมื่อระบบตรวจพบความเสี่ยงขณะขับขี่ "
  //     //         "คุณสามารถอัปโหลดเสียงของตัวเองหรือเลือกจากเสียงสำเร็จรูปด้านบนได้ตลอดเวลา",
  //     //         style: GoogleFonts.prompt(
  //     //           fontSize: 12.5,
  //     //           color: AppColors.cFF0F2557.withOpacity(0.85),
  //     //           height: 1.5,
  //     //         ),
  //     //       ),
  //     //     ),
  //     //   ],
  //     // ),
  //   );
  // }
}
