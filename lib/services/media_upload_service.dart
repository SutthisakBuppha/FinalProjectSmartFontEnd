import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'api_service.dart';

class UploadedMedia {
  final String mediaId;
  final String fileName;
  final String url;
  final int fileSizeBytes;
  final String type;
  final bool isActive;
  final bool isDefault;
  final String? displayName;

  UploadedMedia({
    required this.mediaId,
    required this.fileName,
    required this.url,
    required this.fileSizeBytes,
    required this.type,
    this.isActive = false,
    this.isDefault = false,
    this.displayName,
  });

  factory UploadedMedia.fromJson(Map<String, dynamic> json) {
    return UploadedMedia(
      mediaId: json['media_id']?.toString() ?? '',
      fileName: json['file_name'] ?? '',
      url: json['url'] ?? '',
      fileSizeBytes: (json['file_size'] ?? 0) is int
          ? json['file_size']
          : int.tryParse(json['file_size'].toString()) ?? 0,
      type: json['type'] ?? '',
      isActive: json['is_active'] == true || json['is_active'] == 1,
      isDefault: json['is_default'] == true || json['is_default'] == 1,
      displayName: json['display_name']?.toString(),
    );
  }
}

class MediaUploadService {
  MediaUploadService._();
  static final MediaUploadService instance = MediaUploadService._();
  static String get _baseUrl => ApiService.instance.baseUrl;

  final ImagePicker _picker = ImagePicker();

  // =====================================================================
  // 1) เลือกไฟล์จากเครื่อง
  // =====================================================================

