import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import '../utils/device_status.dart';

/// Records a navigation trip independently from Google Maps.
///
/// Google Maps remains responsible for turn-by-turn navigation. This service
/// keeps a foreground GPS stream, sends precise points to Laravel, and lets
/// the server calculate the authoritative travelled distance.
class TripTrackingService {
  TripTrackingService._();

  static final TripTrackingService instance = TripTrackingService._();

  static const _tripIdKey = 'active_navigation_trip_id';
  static const _deviceIdKey = 'active_navigation_device_id';
  static const _destinationKey = 'active_navigation_destination';
  static const _externalNavigationKey = 'is_navigating_to_rest_stop';
  static const _restStopTripIdKey = 'active_rest_stop_trip_id';
  static const _restUntilKey = 'rest_mode_until_epoch_ms';

  StreamSubscription<Position>? _subscription;
  String? _tripId;
  String? _deviceId;
  String? _destinationName;
  String? _restStopTripId;
  bool _sendingLocation = false;
  bool _isNavigatingToRestStop = false;
  bool _isPaused = false;

  bool get isTracking => _tripId != null;
  bool get isPaused => _isPaused;
  String? get tripId => _tripId;
  String? get destinationName => _destinationName;
  bool get isNavigatingToRestStop => _isNavigatingToRestStop;
  bool get isRestStopTracking => _restStopTripId != null;

  Future<void> restore() async {
    final preferences = await SharedPreferences.getInstance();
    _tripId ??= preferences.getString(_tripIdKey);
    _deviceId ??= preferences.getString(_deviceIdKey);
    _destinationName ??= preferences.getString(_destinationKey);
    _restStopTripId ??= preferences.getString(_restStopTripIdKey);
    _isNavigatingToRestStop =
        preferences.getBool(_externalNavigationKey) ?? false;
    final restUntilMs = preferences.getInt(_restUntilKey);
    _isPaused =
        restUntilMs != null &&
        DateTime.fromMillisecondsSinceEpoch(
          restUntilMs,
        ).isAfter(DateTime.now());
    if (_tripId != null && _subscription == null) {
      _startPositionStream();
    }
  }

