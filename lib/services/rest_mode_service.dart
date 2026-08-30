import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'push_notification_service.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// RestModeService
/// ═══════════════════════════════════════════════════════════════════════
/// จัดการสถานะ "โหมดพักรถ" (Rest Mode)
///
/// ปัญหาที่แก้: เมื่อผู้ใช้จอดรถนอนพัก / จอดพักผ่อน / จอดหยิบของ โดยยังติด
/// เครื่องยนต์ทิ้งไว้ (สตาร์ทค้าง) กล้อง AI ยังคงตรวจจับใบหน้าต่อไปตามปกติ
/// และจะเข้าใจว่าอาการ "หลับตานาน" หรือ "หันหน้าออกจากกล้องนาน" คือ
/// อาการง่วงนอน/เสียสมาธิขณะขับขี่ ทั้งที่จริงแล้วรถจอดสนิทอยู่
/// ทำให้เกิดการแจ้งเตือนที่ไม่จำเป็นและรบกวนผู้ใช้ (false positive)
///
/// วิธีแก้ที่ใช้: 2 ทางร่วมกัน
///   A) Manual: ผู้ใช้กดเปิด "โหมดพักรถ" เองก่อนจะจอดพัก/นอน/หยิบของ
///      โดยเลือกระยะเวลาที่ต้องการ (เช่น 10 / 15 / 30 นาที)
///   B) Auto-close: ระหว่างที่เปิดโหมดพักรถอยู่ ระบบจะ monitor ความเร็วจาก
///      GPS ของมือถือไปด้วย ถ้าตรวจพบว่ารถเริ่ม "เคลื่อนที่จริง" (ไม่ใช่แค่
///      GPS drift ตอนจอดนิ่ง) ระบบจะ "ปิดโหมดพักรถให้อัตโนมัติ" ทันที
///      เพื่อให้กลับมาแจ้งเตือนตามปกติโดยไม่ต้องรอผู้ใช้กดปิดเอง
///      (⚠️ จงใจทำแค่ auto-*ปิด* เท่านั้น ไม่ทำ auto-*เปิด* เพราะความเสี่ยง
///      ด้าน safety อยู่ที่ "ปิดช้าเกินไป" ไม่ใช่ "เปิดช้าเกินไป" — การเปิด
///      โหมดพักยังคงต้องให้ผู้ใช้กดเองเสมอ)
///
/// กันการ toggle เพี้ยนจาก GPS drift (ความแม่นยำ GPS ตอนความเร็วต่ำมัก
/// คลาดเคลื่อน 3-10 เมตร ทำให้คำนวณความเร็วได้ผิดๆ เป็นพักๆ) ด้วยการใช้
/// hysteresis: ต้องตรวจพบความเร็วเกิน threshold ต่อเนื่องกันอย่างน้อย
/// [_movingSustainedDuration] ก่อนถึงจะยอมปิดโหมดพักรถ ไม่ใช่ปิดทันทีที่
/// เจอ reading เดียวที่เกินค่า
///
/// ระบบทำงานแบบ fail-safe: ถ้า GPS ใช้ไม่ได้ (permission ถูกปิด, location
/// service ปิด, หรือ error ใดๆ) จะไม่ auto-close ให้ — fallback กลับไปเป็น
/// manual mode เดิมทันที (ผู้ใช้ยังกดปิดเองได้ตามปกติ)
///
/// สถานะจะถูก persist ไว้ใน SharedPreferences จึงยังคงอยู่แม้ปิด-เปิดแอปใหม่
/// ระหว่างที่กำลังพักรถ (กันปัญหาผู้ใช้ปิดแอปแล้วเปิดใหม่แล้วโดนแจ้งเตือนซ้ำ)
class RestModeService {
  RestModeService._();
  static final RestModeService instance = RestModeService._();

  static const _kRestUntilKey = 'rest_mode_until_epoch_ms';
  static const _kRestReasonKey = 'rest_mode_reason';

  // ─────────────────────────────────────────────────────────────────────
  // 🆕 Auto-close จาก GPS: ค่าที่ปรับได้ (tuning)
  // ─────────────────────────────────────────────────────────────────────
  /// ความเร็วขั้นต่ำ (km/h) ที่ถือว่า "รถกำลังเคลื่อนที่จริง"
  /// ตั้งไว้ไม่ต่ำเกินไป เพื่อกัน GPS drift ตอนจอดนิ่ง (มักเพี้ยน 2-5 km/h)
  static const double _movingSpeedThresholdKmh = 12.0;