  Future<XFile?> pickImage({bool fromCamera = false}) async {
    final XFile? picked = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      // จำกัดขนาดตั้งแต่ต้นทาง ป้องกัน Android ใช้หน่วยความจำสูงเกินไป
      // เมื่อผู้ใช้เลือกรูปจากกล้องมือถือที่มีความละเอียดหลายสิบ MP
      imageQuality: 90,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null) return null;
    return picked;
  }

  Future<XFile?> cropProfileImage(XFile source) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: source.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop profile photo',
          lockAspectRatio: true,
          aspectRatioPresets: const [
            CropAspectRatioPreset.square,
          ], // moved here
        ),
        IOSUiSettings(
          title: 'Crop profile photo',
          aspectRatioLockEnabled: true,
        ),
      ],
    );
    if (cropped == null) return null;
    return XFile(cropped.path);
  }

  Future<Uint8List> compressImageBytes(
    XFile image, {
    int quality = 85,
    int minWidth = 800,
    int minHeight = 800,
  }) async {
    final bytes = await image.readAsBytes();
    return FlutterImageCompress.compressWithList(
      bytes,
      quality: quality,
      minWidth: minWidth,
      minHeight: minHeight,
      keepExif: false,
      format: CompressFormat.jpeg,
    );
  }

  Future<String?> pickCropCompressAndUploadProfileImage({
    bool fromCamera = false,
  }) async {
    final original = await pickImage(fromCamera: fromCamera);
    if (original == null) return null;

    XFile toUpload = original;
    if (!kIsWeb) {
      final cropped = await cropProfileImage(original);
      if (cropped == null) return null;
      toUpload = cropped;
    }

    final bytes = await compressImageBytes(toUpload);
    return ApiService.instance.uploadDriverAvatar(
      bytes: bytes,
      fileName: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
  }

  Future<XFile?> pickVideo({bool fromCamera = false}) async {
    final XFile? picked = await _picker.pickVideo(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );
    if (picked == null) return null;
    return picked;
  }

  Future<PlatformFile?> pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.single;
  }

  // =====================================================================
  // 2) บีบอัดไฟล์ (ลดขนาด แต่ยังคมชัด)
  // =====================================================================

  Future<XFile> compressImage(
    XFile file, {
    int quality = 80,
    int minWidth = 1280,
    int minHeight = 1280,
  }) async {
    final dir = await getTemporaryDirectory();
    final targetPath = p.join(
      dir.path,
      'img_${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}',
    );

    final XFile? result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: quality,
      minWidth: minWidth,
      minHeight: minHeight,
      keepExif: false,
    );

    if (result == null) return file;
    return result;
  }

  /// บีบอัดวิดีโอ
  /// VideoQuality.LowQuality / MediumQuality / HighQuality
  /// MediumQuality คือจุดสมดุลที่ดีระหว่างขนาดไฟล์กับความคมชัด
  Future<XFile> compressVideo(
    XFile file, {
    VideoQuality quality = VideoQuality.MediumQuality,
  }) async {
    final info = await VideoCompress.compressVideo(
      file.path,
      quality: quality,
      deleteOrigin: false,
      includeAudio: true,
    );

    if (info == null || info.file == null) return file;
    return XFile(info.file!.path);
  }

  // =====================================================================
  // 3) อัปโหลดไฟล์ขึ้น backend
  // =====================================================================

  /// อัปโหลดไฟล์ (รูป/วิดีโอที่บีบอัดแล้ว) ไปที่ backend โดยรับเป็น File
  /// ใช้ได้เฉพาะแพลตฟอร์มที่มี filesystem path จริง (Android/iOS/Desktop)
  /// ห้ามใช้กับ Flutter Web เพราะ File ต้องการ path ซึ่งบนเว็บไม่มี
  Future<UploadedMedia> uploadFile({
    required XFile file,
    required String deviceId,
    required String type, // 'image', 'video' หรือ 'audio'
  }) async {
    final fileName = file.name.isNotEmpty ? file.name : p.basename(file.path);
    final bytes = await file.readAsBytes();
    return uploadBytes(
      bytes: bytes,
      fileName: fileName,
      deviceId: deviceId,
      type: type,
    );
  }

  /// อัปโหลดไฟล์จาก raw bytes ไปที่ backend
  /// ใช้ได้ทุกแพลตฟอร์ม (รวมถึง Flutter Web ที่ไม่มี filesystem path)
  /// backend จะเก็บไฟล์ใน storage/app/public/devices/{device_id}/{type}s
  /// และบันทึก file_name / url ลงตาราง device_media
  Future<UploadedMedia> uploadBytes({
    required List<int> bytes,
    required String fileName,
    required String deviceId,
    required String type, // 'image', 'video' หรือ 'audio'
  }) async {
    final uri = Uri.parse('$_baseUrl/device-media/upload');
    final request = http.MultipartRequest('POST', uri);

    request.fields['device_id'] = deviceId;
    request.fields['type'] = type;

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return UploadedMedia.fromJson(data['data'] ?? data);
    }

    String? apiMessage;
    try {
      final errorBody = jsonDecode(response.body);
      apiMessage = errorBody is Map<String, dynamic>
          ? errorBody['message']?.toString()
          : null;
    } catch (_) {
      // Keep the status-code fallback when the server does not return JSON.
    }
    throw Exception(
      apiMessage ?? 'อัปโหลดไฟล์ไม่สำเร็จ (${response.statusCode})',
    );
  }

  Future<void> selectMedia(String mediaId) async {
    final uri = Uri.parse('$_baseUrl/device-media/$mediaId/select');
    final response = await http.patch(uri);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'ตั้งเสียงที่ใช้งานไม่สำเร็จ (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<void> deleteMedia(String mediaId) async {
    final uri = Uri.parse('$_baseUrl/device-media/$mediaId');
    final response = await http.delete(uri);

    if (response.statusCode == 200 || response.statusCode == 204) return;

    String? apiMessage;
    try {
      final errorBody = jsonDecode(response.body);
      apiMessage = errorBody is Map<String, dynamic>
          ? errorBody['message']?.toString()
          : null;
    } catch (_) {
      // Keep the status-code fallback when the server does not return JSON.
    }

    throw Exception(
      apiMessage ?? 'ลบไฟล์เสียงไม่สำเร็จ (${response.statusCode})',
    );
  }

  /// ดึงรายการไฟล์สื่อทั้งหมดที่เคยอัปโหลดของอุปกรณ์นี้
  Future<List<UploadedMedia>> fetchDeviceMedia(String deviceId) async {
    final uri = Uri.parse('$_baseUrl/device-media/$deviceId');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List list = data['data'] ?? [];
      return list.map((e) => UploadedMedia.fromJson(e)).toList();
    }
    throw Exception('โหลดรายการไฟล์ไม่สำเร็จ (${response.statusCode})');
  }

  // =====================================================================
  // 4) ฟังก์ชันรวม: เลือก -> บีบอัด -> อัปโหลด ในคำสั่งเดียว
  // =====================================================================

  Future<UploadedMedia?> pickCompressAndUploadImage({
    required String deviceId,
    bool fromCamera = false,
  }) async {
    final original = await pickImage(fromCamera: fromCamera);
    if (original == null) return null;

    final compressed = await compressImage(original);
    return uploadFile(file: compressed, deviceId: deviceId, type: 'image');
  }

  Future<UploadedMedia?> pickCompressAndUploadVideo({
    required String deviceId,
    bool fromCamera = false,
  }) async {
    final original = await pickVideo(fromCamera: fromCamera);
    if (original == null) return null;

    final compressed = await compressVideo(original);
    return uploadFile(file: compressed, deviceId: deviceId, type: 'video');
  }

  /// เลือกไฟล์เสียงจากเครื่อง -> อัปโหลดขึ้น backend ทันที (ไม่มีการบีบอัด
  /// เพราะไฟล์เสียง preset ทั่วไปมีขนาดเล็กอยู่แล้ว)
  ///
  /// แก้บั๊กเว็บ: ใช้ PlatformFile.bytes แทน File(path) เพราะบน Flutter Web
  /// ไม่มี filesystem path ให้เข้าถึง (path จะเป็น null เสมอ) การอัปโหลดจึง
  /// ใช้ uploadBytes() ซึ่งทำงานได้ทั้งบนเว็บและมือถือ
  Future<UploadedMedia?> pickAndUploadAudio({required String deviceId}) async {
    final platformFile = await pickAudio();
    if (platformFile == null) return null;

    final bytes = platformFile.bytes;
    if (bytes == null) {
      throw Exception(
        'ไม่พบข้อมูลไฟล์เสียง (bytes เป็น null) กรุณาลองเลือกไฟล์ใหม่อีกครั้ง',
      );
    }

    return uploadBytes(
      bytes: bytes,
      fileName: platformFile.name,
      deviceId: deviceId,
      type: 'audio',
    );
  }
}