  Future<void> beginRestStopNavigation() async {
    _isNavigatingToRestStop = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_externalNavigationKey, true);
  }

  Future<String> startRestStopTrip({
    required Position initialPosition,
    required String destinationName,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    if (_tripId == null) {
      throw const ApiException('กรุณาเริ่มทริปหลักก่อนนำทางไปจุดพักรถ');
    }
    if (_restStopTripId != null) return _restStopTripId!;

    var deviceId = _deviceId;
    if (deviceId == null) {
      final devices = await ApiService.instance.devices();
      deviceId = devices.isEmpty
          ? null
          : devices.first['device_id']?.toString();
      if (deviceId != null) {
        _deviceId = deviceId;
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(_deviceIdKey, deviceId);
      }
    }
    final trip = await ApiService.instance.startTrip(
      deviceId: deviceId,
      tripType: 'rest_stop',
      parentTripId: _tripId,
      destinationName: destinationName,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
    );
    final id = trip['trip_id']?.toString();
    if (id == null || id.isEmpty) {
      throw const ApiException('เซิร์ฟเวอร์ไม่ได้ส่งหมายเลขเส้นทางจุดพัก');
    }
    _restStopTripId = id;
    _destinationName = destinationName;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_restStopTripIdKey, id);
    await preferences.setString(_destinationKey, destinationName);
    await beginRestStopNavigation();
    // Do not keep the driver waiting for two location-upload requests before
    // Google Maps opens. _sendPosition handles its own network errors.
    unawaited(_sendPosition(initialPosition));
    return id;
  }

  Future<Map<String, dynamic>?> finishRestStopTrip() async {
    final id = _restStopTripId;
    if (id == null) return null;
    final trip = await ApiService.instance.completeTrip(id);
    _restStopTripId = null;
    _isNavigatingToRestStop = false;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_restStopTripIdKey);
    await preferences.remove(_externalNavigationKey);
    return trip;
  }

  Future<void> endRestStopNavigation() async {
    _isNavigatingToRestStop = false;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_externalNavigationKey);
  }

  Future<String> start({
    required Position initialPosition,
    required String destinationName,
  }) async {
    if (_tripId != null) return _tripId!;

    final devices = await ApiService.instance.devices();
    Map<String, dynamic>? selectedDevice;
    for (final device in devices) {
      if (isDeviceOnline(device)) {
        selectedDevice = device;
        break;
      }
    }
    selectedDevice ??= devices.isNotEmpty ? devices.first : null;

    final trip = await ApiService.instance.startTrip(
      deviceId: selectedDevice?['device_id'],
      destinationName: destinationName,
    );
    final createdTripId = trip['trip_id']?.toString();
    if (createdTripId == null || createdTripId.isEmpty) {
      throw const ApiException('เซิร์ฟเวอร์ไม่ได้ส่งหมายเลขทริปกลับมา');
    }

    _tripId = createdTripId;
    _deviceId = selectedDevice?['device_id']?.toString();
    _isPaused = false;
    _destinationName = destinationName;
    // A new trip may show the rest-stop AlertScreen once. After the driver
    // starts navigation, the flag remains set until this trip is finished.
    _isNavigatingToRestStop = false;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_externalNavigationKey);
    await preferences.setString(_tripIdKey, createdTripId);
    if (_deviceId != null) {
      await preferences.setString(_deviceIdKey, _deviceId!);
    }
    await preferences.setString(_destinationKey, destinationName);

    await _sendPosition(initialPosition);
    _startPositionStream();
    return createdTripId;
  }

  /// Temporarily stops recording GPS points without completing the trip.
  Future<void> pause() async {
    if (_tripId == null || _isPaused) return;
    _isPaused = true;
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Continues recording the same trip after rest mode ends.
  void resume() {
    if (_tripId == null || !_isPaused) return;
    _isPaused = false;
    _startPositionStream();
  }

  void _startPositionStream() {
    if (_tripId == null || _isPaused) return;
    _subscription?.cancel();

    late final LocationSettings settings;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        intervalDuration: Duration(seconds: 5),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'Smart Drive Guard กำลังบันทึกการเดินทาง',
          notificationText: 'กำลังคำนวณระยะทางจากตำแหน่ง GPS',
          enableWakeLock: true,
        ),
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      );
    }

    _subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
          (position) => _sendPosition(position),
          onError: (Object error) {
            debugPrint('Trip GPS stream error: $error');
          },
        );
  }

  Future<void> _sendPosition(Position position) async {
    final activeTripId = _tripId;
    if (activeTripId == null || _isPaused || _sendingLocation) return;

    // Ignore inaccurate fixes to reduce GPS drift while the vehicle is still.
    if (position.accuracy > 50) return;

    _sendingLocation = true;
    try {
      await ApiService.instance.addTripLocation(
        tripId: activeTripId,
        latitude: position.latitude,
        longitude: position.longitude,
        speed: position.speed >= 0 ? position.speed : null,
      );
      final restStopTripId = _restStopTripId;
      if (restStopTripId != null) {
        await ApiService.instance.addTripLocation(
          tripId: restStopTripId,
          latitude: position.latitude,
          longitude: position.longitude,
          speed: position.speed >= 0 ? position.speed : null,
        );
      }
    } catch (error) {
      // Keep tracking. A later GPS point can still be recorded when the
      // internet connection becomes available again.
      debugPrint('Upload trip location failed: $error');
    } finally {
      _sendingLocation = false;
    }
  }

  Future<Map<String, dynamic>?> finish() async {
    final activeTripId = _tripId;
    if (activeTripId == null) return null;
    if (_restStopTripId != null) {
      throw const ApiException(
        'กรุณาจบเส้นทางไปจุดพักในหน้าแผนที่ก่อนจบทริปหลัก',
      );
    }

    await _subscription?.cancel();
    _subscription = null;

    try {
      final trip = await ApiService.instance.completeTrip(activeTripId);
      await _clearLocalTrip();
      return trip;
    } catch (_) {
      // หากเซิร์ฟเวอร์หรืออินเทอร์เน็ตล้มเหลว ทริปยังไม่จบ จึงต้องกลับมา
      // บันทึก GPS ต่อแทนที่จะปล่อยให้สถานะค้างแต่หยุดเก็บเส้นทางเงียบ ๆ
      _startPositionStream();
      rethrow;
    }
  }

  Future<void> _clearLocalTrip() async {
    _tripId = null;
    _deviceId = null;
    _isPaused = false;
    _destinationName = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tripIdKey);
    await preferences.remove(_deviceIdKey);
    await preferences.remove(_destinationKey);
    await preferences.remove(_externalNavigationKey);
    await preferences.remove(_restStopTripIdKey);
    _restStopTripId = null;
    _isNavigatingToRestStop = false;
  }
}