  /// ต้องตรวจพบความเร็วเกิน threshold ต่อเนื่องกันนานเท่านี้ ก่อนจะยอมปิด
  /// โหมดพักรถ (hysteresis กัน false trigger จาก GPS กระตุกแวบเดียว)
  static const Duration _movingSustainedDuration = Duration(seconds: 4);

  /// ความแม่นยำของตำแหน่งที่ยอมรับ (เมตร) - ถ้า reading แม่นยำน้อยกว่านี้
  /// (accuracy สูงกว่าค่านี้) จะไม่นำมาคำนวณ เพื่อกัน noise
  static const double _maxAcceptableAccuracyMeters = 30.0;

  /// เวลา (เป็น DateTime) ที่โหมดพักรถจะหมดอายุ
  /// ค่าเป็น null หมายถึง "ไม่ได้เปิดโหมดพักรถอยู่"
  final ValueNotifier<DateTime?> restUntil = ValueNotifier<DateTime?>(null);
  final ValueNotifier<String?> restReason = ValueNotifier<String?>(null);

  Timer? _autoExpireTimer;
  Timer? _warningTimer;
  bool _initialized = false;

  // 🆕 GPS auto-close monitoring state
  StreamSubscription<Position>? _positionSubscription;
  DateTime? _movingSince; // เวลาที่เริ่มตรวจพบความเร็วเกิน threshold ต่อเนื่อง

  /// กำลังอยู่ในโหมดพักรถอยู่หรือไม่ ณ ขณะนี้
  bool get isActive =>
      restUntil.value != null && restUntil.value!.isAfter(DateTime.now());

  /// เวลาที่เหลือก่อนโหมดพักรถจะหมดอายุ (ถ้าไม่ได้เปิดอยู่จะได้ Duration.zero)
  Duration get remaining {
    if (!isActive) return Duration.zero;
    return restUntil.value!.difference(DateTime.now());
  }

  /// ต้องเรียกครั้งเดียวตอนแอปเริ่มทำงาน (เช่นใน initState ของ MainLayout)
  /// เพื่อโหลดสถานะที่เคย persist ไว้กลับมา
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final savedMs = prefs.getInt(_kRestUntilKey);
    restReason.value = prefs.getString(_kRestReasonKey);

    if (savedMs != null) {
      final saved = DateTime.fromMillisecondsSinceEpoch(savedMs);
      if (saved.isAfter(DateTime.now())) {
        restUntil.value = saved;
        _scheduleAutoExpire();
        _startMovementMonitoring(); // 🆕 กลับมา monitor GPS ต่อด้วย ถ้ายังอยู่ในช่วงพักรถ
      } else {
        // หมดอายุไปแล้วตั้งแต่ตอนปิดแอป -> เคลียร์ทิ้ง
        await prefs.remove(_kRestUntilKey);
        await prefs.remove(_kRestReasonKey);
      }
    }

