import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_layout.dart';
import '/services/api_service.dart';
import '/services/media_upload_service.dart';
import 'utils/device_status.dart';

/// คลังเสียงแยกเป็น 2 ส่วนที่ไม่ยุ่งกัน (อัปโหลด/ลบ/เลือกใช้แยกอิสระ)
/// - event: การแจ้งเตือนรายครั้ง (ครั้งที่ 1–2)
/// - alert: เมื่อเปิดหน้า alert_screen และเมื่อหมดเวลาในโหมดพักรถ
enum _AudioScope { event, alert }

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
  String _eventTone = 'เสียงสัญญาณสั้น (Beep)';
  // ค่าที่บันทึกไว้บนเซิร์ฟเวอร์แล้ว ใช้เทียบว่ามีการเปลี่ยนที่ยังไม่บันทึกหรือไม่
  String _savedActiveTone = 'เสียงคลาสสิก (Classic)';
  String _savedEventTone = 'เสียงสัญญาณสั้น (Beep)';
  bool _isSavingActiveTone = false;
  bool _isSavingEventTone = false;
  bool _isLoadingSetting = true;
  bool _isSavingSetting = false;

  List<UploadedMedia> _audioTones = [];
  // mediaId ของไฟล์ที่ผู้ใช้เพิ่มในแต่ละส่วน (เก็บในเครื่อง แยกตามอุปกรณ์)
  final Set<String> _eventMediaIds = {};
  final Set<String> _alertMediaIds = {};
  bool _isLoadingAudio = true;
  bool _isUploadingAudio = false;
  String? _deletingAudioId;
  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _previewingAudioId;

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
    _loadInitialData();
    _previewPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _previewingAudioId = null);
    });
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleAudioPreview(String id, String url) async {
    try {
      if (_previewingAudioId == id) {
        await _previewPlayer.stop();
        if (mounted) setState(() => _previewingAudioId = null);
        return;
      }
      await _previewPlayer.stop();
      await _previewPlayer.play(UrlSource(url));
      if (mounted) setState(() => _previewingAudioId = id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _previewingAudioId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText('ไม่สามารถทดลองฟังไฟล์เสียงนี้ได้: $e')),
      );
    }
  }

  Future<void> _loadInitialData() async {
    await _fetchDeviceConfig();
    await _fetchAudioTones();
  }

  // ── การแบ่งไฟล์เสียงเป็นสองส่วน ─────────────────────────────────────────
  String _scopePrefsKey(_AudioScope scope) =>
      'device_audio_scope_${scope.name}_$_deviceId';

  List<UploadedMedia> get _eventTones =>
      _audioTones.where((a) => _eventMediaIds.contains(a.mediaId)).toList();

  List<UploadedMedia> get _alertTones =>
      _audioTones.where((a) => _alertMediaIds.contains(a.mediaId)).toList();

  List<UploadedMedia> _tonesOf(_AudioScope scope) =>
      scope == _AudioScope.event ? _eventTones : _alertTones;

  Future<void> _persistScopeAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _scopePrefsKey(_AudioScope.event),
      _eventMediaIds.toList(),
    );
    await prefs.setStringList(
      _scopePrefsKey(_AudioScope.alert),
      _alertMediaIds.toList(),
    );
  }

  /// โหลดว่าไฟล์ไหนอยู่ส่วนไหน ไฟล์เก่าที่ยังไม่เคยจัดกลุ่มจะถูกจัดให้ครั้งเดียว:
  /// ถ้าเป็นเสียงแจ้งเตือนรายครั้งที่ใช้อยู่ → ส่วนบน ที่เหลือ → ส่วนล่าง
  Future<void> _syncScopeAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    final eventIds = (prefs.getStringList(_scopePrefsKey(_AudioScope.event)) ??
            <String>[])
        .toSet();
    final alertIds = (prefs.getStringList(_scopePrefsKey(_AudioScope.alert)) ??
            <String>[])
        .toSet();

    final existingIds = _audioTones.map((a) => a.mediaId).toSet();
    var changed = false;
    final before = eventIds.length + alertIds.length;
    eventIds.removeWhere((id) => !existingIds.contains(id));
    alertIds.removeWhere((id) => !existingIds.contains(id));
    if (eventIds.length + alertIds.length != before) changed = true;

    // ค่า category จากเซิร์ฟเวอร์มาก่อนเสมอ เพื่อให้ทุกเครื่องเห็นตรงกัน
    for (final audio in _audioTones) {
      final category = audio.category;
      if (category == 'event' && !eventIds.contains(audio.mediaId)) {
        eventIds.add(audio.mediaId);
        alertIds.remove(audio.mediaId);
        changed = true;
      } else if (category == 'alert' && !alertIds.contains(audio.mediaId)) {
        alertIds.add(audio.mediaId);
        eventIds.remove(audio.mediaId);
        changed = true;
      }
    }

    // ไฟล์เก่าที่เซิร์ฟเวอร์ยังไม่มี category และยังไม่เคยจัดกลุ่มในเครื่องนี้
    for (final audio in _audioTones) {
      if (eventIds.contains(audio.mediaId) ||
          alertIds.contains(audio.mediaId)) {
        continue;
      }
      if (audio.fileName == _savedEventTone) {
        eventIds.add(audio.mediaId);
      } else {
        alertIds.add(audio.mediaId);
      }
      changed = true;
    }

    if (!mounted) return;
    setState(() {
      _eventMediaIds
        ..clear()
        ..addAll(eventIds);
      _alertMediaIds
        ..clear()
        ..addAll(alertIds);
    });
    if (changed) await _persistScopeAssignments();
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
          _eventTone = config['event_tone'] ?? 'เสียงสัญญาณสั้น (Beep)';
          _savedActiveTone = _activeTone;
          _savedEventTone = _eventTone;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText('ล้มเหลวในการอ่านการตั้งค่าปัจจุบัน: $e')),
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
        await _syncScopeAssignments();
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
        eventTone: _eventTone,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('บันทึกปรับแต่งฮาร์ดแวร์สำเร็จแล้ว')),
        );
        _returnToDeviceList();
      }
    } catch (e) {
      setState(() => _isSavingSetting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText('ไม่สามารถบันทึกได้: $e')));
    }
  }

  Future<void> _handleUploadAudio(_AudioScope scope) async {
    if (_tonesOf(scope).length >= _maxUploadedAudioTones) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(
            'อัปโหลดเสียงได้สูงสุด 5 เสียงต่อส่วน โดยไม่นับเสียงหลัก 3 เสียง',
          ),
        ),
      );
      return;
    }

    setState(() => _isUploadingAudio = true);
    try {
      final result = await MediaUploadService.instance.pickAndUploadAudio(
        deviceId: _deviceId,
        category: scope.name,
      );
      if (result != null) {
        // เพิ่มเข้าคลังเสียงเท่านั้น ไม่เลือกและไม่บันทึกให้อัตโนมัติ
        setState(() {
          _audioTones.insert(0, result);
          (scope == _AudioScope.event ? _eventMediaIds : _alertMediaIds).add(
            result.mediaId,
          );
        });
        await _persistScopeAssignments();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText(
              'อัปโหลดไฟล์เสียงสำเร็จแล้ว เลือกเสียงแล้วกดบันทึกเพื่อใช้งาน',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText('อัปโหลดไฟล์เสียงไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAudio = false);
    }
  }

  // ── helper: หาไฟล์/URL ของเสียงจากชื่อ ─────────────────────────────────
  UploadedMedia? _mediaForTone(String name) {
    for (final audio in _audioTones) {
      if (audio.fileName == name) return audio;
    }
    return null;
  }

  // ── บันทึกแยกของแต่ละส่วน ──────────────────────────────────────────────
  Future<void> _saveActiveTone() async {
    setState(() => _isSavingActiveTone = true);
    try {
      final media = _mediaForTone(_activeTone);
      if (media != null) {
        await MediaUploadService.instance.selectMedia(media.mediaId);
      }
      await ApiService.instance.upsertDeviceSetting(
        deviceId: _deviceId,
        volumeLevel: _volumeLevel.round(),
        soundEnabled: _soundEnabled,
        activeTone: _activeTone,
        eventTone: _savedEventTone,
      );
      if (!mounted) return;
      setState(() => _savedActiveTone = _activeTone);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('บันทึกเสียงระดับเสี่ยงสูงแล้ว')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText('บันทึกเสียงไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSavingActiveTone = false);
    }
  }

  Future<void> _saveEventTone() async {
    setState(() => _isSavingEventTone = true);
    try {
      await ApiService.instance.upsertDeviceSetting(
        deviceId: _deviceId,
        volumeLevel: _volumeLevel.round(),
        soundEnabled: _soundEnabled,
        activeTone: _savedActiveTone,
        eventTone: _eventTone,
      );
      if (!mounted) return;
      setState(() => _savedEventTone = _eventTone);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('บันทึกเสียงแจ้งเตือนทั่วไปแล้ว')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText('บันทึกเสียงไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSavingEventTone = false);
    }
  }

  Widget _buildSaveButton({
    required String label,
    required bool dirty,
    required bool saving,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: (dirty && !saving) ? onPressed : null,
        icon: saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(dirty ? Icons.save_outlined : Icons.check_rounded, size: 18),
        label: AppText(dirty ? label : 'บันทึกแล้ว'),
      ),
    );
  }

  Future<void> _confirmDeleteAudio(UploadedMedia audio) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('ลบไฟล์เสียง'),
        content: AppText(
          'ต้องการลบ “${audio.fileName}” หรือไม่?\n\nไฟล์จะถูกลบออกจากฐานข้อมูลและ Supabase อย่างถาวร',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const AppText('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const AppText('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingAudioId = audio.mediaId);
    final wasSelected = _activeTone == audio.fileName || audio.isActive;
    final wasEventTone = _eventTone == audio.fileName;

    try {
      if (_previewingAudioId == audio.mediaId) {
        await _previewPlayer.stop();
        _previewingAudioId = null;
      }
      await MediaUploadService.instance.deleteMedia(audio.mediaId);
      if (!mounted) return;

      final savedActiveWasDeleted = _savedActiveTone == audio.fileName;
      final savedEventWasDeleted = _savedEventTone == audio.fileName;
      setState(() {
        _audioTones.removeWhere((item) => item.mediaId == audio.mediaId);
        _eventMediaIds.remove(audio.mediaId);
        _alertMediaIds.remove(audio.mediaId);
        if (wasSelected) {
          _activeTone = 'เสียงคลาสสิก (Classic)';
        }
        if (wasEventTone) {
          _eventTone = 'เสียงสัญญาณสั้น (Beep)';
        }
        if (savedActiveWasDeleted) _savedActiveTone = 'เสียงคลาสสิก (Classic)';
        if (savedEventWasDeleted) _savedEventTone = 'เสียงสัญญาณสั้น (Beep)';
      });
      await _persistScopeAssignments();
      if (savedActiveWasDeleted || savedEventWasDeleted) {
        try {
          await ApiService.instance.upsertDeviceSetting(
            deviceId: _deviceId,
            volumeLevel: _volumeLevel.round(),
            soundEnabled: _soundEnabled,
            activeTone: _savedActiveTone,
            eventTone: _savedEventTone,
          );
        } catch (e) {
          debugPrint('บันทึกเสียงเริ่มต้นหลังลบไม่สำเร็จ: $e');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
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
      ).showSnackBar(SnackBar(content: AppText('ลบไฟล์เสียงไม่สำเร็จ: $e')));
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
        title: AppText(
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
                      title: "เสียงแจ้งเตือนรายครั้ง (ครั้งที่ 1–2)",
                      subtitle:
                          "เล่นทุกครั้งที่ตรวจพบพฤติกรรมเสี่ยง ลบได้เฉพาะเสียงที่คุณเพิ่มเอง",
                    ),
                    const SizedBox(height: 12),
                    _buildEventToneSelector(),
                    const SizedBox(height: 16),
                    _buildSectionTitle(
                      icon: Icons.warning_amber_rounded,
                      title: "เสียงเมื่อเปิดหน้าแจ้งเตือน / หมดเวลาพักรถ",
                      subtitle:
                          "เล่นเมื่อเปิดหน้า Alert และเมื่อหมดเวลาในโหมดพักรถ",
                    ),
                    const SizedBox(height: 12),
                    _buildToneListCard(
                      tones: _alertTones,
                      selectedTone: _activeTone,
                      onSelect: (tone) => setState(() => _activeTone = tone),
                    ),
                    const SizedBox(height: 12),
                    _buildSaveButton(
                      label: 'บันทึกเสียงหน้าแจ้งเตือน / หมดเวลาพักรถ',
                      dirty: _activeTone != _savedActiveTone,
                      saving: _isSavingActiveTone,
                      onPressed: _saveActiveTone,
                    ),
                    const SizedBox(height: 20),
                    _buildUploadCard(_AudioScope.alert),
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
                                  AppText(
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
                AppText(
                  widget.deviceData['device_name'] ?? 'ไม่ระบุชื่อ',
                  style: GoogleFonts.prompt(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                AppText(
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
                AppText(
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
              AppText(
                title,
                style: GoogleFonts.prompt(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cFF0F2557,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                AppText(
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
  Widget _buildToneListCard({
    required List<UploadedMedia> tones,
    required String selectedTone,
    required ValueChanged<String> onSelect,
  }) {
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
            selectedTone: selectedTone,
            onSelect: onSelect,
            previewUrl:
                'https://krzpmhifnpbstikhnbpf.supabase.co/storage/v1/object/public/driver-images/default-audio/classic.mp3',
          ),
          const SizedBox(height: 10),
          _buildToneOption(
            'เสียงสัญญาณสั้น (Beep)',
            icon: Icons.notifications_active_rounded,
            selectedTone: selectedTone,
            onSelect: onSelect,
            previewUrl:
                'https://krzpmhifnpbstikhnbpf.supabase.co/storage/v1/object/public/driver-images/default-audio/beep.mp3',
          ),
          const SizedBox(height: 10),
          _buildToneOption(
            'เสียงแจ้งเตือนไซเรน (Siren)',
            icon: Icons.warning_amber_rounded,
            selectedTone: selectedTone,
            onSelect: onSelect,
            previewUrl:
                'https://krzpmhifnpbstikhnbpf.supabase.co/storage/v1/object/public/driver-images/default-audio/siren.mp3',
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
          ] else if (tones.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade200)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: AppText(
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
            ...tones.map(
              (audio) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildToneOption(
                  audio.fileName,
                  selectedTone: selectedTone,
                  onSelect: onSelect,
                  icon: Icons.audiotrack_rounded,
                  mediaId: audio.mediaId,
                  previewUrl: audio.url,
                  fileSizeBytes: audio.fileSizeBytes,
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

  Widget _buildEventToneSelector() {
    return Column(
      children: [
        _buildToneListCard(
          tones: _eventTones,
          selectedTone: _eventTone,
          onSelect: (tone) => setState(() => _eventTone = tone),
        ),
        const SizedBox(height: 12),
        _buildUploadCard(_AudioScope.event),
        const SizedBox(height: 12),
        _buildSaveButton(
          label: 'บันทึกเสียงแจ้งเตือนทั่วไป',
          dirty: _eventTone != _savedEventTone,
          saving: _isSavingEventTone,
          onPressed: _saveEventTone,
        ),
      ],
    );
  }

  Widget _buildToneOption(
    String title, {
    required String selectedTone,
    required ValueChanged<String> onSelect,
    required IconData icon,
    String? mediaId,
    String? previewUrl,
    int? fileSizeBytes,
    VoidCallback? onDelete,
  }) {
    final isSelected = selectedTone == title;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      // แค่เลือกในหน้าจอ ยังไม่บันทึกจนกว่าจะกดปุ่มบันทึก
      onTap: () => onSelect(title),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.prompt(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? AppColors.cFF0F2557
                          : Colors.grey.shade800,
                    ),
                  ),
                  if (fileSizeBytes != null)
                    AppText(
                      '${(fileSizeBytes / 1024 / 1024).toStringAsFixed(2)} MB',
                      style: GoogleFonts.prompt(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            if (previewUrl != null)
              IconButton(
                tooltip: appTr(
                  _previewingAudioId == (mediaId ?? title)
                      ? 'หยุด'
                      : 'ทดลองฟัง',
                ),
                onPressed: () =>
                    _toggleAudioPreview(mediaId ?? title, previewUrl),
                icon: Icon(
                  _previewingAudioId == (mediaId ?? title)
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline_rounded,
                  color: AppColors.cFF0F2557,
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
                tooltip: appTr('ลบไฟล์เสียง'),
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
  Widget _buildUploadCard(_AudioScope scope) {
    final scopeCount = _tonesOf(scope).length;
    final hasReachedAudioLimit = scopeCount >= _maxUploadedAudioTones;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _isUploadingAudio ? null : () => _handleUploadAudio(scope),
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
            AppText(
              _isUploadingAudio
                  ? "กำลังอัปโหลด..."
                  : hasReachedAudioLimit
                  ? "อัปโหลดครบ 5/5 เสียงแล้ว"
                  : "อัปโหลดเสียงใหม่ ($scopeCount/$_maxUploadedAudioTones)",
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
  //     //       child: AppText(
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