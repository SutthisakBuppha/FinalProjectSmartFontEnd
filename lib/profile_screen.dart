import 'package:flutter/material.dart';
import '/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_edit_screen.dart';
import 'login_screen.dart';
import '/services/api_service.dart';
import '/services/text_scale_service.dart';
import '/services/language_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profileData;
  double _totalDistance = 0;
  int _totalDrivingMinutes = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final results = await Future.wait([
        ApiService.instance.driverProfile(),
        ApiService.instance.trips(),
      ]);
      if (!mounted) return;
      setState(() {
        _profileData = results[0] as Map<String, dynamic>;
        final trips = results[1] as List<Map<String, dynamic>>;
        final mainTrips = trips.where((trip) {
          return (trip['trip_type']?.toString() ?? 'main') == 'main';
        }).toList();
        final completedTrips = mainTrips.where((trip) {
          return trip['status']?.toString() == 'completed' ||
              trip['end_time'] != null;
        }).toList();
        _totalDistance = completedTrips.fold<double>(0, (sum, trip) {
          return sum +
              (double.tryParse(trip['distance']?.toString() ?? '') ?? 0);
        });
        _totalDrivingMinutes = completedTrips.fold<int>(0, (sum, trip) {
          return sum + _tripDurationMinutes(trip);
        });
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText('โหลดข้อมูลโปรไฟล์ล้มเหลว: $e')),
      );
    }
  }

  /// Backend stores `status` as a tinyint (0/1) on the `drivers` table.
  /// This converts that numeric code into a Thai label for display.
  /// Falls back gracefully if a String ever comes through instead.
  static String statusLabel(dynamic value) {
    if (value == null) return 'ไม่มีสถานะ';
    if (value is String) {
      // Already text (e.g. legacy/admin data) — use as-is.
      if (value.trim().isEmpty) return 'ไม่มีสถานะ';
      final parsed = int.tryParse(value);
      if (parsed == null) return value;
      value = parsed;
    }
    switch (value) {
      case 1:
        return 'ปฏิบัติงานปกติ';
      case 0:
        return 'ระงับการขับขี่';
      default:
        return 'ไม่มีสถานะ';
    }
  }

  /// Whether the status code represents an active/normal driver.
  static bool statusIsActive(dynamic value) {
    if (value is String) value = int.tryParse(value);
    return value == 1;
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: AppText(
          "ยืนยันการออกจากระบบ",
          style: GoogleFonts.prompt(fontWeight: FontWeight.bold),
        ),
        content: AppText(
          "คุณต้องการออกจากระบบใช่หรือไม่?",
          style: GoogleFonts.prompt(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: AppText(
              "ยกเลิก",
              style: GoogleFonts.prompt(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );

              ApiService.instance.logoutDriver().catchError((e) {
                debugPrint("Logout API error (ไม่กระทบผู้ใช้): $e");
              });
            },
            child: AppText(
              "ออกจากระบบ",
              style: GoogleFonts.prompt(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).height < 760;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight),
            )
          : Stack(
              children: [
                Column(
                  children: [
                    _buildHeader(isCompact),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            isCompact ? 12 : 20,
                            20,
                            110,
                          ),
                          child: Column(
                            children: [_buildDisplaySettings(isCompact)],
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

  Widget _buildHeader(bool isCompact) {
    final name = _profileData?['name'] ?? 'ไม่ระบุชื่อ';
    final username = _profileData?['username'] ?? 'No Username';
    final rawStatus = _profileData?['status'];
    final status = statusLabel(rawStatus);
    final isActive = statusIsActive(rawStatus);
    final avatarUrl = _profileData?['avatar_url'];

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(isCompact ? 28 : 34),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: isCompact ? 2 : 6,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppText(
                      "โปรไฟล์",
                      style: GoogleFonts.prompt(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit_note_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileEditScreen(
                            currentData: _profileData ?? {},
                          ),
                        ),
                      ).then((_) => _fetchProfile());
                    },
                  ),
                  IconButton(
                    tooltip: appTr('ออกจากระบบ'),
                    onPressed: _handleLogout,
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isCompact ? 2 : 10),
            CircleAvatar(
              radius: isCompact ? 34 : 42,
              backgroundColor: Colors.white24,
              backgroundImage:
                  avatarUrl != null && avatarUrl.toString().isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null || avatarUrl.toString().isEmpty
                  ? Icon(
                      Icons.person_rounded,
                      size: isCompact ? 36 : 44,
                      color: Colors.white,
                    )
                  : null,
            ),
            SizedBox(height: isCompact ? 6 : 10),
            AppText(
              name,
              style: GoogleFonts.prompt(
                color: Colors.white,
                fontSize: isCompact ? 19 : 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            AppText(
              "@$username",
              style: GoogleFonts.prompt(
                color: Colors.white70,
                fontSize: isCompact ? 12 : 13,
              ),
            ),
            SizedBox(height: isCompact ? 5 : 8),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: isCompact ? 4 : 5,
              ),
              decoration: BoxDecoration(
                color: isActive ? AppColors.cFF4ADE80 : AppColors.cFFDC2626,
                borderRadius: BorderRadius.circular(20),
              ),
              child: AppText(
                status,
                style: GoogleFonts.prompt(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: isCompact ? 6 : 12),
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: isCompact ? 6 : 10,
              ),
              padding: EdgeInsets.symmetric(vertical: isCompact ? 9 : 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(
                    "ระยะทางรวม",
                    "${_totalDistance.toStringAsFixed(1)} กม.",
                  ),
                  _buildStatItem(
                    "เวลาขับขี่",
                    "${(_totalDrivingMinutes / 60).toStringAsFixed(1)} ชม.",
                  ),
                ],
              ),
            ),
            SizedBox(height: isCompact ? 6 : 10),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        AppText(
          value,
          style: GoogleFonts.prompt(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        AppText(
          label,
          style: GoogleFonts.prompt(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  int _tripDurationMinutes(Map<String, dynamic> trip) {
    final start = DateTime.tryParse(trip['start_time']?.toString() ?? '');
    final end = DateTime.tryParse(trip['end_time']?.toString() ?? '');
    if (start != null && end != null) {
      return end.difference(start).inMinutes.abs();
    }
    return num.tryParse(trip['duration']?.toString() ?? '')?.toInt() ?? 0;
  }

  Widget _buildDisplaySettings(bool isCompact) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        TextScaleController.instance,
        LanguageController.instance,
      ]),
      builder: (context, _) {
        final controller = TextScaleController.instance;
        final languageController = LanguageController.instance;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isCompact ? 16 : 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.cFFEFF6FF,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.text_fields_rounded,
                      color: AppColors.cFF1D4ED8,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          'การตั้งค่าการแสดงผล',
                          style: GoogleFonts.prompt(
                            color: AppColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AppText(
                          'เลือกขนาดตัวอักษรที่อ่านสบายตา',
                          style: GoogleFonts.prompt(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 14 : 18),
              AppText(
                'ขนาดตัวอักษร',
                style: GoogleFonts.prompt(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TextScaleController.presets.entries.map((entry) {
                  final isSelected =
                      (controller.scaleFactor - entry.value).abs() < 0.01;

                  return ChoiceChip(
                    label: AppText(entry.key),
                    selected: isSelected,
                    showCheckmark: false,
                    selectedColor: AppColors.primaryLight,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primaryLight
                          : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelStyle: GoogleFonts.prompt(
                      color: isSelected ? Colors.white : AppColors.text,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    onSelected: (_) async {
                      if (isSelected) return;
                      try {
                        await controller.setScale(entry.value);
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: AppText(
                              'บันทึกขนาดตัวอักษรไม่สำเร็จ: $error',
                            ),
                          ),
                        );
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AppText(
                  'ตัวอย่างข้อความในแอป',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.prompt(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 16),
              AppText(
                'ภาษา',
                style: GoogleFonts.prompt(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              AppText(
                'เลือกภาษาที่ใช้ในแอป',
                style: GoogleFonts.prompt(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    const [
                      ('th', 'ไทย', Icons.language_rounded),
                      ('en', 'English', Icons.translate_rounded),
                    ].map((option) {
                      final isSelected =
                          languageController.languageCode == option.$1;
                      return ChoiceChip(
                        avatar: Icon(
                          option.$3,
                          size: 17,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textMuted,
                        ),
                        label: AppText(option.$2),
                        selected: isSelected,
                        showCheckmark: false,
                        selectedColor: AppColors.primaryLight,
                        backgroundColor: AppColors.surface,
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primaryLight
                              : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        labelStyle: GoogleFonts.prompt(
                          color: isSelected ? Colors.white : AppColors.text,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        onSelected: (_) async {
                          if (isSelected) return;
                          try {
                            await languageController.setLanguage(option.$1);
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: AppText('บันทึกภาษาไม่สำเร็จ: $error'),
                              ),
                            );
                          }
                        },
                      );
                    }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
