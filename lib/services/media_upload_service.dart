import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'api_service.dart'; // ใช้ baseUrl เดียวกับ ApiService (10.0.2.2 / env / localhost)

/// ผลลัพธ์ที่ได้กลับมาหลังอัปโหลดไฟล์สำเร็จ
/// ตรงกับ response ของ endpoint POST /api/device-media/upload
class UploadedMedia {
  final String fileName;
  final String url;
  final int fileSizeBytes;
  final String type; // 'image', 'video' หรือ 'audio'

  UploadedMedia({
    required this.fileName,
    required this.url,
    required this.fileSizeBytes,
    required this.type,
  });

  factory UploadedMedia.fromJson(Map<String, dynamic> json) {
    return UploadedMedia(
      fileName: json['file_name'] ?? '',
      url: json['url'] ?? '',
      fileSizeBytes: (json['file_size'] ?? 0) is int
          ? json['file_size']
          : int.tryParse(json['file_size'].toString()) ?? 0,
      type: json['type'] ?? '',
    );
  }
}

/// รวมฟังก์ชันทั้งหมดที่เกี่ยวกับการเลือกไฟล์จากเครื่อง, บีบอัด,
/// และอัปโหลดขึ้น backend (Laravel) ซึ่งจะเก็บไฟล์ลง folder ของโปรเจกต์
/// (storage/app/public/devices/{device_id}/...) แล้วบันทึกชื่อไฟล์ + url ลง MySQL
///
/// วิธีใช้แบบง่ายที่สุด (เลือก -> บีบอัด -> อัปโหลด ในคำสั่งเดียว):
///
/// ```dart
/// final result = await MediaUploadService.instance.pickCompressAndUploadImage(
///   deviceId: widget.deviceData['device_id'].toString(),
/// );
/// if (result != null) print(result.url);
/// ```
class MediaUploadService {
  MediaUploadService._();
  static final MediaUploadService instance = MediaUploadService._();

  /// ใช้ base URL เดียวกับ ApiService เสมอ (10.0.2.2 บน Android emulator,
  /// 127.0.0.1 ตอนรันเดสก์ท็อป/เว็บ หรือค่าที่ตั้งผ่าน --dart-define=API_BASE_URL)
  static String get _baseUrl => ApiService.instance.baseUrl;

  final ImagePicker _picker = ImagePicker();

  // =====================================================================
  // 1) เลือกไฟล์จากเครื่อง
  // =====================================================================

  /// เปิดกล้อง หรือ คลังรูปภาพ เพื่อเลือกรูป
  Future<File?> pickImage({bool fromCamera = false}) async {
    final XFile? picked = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 100, // ดึงต้นฉบับมาก่อน แล้วค่อยไปบีบเองอีกที
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// เปิดกล้อง หรือ คลังวิดีโอ เพื่อเลือกวิดีโอ
  Future<File?> pickVideo({bool fromCamera = false}) async {
    final XFile? picked = await _picker.pickVideo(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// เปิดตัวเลือกไฟล์ของเครื่อง เพื่อเลือกไฟล์เสียง (mp3, wav, m4a, aac ฯลฯ)
  /// ใช้ file_picker เพราะ image_picker ไม่รองรับไฟล์เสียง
  Future<File?> pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );
    if (result == null || result.files.single.path == null) return null;
    return File(result.files.single.path!);
  }

  // =====================================================================
  // 2) บีบอัดไฟล์ (ลดขนาด แต่ยังคมชัด)
  // =====================================================================

  /// บีบอัดรูปภาพ
  /// - quality 70-85 คือช่วงที่คมชัดพอ แต่ไฟล์เล็กลงมาก (แนะนำ 80)
  /// - minWidth/minHeight ควบคุมความละเอียดสูงสุดที่จะย่อลงมา
  Future<File> compressImage(
    File file, {
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
      file.absolute.path,
      targetPath,
      quality: quality,
      minWidth: minWidth,
      minHeight: minHeight,
      keepExif: false,
    );

    if (result == null) return file; // บีบไม่สำเร็จ ใช้ไฟล์เดิมแทน
    return File(result.path);
  }

  /// บีบอัดวิดีโอ
  /// VideoQuality.LowQuality / MediumQuality / HighQuality
  /// MediumQuality คือจุดสมดุลที่ดีระหว่างขนาดไฟล์กับความคมชัด
  Future<File> compressVideo(
    File file, {
    VideoQuality quality = VideoQuality.MediumQuality,
  }) async {
    final info = await VideoCompress.compressVideo(
      file.path,
      quality: quality,
      deleteOrigin: false,
      includeAudio: true,
    );

    if (info == null || info.file == null) return file;
    return info.file!;
  }

  // =====================================================================
  // 3) อัปโหลดไฟล์ขึ้น backend
  // =====================================================================

  /// อัปโหลดไฟล์ (รูป/วิดีโอที่บีบอัดแล้ว หรือไฟล์เสียง) ไปที่ backend
  /// backend จะเก็บไฟล์ใน storage/app/public/devices/{device_id}/{type}s
  /// และบันทึก file_name / url ลงตาราง device_media
  Future<UploadedMedia> uploadFile({
    required File file,
    required String deviceId,
    required String type, // 'image', 'video' หรือ 'audio'
  }) async {
    final uri = Uri.parse('$_baseUrl/device-media/upload');
    final request = http.MultipartRequest('POST', uri);

    request.fields['device_id'] = deviceId;
    request.fields['type'] = type;

    final fileName = p.basename(file.path);
    request.files.add(
      await http.MultipartFile.fromPath('file', file.path, filename: fileName),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return UploadedMedia.fromJson(data['data'] ?? data);
    }
    throw Exception('อัปโหลดไฟล์ไม่สำเร็จ (${response.statusCode}): ${response.body}');
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
  Future<UploadedMedia?> pickAndUploadAudio({
    required String deviceId,
  }) async {
    final file = await pickAudio();
    if (file == null) return null;

    return uploadFile(file: file, deviceId: deviceId, type: 'audio');
  }
}