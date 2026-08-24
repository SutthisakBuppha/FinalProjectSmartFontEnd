import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'package:audioplayers/audioplayers.dart';

import 'map_screen.dart';
import '/services/api_service.dart';
import '/services/media_upload_service.dart';

class AlertScreen extends StatefulWidget {
  final dynamic deviceId;
  const AlertScreen({super.key, this.deviceId});

  @override
  State<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen> with SingleTickerProviderStateMixin {
  static const MethodChannel _alarmChannel = MethodChannel(
    'smart_drive_guard/alarm',
  );

  bool _isLoading = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSoundPlaying = false;
  
  // สำหรับ Animation ตอนเปิดหน้า
  late AnimationController _entranceController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup Entrance Animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.elasticOut,
    );
    _entranceController.forward();

    _startAlertVibration();
    _playAlertSound();
  }

  bool get _isAndroidMobile =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _startAlertVibration() async {
    if (!_isAndroidMobile) return;
    try {
      await _alarmChannel.invokeMethod<void>('startVibration');
    } catch (e) {
      debugPrint('เริ่มระบบสั่นแจ้งเตือนไม่สำเร็จ: $e');
    }
  }

  Future<void> _stopAlertVibration() async {
    if (!_isAndroidMobile) return;
    try {
      await _alarmChannel.invokeMethod<void>('stopVibration');
    } catch (e) {
      debugPrint('หยุดระบบสั่นแจ้งเตือนไม่สำเร็จ: $e');
    }
  }

  Future<void> _playAlertSound() async {
    final deviceId = widget.deviceId;
    if (deviceId == null) {
      debugPrint('ไม่มี deviceId ส่งมา -> ข้ามการเล่นเสียงแจ้งเตือน');
      return;
    }

    try {
      final setting = await ApiService.instance.deviceSetting(deviceId);
      final activeTone = setting?['active_tone'];
      final soundEnabled = setting?['sound_enabled'] == 1 || setting?['sound_enabled'] == true;

      if (!soundEnabled || activeTone == null) {
        debugPrint('ปิดเสียงไว้ หรือไม่มี active_tone -> ไม่เล่นเสียง');
        return;
      }

      final mediaList = await MediaUploadService.instance.fetchDeviceMedia(
        deviceId.toString(),
      );
      final match = mediaList.where((media) {
        if (media.type != 'audio') return false;
        if (!media.isDefault) return media.isActive;

        final defaultName = media.displayName ?? media.fileName;
        return defaultName == activeTone || media.fileName == activeTone;
      }).toList();

      if (match.isEmpty) {
        debugPrint('ไม่มีไฟล์เสียงที่ถูกเลือก (is_active) -> ไม่เล่นเสียง');
        return;
      }

      final volumeLevel = setting?['volume_level'] ?? 100;
      final volume = (volumeLevel is int
              ? volumeLevel
              : int.tryParse(volumeLevel.toString()) ?? 100) /
          100.0;

      final audioUrl = match.first.url;

      debugPrint('=========================================');
      debugPrint('👉 URL ที่กำลังจะเล่นจริงบนมือถือ: $audioUrl');
      debugPrint('=========================================');

      // Web keeps its normal media playback. On Android the sound is routed
      // through the Alarm stream so it follows the device's alarm volume.
      if (_isAndroidMobile) {
        await _audioPlayer.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              isSpeakerphoneOn: true,
              stayAwake: true,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.alarm,
              audioFocus: AndroidAudioFocus.gainTransient,
            ),
          ),
        );
      }

      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(volume.clamp(0.0, 1.0).toDouble());
      await _audioPlayer.play(UrlSource(audioUrl));

      if (mounted) {
        setState(() => _isSoundPlaying = true);
      }
    } catch (e) {
      debugPrint('เล่นเสียงแจ้งเตือนไม่สำเร็จ: $e');
    }
  }

  Future<void> _stopAlertSound() async {
    await _stopAlertVibration();
    try {
      if (_isSoundPlaying) {
        await _audioPlayer.stop();
      }
    } catch (e) {
      debugPrint('หยุดเสียงแจ้งเตือนไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _isSoundPlaying = false);
    }
  }

  @override
  void dispose() {
    // MethodChannel calls cannot be awaited from dispose.
    _stopAlertVibration();
    _entranceController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _navigateToNearestRest() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await _stopAlertSound();
    
    // หน่วงเวลาเล็กน้อยให้เห็นปุ่ม Loading
    await Future.delayed(const Duration(milliseconds: 300)); 
    
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MapScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color alertRed = AppColors.cFFFF4D4D;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.cFF161022, // สีพื้นหลังเข้ม
        body: Stack(
          fit: StackFit.expand,
          children: [
            // --- Layer 1: Background UI (Map & Dashboard) ---
            SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "SaveDriveAi",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Prompt',
                            letterSpacing: 0.5,
                          ),
                        ),
                        _buildIconButton(Icons.account_circle_outlined),
                      ],
                    ),
                  ),

                  // Map Placeholder Area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.grey[800]!.withOpacity(0.5),
                                  Colors.grey[900]!.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.map_rounded, color: Colors.white24, size: 80),
                                  SizedBox(height: 16),
                                  Text(
                                    'Map view unavailable',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 24,
                            left: 16,
                            right: 16,
                            child: Row(
                              children: [
                                Expanded(child: _buildInfoCard("ความเร็ว", "65", "กม./ชม.")),
                                const SizedBox(width: 12),
                                Expanded(child: _buildInfoCard("เวลาขับขี่", "2:15", "ชม.")),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // --- Layer 2: Blur Overlay ---
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(color: AppColors.cFF161022.withOpacity(0.75)),
              ),
            ),

            // --- Layer 3: Modal Alert ---
            Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 360),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: alertRed.withOpacity(0.2), // แสงเงาสีแดงรอบๆ การ์ด
                          blurRadius: 40,
                          spreadRadius: 10,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Warning Icon (Ripple Effect)
                        const PulseWarningIcon(color: alertRed),
                        const SizedBox(height: 28),

                        // Title
                        const Text(
                          "ตรวจพบความเสี่ยง\nง่วงนอนหลับใน!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.cFF120D1B,
                            fontSize: 26,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Subtitle
                        const Text(
                          "ระบบแจ้งเตือนความปลอดภัยกำลังทำงาน\nโปรดหาที่จอดพักที่ปลอดภัยทันที",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.cFF6B7280,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Status Icons (Pills)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStatusChip(Icons.volume_up_rounded, "เสียงเตือน"),
                            const SizedBox(width: 12),
                            _buildStatusChip(Icons.vibration_rounded, "ระบบสั่น"),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // 🔴 Button
                        _buildFilledButton(
                          text: _isLoading ? "กำลังค้นหาจุดพักรถ..." : "นำทางไปจุดพักรถใกล้ฉัน",
                          icon: _isLoading ? Icons.hourglass_top_rounded : Icons.navigation_rounded,
                          color: alertRed,
                          onPressed: _isLoading ? null : _navigateToNearestRest,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(10),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }

  Widget _buildInfoCard(String title, String value, String unit) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF3B82F6), size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF2563EB),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilledButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        boxShadow: onPressed == null ? [] : [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withOpacity(0.6),
          disabledForegroundColor: Colors.white70,
          elevation: 0, 
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Icon(icon, size: 26),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Prompt',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// PulseWarningIcon: ปรับแต่งให้แอนิเมชันเด้งและแผ่รัศมี (Ripple) สวยขึ้น
// ----------------------------------------------------------------------
class PulseWarningIcon extends StatefulWidget {
  final Color color;
  const PulseWarningIcon({super.key, required this.color});

  @override
  State<PulseWarningIcon> createState() => _PulseWarningIconState();
}

class _PulseWarningIconState extends State<PulseWarningIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // วงแหวนที่แผ่ออกไป (Ripple)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          ),
          // วงกลมพื้นหลังชั้นใน
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
          ),
          // วงกลมสีทึบตรงกลาง
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_rounded,
              color: widget.color,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }
}
