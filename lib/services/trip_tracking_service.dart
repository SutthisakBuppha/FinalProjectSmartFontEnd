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
  static const _destinationKey = 'active_navigation_destination';

  StreamSubscription<Position>? _subscription;
  String? _tripId;
  String? _destinationName;
  bool _sendingLocation = false;

  bool get isTracking => _tripId != null;
  String? get tripId => _tripId;
  String? get destinationName => _destinationName;

  Future<void> restore() async {
    final preferences = await SharedPreferences.getInstance();
    _tripId ??= preferences.getString(_tripIdKey);
    _destinationName ??= preferences.getString(_destinationKey);
    if (_tripId != null && _subscription == null) {
      _startPositionStream();
    }
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
    );
    final createdTripId = trip['trip_id']?.toString();
    if (createdTripId == null || createdTripId.isEmpty) {
      throw const ApiException('เซิร์ฟเวอร์ไม่ได้ส่งหมายเลขทริปกลับมา');
    }

    _tripId = createdTripId;
    _destinationName = destinationName;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tripIdKey, createdTripId);
    await preferences.setString(_destinationKey, destinationName);

    await _sendPosition(initialPosition);
    _startPositionStream();
    return createdTripId;
  }

  void _startPositionStream() {
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

    _subscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (position) => _sendPosition(position),
      onError: (Object error) {
        debugPrint('Trip GPS stream error: $error');
      },
    );
  }

  Future<void> _sendPosition(Position position) async {
    final activeTripId = _tripId;
    if (activeTripId == null || _sendingLocation) return;

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

    await _subscription?.cancel();
    _subscription = null;

    final trip = await ApiService.instance.completeTrip(activeTripId);
    await _clearLocalTrip();
    return trip;
  }

  Future<void> _clearLocalTrip() async {
    _tripId = null;
    _destinationName = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tripIdKey);
    await preferences.remove(_destinationKey);
  }
}
