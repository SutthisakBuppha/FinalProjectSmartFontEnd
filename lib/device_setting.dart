import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'devices_screen.dart'; // ตรวจสอบให้แน่ใจว่าชื่อไฟล์ตรงกับหน้าจัดการอุปกรณ์ของคุณ

class DeviceCustomizationScreen extends StatefulWidget {
  const DeviceCustomizationScreen({
    super.key,
    required this.deviceData,
  });

  final Map<String, dynamic> deviceData;

  @override
  State<DeviceCustomizationScreen> createState() =>
      _DeviceCustomizationScreenState();
}

class _DeviceCustomizationScreenState extends State<DeviceCustomizationScreen> {
  // สีพื้นฐานอ้างอิงจาก Tailwind config
  static const Color primaryColor = Color(0xFF0F2557);
  static const Color bgLight = Color(0xFFFFFFFF);
  static const Color bgOffwhite = Color(0xFFF6F8FA);
  static const Color accentBlue = Color(0xFFE8EFFD);
  static const Color accentBlueDark = Color(0xFF1A3A75);

  // States
  bool _soundEnabled = true;
  double _volumeLevel = 75.0;
  String _activeTone = 'เสียงคลาสสิก (Classic)';
  String? _customSoundFileName; // ตัวแปรเก็บชื่อไฟล์เสียงภายนอกที่ผู้ใช้เลือก

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgOffwhite,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: primaryColor,
            size: 22,
          ),
          onPressed: () {
            // ย้อนกลับไปหน้า DevicesScreen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const DeviceManagementScreen(), 
              ),
            );
          },
        ),
        title: Text(
          "การตั้งค่าอุปกรณ์",
          style: GoogleFonts.notoSansThai(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: primaryColor,
              size: 28,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildActiveDeviceHeader(),
            const SizedBox(height: 32),
            _buildSoundPreferences(),
            const SizedBox(height: 24),
            _buildCustomSoundSection(), // <--- ส่วนที่เพิ่มมาใหม่แทน Visual Feedback
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ================= ส่วนหัว (ข้อมูลอุปกรณ์) =================
  Widget _buildActiveDeviceHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryColor,
                    Color(0xFF1E40AF),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.videocam_outlined,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "อุปกรณ์ที่ใช้งาน",
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "กล้องหน้ารถ",
                  style: GoogleFonts.notoSansThai(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "ออนไลน์",
                      style: GoogleFonts.notoSansThai(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "เปลี่ยนชื่อ",
                      style: GoogleFonts.notoSansThai(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ================= ส่วนตั้งค่าเสียงระบบ (Sound Preferences) =================
  Widget _buildSoundPreferences() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgLight,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // สวิตช์เปิด/ปิดเสียง
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8EFFD),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.volume_up_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "การตั้งค่าเสียง",
                    style: GoogleFonts.notoSansThai(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              CupertinoSwitch(
                value: _soundEnabled,
                activeColor: primaryColor,
                onChanged: (value) => setState(() => _soundEnabled = value),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // แถบปรับระดับเสียง
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ระดับเสียง",
                style: GoogleFonts.notoSansThai(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
              Text(
                "${_volumeLevel.toInt()}%",
                style: GoogleFonts.notoSansThai(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: primaryColor,
              inactiveTrackColor: accentBlue,
              thumbColor: Colors.white,
              overlayColor: primaryColor.withOpacity(0.1),
              thumbShape: const _CustomThumbShape(
                borderColor: primaryColor,
              ),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: _volumeLevel,
              min: 0,
              max: 100,
              onChanged: _soundEnabled
                  ? (value) => setState(() => _volumeLevel = value)
                  : null, // ปิดการใช้งานเมื่อปิดสวิตช์
            ),
          ),
          const SizedBox(height: 24),

          // เสียงแจ้งเตือน
          Text(
            "เสียงแจ้งเตือน (ALERT TONES)",
            style: GoogleFonts.notoSansThai(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildToneOption(
            "เสียงโมเดิร์น (Modern)",
            "เสียงแจ้งเตือนแบบนุ่มนวล",
          ),
          const SizedBox(height: 12),
          _buildToneOption(
            "เสียงคลาสสิก (Classic)",
            "เสียงเตือนมาตรฐานแบบบี๊บ",
          ),
          const SizedBox(height: 12),
          _buildToneOption(
            "เสียงฉุกเฉิน (High Alert)",
            "เสียงเตือนภัยระดับเร่งด่วน",
          ),
        ],
      ),
    );
  }

  // ================= เพิ่มเสียงแจ้งเตือนแบบกำหนดเอง (Custom Audio) =================
  Widget _buildCustomSoundSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgLight,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EFFD),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.audio_file_rounded,
                  color: primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "เพิ่มเสียงแจ้งเตือนใหม่",
                  style: GoogleFonts.notoSansThai(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "คุณสามารถเพิ่มไฟล์เสียงภายนอก (เช่น .mp3, .wav) จากอุปกรณ์ของคุณ เพื่อใช้เป็นเสียงแจ้งเตือนแบบกำหนดเองได้",
            style: GoogleFonts.notoSansThai(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              // TODO: ใส่ Logic สำหรับเลือกไฟล์เสียงตรงนี้ เช่น ใช้ package: file_picker
              // ตัวอย่าง Mock up การเลือกไฟล์
              setState(() {
                _customSoundFileName = "my_custom_alert_sound.mp3";
                _activeTone = "เสียงกำหนดเอง"; // เปลี่ยนให้ใช้งานเสียงนี้อัตโนมัติ
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _customSoundFileName == null
                      ? Colors.grey.shade300
                      : primaryColor,
                ),
                borderRadius: BorderRadius.circular(12),
                color: _customSoundFileName == null
                    ? Colors.white
                    : primaryColor.withOpacity(0.03),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          _customSoundFileName == null
                              ? Icons.upload_file_rounded
                              : Icons.check_circle_rounded,
                          color: _customSoundFileName == null
                              ? Colors.grey.shade500
                              : Colors.green,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _customSoundFileName ?? "เลือกไฟล์เสียงจากในเครื่อง...",
                            style: GoogleFonts.notoSansThai(
                              fontSize: 14,
                              fontWeight: _customSoundFileName == null
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                              color: _customSoundFileName == null
                                  ? Colors.grey.shade500
                                  : primaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_customSoundFileName != null)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _customSoundFileName = null; // ลบไฟล์ที่เลือก
                          if (_activeTone == "เสียงกำหนดเอง") {
                            _activeTone = "เสียงคลาสสิก (Classic)"; // กลับไปใช้ค่าเริ่มต้น
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.red.shade400,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // แสดงตัวเลือกนี้เฉพาะเวลาที่มีการอัพโหลดไฟล์เข้ามา
          if (_customSoundFileName != null) ...[
            const SizedBox(height: 16),
            _buildToneOption("เสียงกำหนดเอง", "ไฟล์: $_customSoundFileName")
          ]
        ],
      ),
    );
  }

  // ================= วิดเจ็ตตัวเลือกเสียง (Tone Option Builder) =================
  Widget _buildToneOption(String title, String subtitle) {
    bool isActive = _activeTone == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTone = title;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFF0F5FF) : bgLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? primaryColor : Colors.grey.shade200,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isActive ? primaryColor : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 16,
                      color: isActive ? Colors.white : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.notoSansThai(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isActive ? primaryColor : Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.notoSansThai(
                            fontSize: 12,
                            color: isActive
                                ? primaryColor.withOpacity(0.6)
                                : Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: isActive ? primaryColor : Colors.grey.shade300,
                  width: isActive ? 5 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= รูปแบบ Custom Slider Thumb =================
class _CustomThumbShape extends SliderComponentShape {
  final Color borderColor;
  final double thumbRadius;
  final double borderWidth;

  const _CustomThumbShape({
    required this.borderColor,
    this.thumbRadius = 10.0,
    this.borderWidth = 2.0,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    final Path shadowPath = Path()
      ..addOval(
        Rect.fromCircle(center: center.translate(0, 2), radius: thumbRadius),
      );
    canvas.drawShadow(shadowPath, Colors.black, 4, true);

    final Paint fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, thumbRadius, fillPaint);

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, thumbRadius, borderPaint);
  }
}