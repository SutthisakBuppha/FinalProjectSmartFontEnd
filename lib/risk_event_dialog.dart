import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/api_service.dart';
import 'services/media_upload_service.dart';
import 'services/language_service.dart';
import 'theme/app_theme.dart';

class RiskEventDialog extends StatefulWidget {
  const RiskEventDialog({
    super.key,
    required this.deviceId,
    required this.type,
    required this.eventCount,
  });

  final String deviceId;
  final String type;
  final int eventCount;

  @override
  State<RiskEventDialog> createState() => _RiskEventDialogState();
}

class _RiskEventDialogState extends State<RiskEventDialog> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Timer? _countdownTimer;
  int _secondsRemaining = 5;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _playEventTone();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isClosing) return;
      if (_secondsRemaining <= 1) {
        _closeDialog();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _closeDialog() async {
    if (_isClosing) return;
    _isClosing = true;
    _countdownTimer?.cancel();
    await _player.stop();
    if (mounted) Navigator.of(context).pop();
  }

  String get _displayType => widget.type.contains('ไม่กระพริบตา')
      ? 'เหม่อลอย'
      : widget.type;

  Future<void> _playEventTone() async {
    if (widget.deviceId.isEmpty) return;
    Map<String, dynamic>? setting;
    try {
      setting = await ApiService.instance.deviceSetting(widget.deviceId);
    } catch (error) {
      debugPrint('อ่านการตั้งค่าเสียงไม่สำเร็จ จะใช้เสียง Beep: $error');
    }

    try {
      final enabled = setting == null ||
          setting['sound_enabled'] == true ||
          setting['sound_enabled'] == 1;
      if (!enabled) return;

      final selectedTone =
          setting?['event_tone']?.toString() ?? 'เสียงสัญญาณสั้น (Beep)';
      const builtInUrls = <String, String>{
        'เสียงคลาสสิก (Classic)':
            'https://krzpmhifnpbstikhnbpf.supabase.co/storage/v1/object/public/driver-images/default-audio/classic.mp3',
        'classic.mp3':
            'https://krzpmhifnpbstikhnbpf.supabase.co/storage/v1/object/public/driver-images/default-audio/classic.mp3',
        'เสียงสัญญาณสั้น (Beep)':
            'https://krzpmhifnpbstikhnbpf.supabase.co/storage/v1/object/public/driver-images/default-audio/beep.mp3',
        'beep.mp3':
            'https://krzpmhifnpbstikhnbpf.supabase.co/storage/v1/object/public/driver-images/default-audio/beep.mp3',
        'เสียงแจ้งเตือนไซเรน (Siren)':
            'https://krzpmhifnpbstikhnbpf.supabase.co/storage/v1/object/public/driver-images/default-audio/siren.mp3',
        'siren.mp3':
            'https://krzpmhifnpbstikhnbpf.supabase.co/storage/v1/object/public/driver-images/default-audio/siren.mp3',
      };

      var audioUrl = builtInUrls[selectedTone];
      if (audioUrl == null) {
        final media = await MediaUploadService.instance.fetchDeviceMedia(
          widget.deviceId,
        );
        final matches = media.where((item) {
          if (item.type != 'audio') return false;
          final name = item.displayName ?? item.fileName;
          return name == selectedTone || item.fileName == selectedTone;
        }).toList();
        if (matches.isNotEmpty) audioUrl = matches.first.url;
      }
      if (audioUrl == null || audioUrl.isEmpty || !mounted) {
        debugPrint('ไม่พบ URL ของเสียงแจ้งเตือน: $selectedTone');
        return;
      }

      final rawVolume = setting?['volume_level'];
      final volume = (rawVolume is num
              ? rawVolume.toDouble()
              : double.tryParse(rawVolume?.toString() ?? '100') ?? 100) /
          100;
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(volume.clamp(0.0, 1.0));
      await _player.play(UrlSource(audioUrl));
      if (mounted) setState(() => _isPlaying = true);
    } catch (error) {
      debugPrint('เล่นเสียงแจ้งเตือนทั่วไปไม่สำเร็จ: $error');
    }
  }

  Future<void> _stopSound() async {
    await _player.stop();
    if (mounted) setState(() => _isPlaying = false);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventCount = widget.eventCount.clamp(1, 3);
    final countText = LanguageController.instance.isEnglish
        ? 'Detection $eventCount of 3'
        : 'ตรวจพบครั้งที่ $eventCount จาก 3';
    return AlertDialog(
      icon: const Icon(
        Icons.warning_amber_rounded,
        color: AppColors.warning,
        size: 48,
      ),
      title: const AppText(
        'ตรวจพบพฤติกรรมเสี่ยง',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppText(
            _displayType,
            textAlign: TextAlign.center,
            style: GoogleFonts.prompt(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 8),
          AppText(
            countText,
            textAlign: TextAlign.center,
            style: GoogleFonts.prompt(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          AppText(
            LanguageController.instance.isEnglish
                ? 'Closing in $_secondsRemaining seconds'
                : 'ปิดอัตโนมัติใน $_secondsRemaining วินาที',
            textAlign: TextAlign.center,
            style: GoogleFonts.prompt(
              fontWeight: FontWeight.w700,
              color: AppColors.cFF0F2647,
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        OutlinedButton.icon(
          onPressed: _isPlaying ? _stopSound : null,
          icon: const Icon(Icons.volume_off_rounded),
          label: const AppText('ปิดเสียง'),
        ),
      ],
    );
  }
}
