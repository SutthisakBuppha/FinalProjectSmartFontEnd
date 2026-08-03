import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '/services/api_service.dart';
import '/services/media_upload_service.dart';

class ProfileEditScreen extends StatefulWidget {
  final Map<String, dynamic> currentData;
  const ProfileEditScreen({super.key, required this.currentData});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late TextEditingController _nameController;
  bool _isSaving = false;
  String? _avatarUrl;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentData['name'] ?? '');
    _avatarUrl = widget.currentData['avatar_url']?.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      await ApiService.instance.updateDriverProfile(
        name: _nameController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปเดตข้อมูลสำเร็จเรียบร้อย')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกข้อมูลล้มเหลว: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatarPicker(),
                    const SizedBox(height: 24),
                    _buildInputField("ชื่อ-นามสกุลคนขับ", _nameController, Icons.person_outline_rounded),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                "บันทึกข้อมูลส่วนตัว",
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.primaryLight]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            "แก้ไขโปรไฟล์",
            style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPicker() {
    final hasAvatar = _avatarUrl != null && _avatarUrl!.isNotEmpty;
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: AppColors.primaryLight.withOpacity(0.12),
                backgroundImage: hasAvatar ? NetworkImage(_avatarUrl!) : null,
                child: hasAvatar
                    ? null
                    : const Icon(Icons.person_rounded, size: 52, color: AppColors.primaryLight),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: AppColors.primaryLight,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _isUploadingAvatar ? null : _showAvatarSourceSheet,
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: _isUploadingAvatar
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('แตะเพื่อเปลี่ยนรูปโปรไฟล์', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _showAvatarSourceSheet() async {
    final fromCamera = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('เลือกรูปจากคลังภาพ'),
              onTap: () => Navigator.pop(sheetContext, false),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('ถ่ายรูปใหม่'),
              onTap: () => Navigator.pop(sheetContext, true),
            ),
          ],
        ),
      ),
    );
    if (fromCamera == null || !mounted) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final url = await MediaUploadService.instance
          .pickCropCompressAndUploadProfileImage(fromCamera: fromCamera);
      if (url != null && mounted) setState(() => _avatarUrl = url);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อัปโหลดรูปภาพไม่สำเร็จ: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.textMuted),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primaryLight, width: 2)),
          ),
        ),
      ],
    );
  }

}
