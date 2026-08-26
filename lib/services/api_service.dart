import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  final http.Client _client = http.Client();

  String? _token;
  String? _driverId;
  Map<String, dynamic>? _driver;

  String get baseUrl => _baseUrl;
  bool get isLoggedIn => _token != null && _driverId != null;
  String? get driverId => _driverId;
  Map<String, dynamic>? get currentDriver => _driver;

  static final String _baseUrl = _resolveBaseUrl();

  static String _resolveBaseUrl() {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) {
      return _normalizeBaseUrl(fromEnv);
    }

    return 'http://smartdriver.lnw.mn/api';
  }

  static String _normalizeBaseUrl(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  Future<Map<String, dynamic>> loginDriver({
    required String username,
    required String password,
  }) async {
    final response = await _request(
      'POST',
      'driver/login',
      body: {'username': username, 'password': password},
      requireAuth: false,
    );

    return _applyAuthResponse(
      response,
      'Login response does not include driver token.',
    );
  }

  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
  }) async {
    final response = await _request(
      'POST',
      'driver/google-login',
      body: {'id_token': idToken},
      requireAuth: false,
    );

    return _applyAuthResponse(
      response,
      'Google login response does not include driver token.',
    );
  }

  Future<Map<String, dynamic>> registerDriver({
    required String name,
    required String username,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _request(
      'POST',
      'driver/register',
      body: {
        'name': name,
        'username': username,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
      requireAuth: false,
    );

    return _applyAuthResponse(
      response,
      'Register response does not include driver token.',
    );
  }

  Future<void> forgotPasswordDriver({required String email}) async {
    await _request(
      'POST',
      'driver/forgot-password',
      body: {'email': email},
      requireAuth: false,
    );
  }

  Future<void> resetPasswordDriver({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _request(
      'POST',
      'driver/reset-password',
      body: {
        'email': email,
        'otp': otp,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
      requireAuth: false,
    );
  }

  Future<void> logoutDriver() async {
    if (!isLoggedIn) {
      clearSession();
      return;
    }

    try {
      await _request('POST', 'drivers/$_driverId/logout');
    } finally {
      clearSession();
    }
  }

  void clearSession() {
    _token = null;
    _driverId = null;
    _driver = null;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_kTokenKey);
      prefs.remove(_kDriverIdKey);
      prefs.remove(_kLastRouteKey);
    });
  }

  static const _kTokenKey = 'auth_token';
  static const _kDriverIdKey = 'auth_driver_id';

  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kTokenKey);
    final driverId = prefs.getString(_kDriverIdKey);

    if (token == null || driverId == null) return false;

    _token = token;
    _driverId = driverId;
    return true;
  }

  Future<void> _persistSession(String token, String driverId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
    await prefs.setString(_kDriverIdKey, driverId);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🆕 จำ "หน้าล่าสุด" ที่ผู้ใช้อยู่ไว้ เพื่อให้ SplashScreen พาไปหน้าเดิม
  // ได้เวลา refresh (เว็บ) หรือปิด-เปิดแอปใหม่ (มือถือ) แทนที่จะเด้งไป
  // หน้าคงที่หน้าใดหน้าหนึ่งเสมอ
  //
  // วิธีใช้: ให้แต่ละหน้าหลัก (home, devices, profile, ฯลฯ) เรียก
  // ApiService.instance.saveLastRoute('ชื่อ_key_เฉพาะของหน้านั้น') ใน initState()
  // ═══════════════════════════════════════════════════════════════════
  static const _kLastRouteKey = 'last_route';

  Future<void> saveLastRoute(String routeKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastRouteKey, routeKey);
  }

  Future<String?> getLastRoute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastRouteKey);
  }

  Future<void> clearLastRoute() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastRouteKey);
  }

  Future<Map<String, dynamic>> dashboard() async {
    final response = await _request(
      'GET',
      'drivers/${_requireDriverId()}/dashboard',
    );
    return _dataMap(response);
  }

  Future<Map<String, dynamic>> driverProfile() async {
    final response = await _request('GET', 'app/drivers/${_requireDriverId()}');
    final profile = _dataMap(response);
    _driver = profile;
    return profile;
  }

  Future<Map<String, dynamic>> updateDriverProfile({
    String? name,
    String? avatarUrl,
    String? status,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (status != null) body['status'] = status;

    final response = await _request(
      'PATCH',
      'app/drivers/${_requireDriverId()}',
      body: body,
    );
    final profile = _dataMap(response);
    _driver = profile;
    return profile;
  }

  Future<String> uploadDriverAvatar({
    required List<int> bytes,
    required String fileName,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/app/drivers/${_requireDriverId()}/avatar'),
    );
    request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(
      http.MultipartFile.fromBytes('avatar', bytes, filename: fileName),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final decoded = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _messageFrom(decoded) ??
            'Avatar upload failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    final profile = _dataMap(
      decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded},
    );
    _driver = profile;
    final avatarUrl = profile['avatar_url']?.toString();
    if (avatarUrl == null || avatarUrl.isEmpty) {
      throw const ApiException(
        'Avatar upload succeeded but no URL was returned.',
      );
    }
    return avatarUrl;
  }

  Future<List<Map<String, dynamic>>> devices() async {
    final response = await _request(
      'GET',
      'app/drivers/${_requireDriverId()}/devices',
    );
    return _dataList(response);
  }

  Future<Map<String, dynamic>> createDevice({
    required String serialNumber,
    required String deviceName,
    required String deviceType,
  }) async {
    final response = await _request(
      'POST',
      'app/drivers/${_requireDriverId()}/devices',
      body: {
        'serial_number': serialNumber,
        'device_name': deviceName,
        'device_type': deviceType,
        'status': 'ออฟไลน์',
        'is_active': true,
      },
    );
    return _dataMap(response);
  }

  Future<bool> registerDevice(String serialNumber) async {
    try {
      await createDevice(
        serialNumber: serialNumber,
        deviceName: 'อุปกรณ์ใหม่ #$serialNumber',
        deviceType: 'ESP32-CAM',
      );
      return true;
    } on ApiException {
      // The server may have committed the first request while its response was
      // lost. Verify current state so a retry can continue to the device page.
      try {
        final registeredDevices = await devices();
        final wantedSerial = serialNumber.trim().toUpperCase();
        return registeredDevices.any(
          (device) =>
              device['serial_number']?.toString().trim().toUpperCase() ==
              wantedSerial,
        );
      } catch (_) {
        return false;
      }
    }
  }

  Future<Map<String, dynamic>> updateDevice({
    required dynamic deviceId,
    String? serialNumber,
    String? deviceName,
    String? deviceType,
    String? status,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (serialNumber != null) body['serial_number'] = serialNumber;
    if (deviceName != null) body['device_name'] = deviceName;
    if (deviceType != null) body['device_type'] = deviceType;
    if (status != null) body['status'] = status;
    if (isActive != null) body['is_active'] = isActive;

    final response = await _request(
      'PATCH',
      'app/drivers/${_requireDriverId()}/devices/$deviceId',
      body: body,
    );
    return _dataMap(response);
  }

  Future<Map<String, dynamic>?> deviceSetting(dynamic deviceId) async {
    final response = await _request(
      'GET',
      'app/drivers/${_requireDriverId()}/devices/$deviceId/setting',
    );
    return _nullableDataMap(response);
  }

  Future<void> upsertDeviceSetting({
    required dynamic deviceId,
    required int volumeLevel,
    required bool soundEnabled,
    required String activeTone,
  }) async {
    await _request(
      'PUT',
      'app/drivers/${_requireDriverId()}/devices/$deviceId/setting',
      body: {
        'volume_level': volumeLevel,
        'sound_enabled': soundEnabled,
        'active_tone': activeTone,
      },
    );
  }

  Future<void> removeDevice(dynamic deviceId) async {
    await _request(
      'DELETE',
      'app/drivers/${_requireDriverId()}/devices/$deviceId',
    );
  }

  Future<void> resetDeviceWifi(String ipAddress) async {
    final cleanIp = ipAddress
        .trim()
        .replaceFirst(RegExp(r'^https?://'), '')
        .split('/')
        .first
        .split(':')
        .first;

    if (cleanIp.isEmpty) {
      throw const ApiException('ไม่พบ IP Address ของอุปกรณ์');
    }

    try {
      final response = await _client
          .get(Uri.parse('http://$cleanIp:82/wifi/reset'))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'อุปกรณ์ปฏิเสธคำสั่งรีเซ็ต Wi-Fi (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'ส่งคำสั่งล้าง Wi-Fi ไม่สำเร็จ กรุณาตรวจว่ามือถือกับอุปกรณ์อยู่ Wi-Fi เดียวกันและอุปกรณ์ออนไลน์',
      );
    }
  }

  Future<List<Map<String, dynamic>>> trips({dynamic deviceId}) async {
    final response = await _request(
      'GET',
      'app/drivers/${_requireDriverId()}/trips',
      query: {if (deviceId != null) 'device_id': deviceId.toString()},
    );
    return _dataList(response);
  }

  Future<Map<String, dynamic>> startTrip({dynamic deviceId}) async {
    final response = await _request(
      'POST',
      'app/drivers/${_requireDriverId()}/trips',
      body: {
        if (deviceId != null) 'device_id': deviceId.toString(),
        'start_time': DateTime.now().toUtc().toIso8601String(),
        'distance': 0,
        'status': 'active',
      },
    );
    return _dataMap(response);
  }

  Future<Map<String, dynamic>> addTripLocation({
    required dynamic tripId,
    required double latitude,
    required double longitude,
    double? speed,
  }) async {
    final response = await _request(
      'POST',
      'app/drivers/${_requireDriverId()}/trips/$tripId/locations',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        if (speed != null && speed >= 0) 'speed': speed,
      },
    );
    return _dataMap(response);
  }

  Future<Map<String, dynamic>> completeTrip(dynamic tripId) async {
    final response = await _request(
      'PATCH',
      'app/drivers/${_requireDriverId()}/trips/$tripId',
      body: {
        'end_time': DateTime.now().toUtc().toIso8601String(),
        'status': 'completed',
      },
    );
    return _dataMap(response);
  }

  Future<Map<String, dynamic>> tripDetail(dynamic tripId) async {
    final response = await _request(
      'GET',
      'app/drivers/${_requireDriverId()}/trips/$tripId',
    );
    return _dataMap(response);
  }

  Future<List<Map<String, dynamic>>> tripLocations(dynamic tripId) async {
    final response = await _request(
      'GET',
      'app/drivers/${_requireDriverId()}/trips/$tripId/locations',
    );
    return _dataList(response);
  }

  Future<List<Map<String, dynamic>>> alerts({
    dynamic tripId,
    bool todayOnly = false,
  }) async {
    final response = await _request(
      'GET',
      'app/drivers/${_requireDriverId()}/alerts',
      query: {
        if (tripId != null) 'trip_id': tripId.toString(),
        if (todayOnly) 'today': '1',
      },
    );
    return _dataList(response);
  }

  Future<Map<String, dynamic>> alertSummary() async {
    final response = await _request(
      'GET',
      'drivers/${_requireDriverId()}/alerts/summary',
    );
    return _dataMap(response);
  }

  Future<List<Map<String, dynamic>>> notifications({bool? isRead}) async {
    final response = await _request(
      'GET',
      'app/drivers/${_requireDriverId()}/notifications',
      query: {if (isRead != null) 'is_read': isRead ? '1' : '0'},
    );
    return _dataList(response);
  }

  Future<Map<String, dynamic>> markNotificationRead(
    dynamic notificationId,
  ) async {
    final response = await _request(
      'PATCH',
      'app/drivers/${_requireDriverId()}/notifications/$notificationId/read',
    );
    return _dataMap(response);
  }

  Future<void> markAllNotificationsRead() async {
    await _request(
      'PATCH',
      'app/drivers/${_requireDriverId()}/notifications/read-all',
    );
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _request('GET', 'app/drivers/${_requireDriverId()}');
    _driver = _dataMap(response);
    return _driver!;
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    String? password,
  }) async {
    final response = await _request(
      'PATCH',
      'app/drivers/${_requireDriverId()}',
      body: {
        'name': name,
        if (password != null && password.isNotEmpty) 'password': password,
      },
    );
    _driver = _dataMap(response);
    return _driver!;
  }

  Future<List<Map<String, dynamic>>> getMyDevices() async {
    final response = await _request(
      'GET',
      'app/drivers/${_requireDriverId()}/devices',
    );
    return _dataList(response);
  }

  Future<Map<String, dynamic>> updateDeviceSettings({
    required dynamic deviceId,
    required int volumeLevel,
    required bool soundEnabled,
    required String activeTone,
  }) async {
    final response = await _request(
      'PATCH',
      'app/drivers/${_requireDriverId()}/devices/$deviceId/setting',
      body: {
        'volume_level': volumeLevel,
        'sound_enabled': soundEnabled,
        'active_tone': activeTone,
      },
    );
    return _dataMap(response);
  }

  // ═══════════════════════════════════════════════════════════════════
  // FCM Push Notification token registration
  // ═══════════════════════════════════════════════════════════════════

  Future<void> registerFcmToken({
    required String token,
    required String platform,
  }) async {
    await _request(
      'POST',
      'app/drivers/${_requireDriverId()}/fcm-token',
      body: {'token': token, 'platform': platform},
    );
  }

  Future<void> unregisterFcmToken({required String token}) async {
    await _request(
      'DELETE',
      'app/drivers/${_requireDriverId()}/fcm-token',
      body: {'token': token},
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Rest Mode
  // ═══════════════════════════════════════════════════════════════════

  Future<void> activateRestMode({
    required dynamic deviceId,
    required int minutes,
  }) async {
    await _request(
      'POST',
      'app/drivers/${_requireDriverId()}/devices/$deviceId/rest-mode',
      body: {'minutes': minutes},
    );
  }

  Future<void> cancelRestMode({required dynamic deviceId}) async {
    await _request(
      'DELETE',
      'app/drivers/${_requireDriverId()}/devices/$deviceId/rest-mode',
    );
  }

  String _requireDriverId() {
    final id = _driverId;
    if (_token == null || id == null) {
      throw const ApiException('Please log in before using this feature.');
    }
    return id;
  }

  Map<String, dynamic> _applyAuthResponse(
    Map<String, dynamic> response,
    String errorMessage,
  ) {
    final token = response['token']?.toString();
    final driverId = _toString(response['driver_id']);

    if (token == null || token.isEmpty || driverId == null) {
      throw ApiException(errorMessage);
    }

    _token = token;
    _driverId = driverId;
    _driver = {
      'driver_id': driverId,
      'name': response['name'],
      'avatar_url': response['avatar_url'],
      'status': response['status'],
    };

    _persistSession(token, driverId);

    return Map<String, dynamic>.from(_driver!);
  }

  Future<List<Map<String, dynamic>>> nearbyPlaces({
    required double latitude,
    required double longitude,
    double radiusMeters = 5000,
  }) async {
    final response = await _request(
      'GET',
      'nearby-places',
      query: {'lat': latitude, 'lng': longitude, 'radius': radiusMeters},
    );

    final list = response['data'];
    if (list is List) {
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool requireAuth = true,
  }) async {
    if (requireAuth && _token == null) {
      throw const ApiException('Please log in again.');
    }

    final uri = _uri(path, query);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (requireAuth) 'Authorization': 'Bearer $_token',
    };

    late http.Response response;
    final encodedBody = body == null ? null : jsonEncode(body);

    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: headers);
      case 'POST':
        response = await _client.post(uri, headers: headers, body: encodedBody);
      case 'PUT':
        response = await _client.put(uri, headers: headers, body: encodedBody);
      case 'PATCH':
        response = await _client.patch(
          uri,
          headers: headers,
          body: encodedBody,
        );
      case 'DELETE':
        response = await _client.delete(
          uri,
          headers: headers,
          body: encodedBody,
        );
      default:
        throw ApiException('Unsupported request method: $method');
    }

    final decoded = _decodeResponse(response);

    if (response.statusCode == 401) {
      clearSession();
      throw ApiException(
        _messageFrom(decoded) ?? 'Session expired. Please log in again.',
        statusCode: 401,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _messageFrom(decoded) ?? 'Request failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (decoded is Map<String, dynamic> && decoded['success'] == false) {
      throw ApiException(_messageFrom(decoded) ?? 'Request failed.');
    }

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {'data': decoded};
  }

  Uri _uri(String path, Map<String, dynamic>? query) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('$_baseUrl/$cleanPath');

    if (query == null || query.isEmpty) {
      return uri;
    }

    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        ...query.map((key, value) => MapEntry(key, value.toString())),
      },
    );
  }

  dynamic _decodeResponse(http.Response response) {
    if (response.bodyBytes.isEmpty) {
      return null;
    }

    final body = utf8.decode(response.bodyBytes);
    try {
      return jsonDecode(body);
    } on FormatException {
      return {'message': body};
    }
  }

  String? _messageFrom(dynamic decoded) {
    if (decoded is! Map) {
      return null;
    }

    final message = decoded['message'];
    if (message is String && message.isNotEmpty) {
      return message;
    }

    final errors = decoded['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
      return first.toString();
    }

    return null;
  }

  Map<String, dynamic> _dataMap(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic>? _nullableDataMap(Map<String, dynamic> response) {
    final data = response['data'];
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  List<Map<String, dynamic>> _dataList(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  String? _toString(dynamic value) {
    if (value is String) return value;
    if (value is int) return value.toString();
    if (value is num) return value.toInt().toString();
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🆕 Notifications summary (today_events / max_risk สำหรับหน้า NotificationScreen)
  // ═══════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> notificationsSummary() async {
    final response = await _request(
      'GET',
      'app/drivers/${_requireDriverId()}/notifications/summary',
    );
    return _dataMap(response);
  }

  Future<Map<String, dynamic>?> latestAlert() async {
    final response = await _request(
      'GET',
      'driver-latest-alert',
      query: {'driver_id': _requireDriverId()},
      requireAuth: false,
    );
    return _nullableDataMap(response);
  }
}