    try {
      final devices = await ApiService.instance.devices();
      if (devices.isNotEmpty) {
        final raw = devices.first['rest_mode_until']?.toString();
        final serverUntil = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
        if (serverUntil != null && serverUntil.isAfter(DateTime.now())) {
          restUntil.value = serverUntil;
          restReason.value = devices.first['rest_mode_reason']?.toString();
          await _persistLocal();
          _scheduleAutoExpire();
          _startMovementMonitoring();
        }
      }
    } catch (_) {
      // Offline startup continues with the locally persisted state.
    }

  }

  /// เปิดโหมดพักรถเป็นระยะเวลา [duration]
  /// เช่น RestModeService.instance.activate(const Duration(minutes: 15))
  Future<void> activate(Duration duration, {String reason = 'break'}) async {
    final devices = await ApiService.instance.devices();
    if (devices.isEmpty) {
      throw const ApiException('ไม่พบอุปกรณ์สำหรับเปิดโหมดพักรถ');
    }
    await ApiService.instance.activateRestMode(
      deviceId: devices.first['device_id'],
      minutes: duration.inMinutes,
      reason: reason,
    );

    final until = DateTime.now().add(duration);
    restUntil.value = until;
    restReason.value = reason;
    await _persistLocal();

    _scheduleAutoExpire();
    _startMovementMonitoring(); // 🆕 เริ่มจับตาความเร็ว GPS เพื่อ auto-close
  }

  /// ยกเลิกโหมดพักรถก่อนครบเวลา (เช่น ผู้ใช้พร้อมขับต่อแล้ว หรือระบบ
  /// auto-close จาก GPS ตรวจพบว่ารถเคลื่อนที่จริง)
  Future<void> cancel() async {
    final devices = await ApiService.instance.devices();
    if (devices.isNotEmpty) {
      await ApiService.instance.cancelRestMode(
        deviceId: devices.first['device_id'],
      );
    }
    restUntil.value = null;
    restReason.value = null;
    _autoExpireTimer?.cancel();
    _warningTimer?.cancel();
    _stopMovementMonitoring();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRestUntilKey);
    await prefs.remove(_kRestReasonKey);
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final until = restUntil.value;
    if (until != null) {
      await prefs.setInt(_kRestUntilKey, until.millisecondsSinceEpoch);
    }
    final reason = restReason.value;
    if (reason != null) await prefs.setString(_kRestReasonKey, reason);
  }

  /// ตั้งเวลาให้ปิดโหมดพักรถอัตโนมัติเมื่อครบกำหนด โดยไม่ต้องรอ poll
  void _scheduleAutoExpire() {
    _autoExpireTimer?.cancel();
    _warningTimer?.cancel();
    if (restUntil.value == null) return;

    final delay = restUntil.value!.difference(DateTime.now());
    if (delay.isNegative) {
      restUntil.value = null;
      restReason.value = null;
      return;
    }

    final warningDelay = delay - const Duration(minutes: 1);
    if (!warningDelay.isNegative) {
      _warningTimer = Timer(warningDelay, () {
        unawaited(PushNotificationService.instance.showRestModeEndingSoon());
      });
    }

    _autoExpireTimer = Timer(delay, () {
      restUntil.value = null;
      restReason.value = null;
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove(_kRestUntilKey);
        prefs.remove(_kRestReasonKey);
      });
      _stopMovementMonitoring();
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🆕 GPS Auto-close: monitor ความเร็วระหว่างเปิดโหมดพักรถ
  // ═══════════════════════════════════════════════════════════════════

  /// เริ่ม stream ตำแหน่ง/ความเร็วจาก GPS เพื่อคอยเช็คว่ารถเคลื่อนที่จริง
  /// หรือไม่ ระหว่างที่เปิดโหมดพักรถอยู่ ถ้าใช้ GPS ไม่ได้ (permission/
  /// service ปิด หรือ error ใดๆ) จะเงียบๆ ไม่ auto-close ให้ (fail-safe
  /// กลับไปเป็น manual mode เดิม)
  Future<void> _startMovementMonitoring() async {
    if (_positionSubscription != null) return; // กำลัง monitor อยู่แล้ว
    _movingSince = null;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('RestModeService: Location service ปิดอยู่ -> ข้าม auto-close');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('RestModeService: ไม่ได้รับสิทธิ์ location -> ข้าม auto-close');
        return;
      }

      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0, // อยากได้ update ตามเวลา ไม่ใช่ตามระยะทาง เพื่อจับความเร็วได้ไว
      );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        _onPositionUpdate,
        onError: (e) {
          debugPrint('RestModeService: GPS stream error (ไม่กระทบผู้ใช้): $e');
          // fail-safe: ปล่อยให้ manual cancel ยังใช้ได้ตามปกติ ไม่ throw ต่อ
        },
      );
    } catch (e) {
      debugPrint('RestModeService: เริ่ม GPS monitoring ไม่สำเร็จ (ไม่กระทบผู้ใช้): $e');
    }
  }

  void _stopMovementMonitoring() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _movingSince = null;
  }

  void _onPositionUpdate(Position position) {
    if (!isActive) return;

    // ทิ้ง reading ที่ไม่แม่นยำพอ (accuracy เป็นเมตร ยิ่งน้อยยิ่งแม่น)
    if (position.accuracy > _maxAcceptableAccuracyMeters) {
      return;
    }

    final speedKmh = position.speed * 3.6; // Geolocator ให้ speed เป็น m/s
    final now = DateTime.now();

    if (speedKmh >= _movingSpeedThresholdKmh) {
      _movingSince ??= now;

      final movingDuration = now.difference(_movingSince!);
      if (movingDuration >= _movingSustainedDuration) {
        debugPrint(
          'RestModeService: ตรวจพบรถเคลื่อนที่ต่อเนื่อง '
          '(${speedKmh.toStringAsFixed(1)} km/h นาน ${movingDuration.inSeconds} วิ) '
          '-> ปิดโหมดพักรถอัตโนมัติ',
        );
        unawaited(cancel());
      }
    } else {
      // ความเร็วตกลงมาต่ำกว่า threshold -> รีเซ็ตตัวจับเวลาความต่อเนื่อง
      _movingSince = null;
    }
  }

  void dispose() {
    _autoExpireTimer?.cancel();
    _warningTimer?.cancel();
      _stopMovementMonitoring();
      unawaited(PushNotificationService.instance.showRestModeEnded());
  }
}
