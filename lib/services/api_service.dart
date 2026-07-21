import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  String? _driverId;  // เปลี่ยนจาก int? เป็น String? เนื่องจาก ID เป็น CHAR แล้ว
  Map<String, dynamic>? _driver;

  String get baseUrl => _baseUrl;
  bool get isLoggedIn => _token != null && _driverId != null;
  String? get driverId => _driverId;  // เปลี่ยน return type จาก int? เป็น String?
  Map<String, dynamic>? get currentDriver => _driver;

  static final String _baseUrl = _resolveBaseUrl();

  static String _resolveBaseUrl() {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) {
      return _normalizeBaseUrl(fromEnv);
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }

    return 'http://127.0.0.1:8000/api';
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

  // / Sign in (or auto-register) a driver using a Google ID token.
  // /
  // / [idToken] must be the ID token obtained from `GoogleSignInAuthentication`
  // / on the Flutter side. The backend verifies it directly with Google.
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
    required String username, // เพิ่มใหม่
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _request(
      'POST',
      'driver/register',
      body: {
        'name': name,
        'username': username, // เพิ่มใหม่
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
    // ล้างค่าที่เคยจำไว้ใน local storage ด้วย (ไม่ await เพราะ clearSession() เป็น sync)
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_kTokenKey);
      prefs.remove(_kDriverIdKey);
    });
  }

  static const _kTokenKey = 'auth_token';
  static const _kDriverIdKey = 'auth_driver_id';

  /// เรียกครั้งเดียวตอนแอปเริ่มทำงาน (splash) เพื่อโหลด session ที่เคย login ค้างไว้
  /// คืน true ถ้ามี token เก่าอยู่ (ยังไม่ได้ตรวจกับ backend ว่า token หมดอายุหรือยัง)
  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kTokenKey);
    // เปลี่ยนจาก getInt เป็น getString เนื่องจาก driverId เป็น String แล้ว
    final driverId = prefs.getString(_kDriverIdKey);

    if (token == null || driverId == null) return false;

    _token = token;
    _driverId = driverId;
    return true;
  }

  // เปลี่ยน driverId parameter จาก int เป็น String
  Future<void> _persistSession(String token, String driverId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
    // เปลี่ยนจาก setInt เป็น setString
    await prefs.setString(_kDriverIdKey, driverId);
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

  /// ลงทะเบียนอุปกรณ์ใหม่ด้วย Serial Number อย่างเดียว
  /// (ตั้งชื่อ/ประเภทเริ่มต้นให้อัตโนมัติ เพราะหน้าจอมีแค่ช่อง S/N)
  Future<bool> registerDevice(String serialNumber) async {
    try {
      await createDevice(
        serialNumber: serialNumber,
        deviceName: 'อุปกรณ์ใหม่ #$serialNumber',
        deviceType: 'ESP32-CAM',
      );
      return true;
    } on ApiException {
      return false;
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

  Future<List<Map<String, dynamic>>> trips({dynamic deviceId}) async {
    final response = await _request(
      'GET',
      'app/drivers/${_requireDriverId()}/trips',
      query: {if (deviceId != null) 'device_id': deviceId.toString()},
    );
    return _dataList(response);
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

  Future<List<Map<String, dynamic>>> alerts({dynamic tripId}) async {
    final response = await _request(
      'GET',
      'app/drivers/${_requireDriverId()}/alerts',
      query: {if (tripId != null) 'trip_id': tripId.toString()},
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

  /// ดึงข้อมูลโปรไฟล์ล่าสุดของ Driver ที่ล็อกอินอยู่
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _request('GET', 'app/drivers/${_requireDriverId()}');
    _driver = _dataMap(response);
    return _driver!;
  }

  /// อัปเดตข้อมูลโปรไฟล์ (สำหรับหน้า ProfileEditScreen)
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

  /// ดึงรายการอุปกรณ์เฉพาะของ Driver คนนี้
  Future<List<Map<String, dynamic>>> getMyDevices() async {
    final response = await _request(
      'GET',
      'app/drivers/${_requireDriverId()}/devices',
    );
    return _dataList(response);
  }

  /// อัปเดตตั้งค่าเสียงอุปกรณ์ (สำหรับหน้า DeviceCustomizationScreen)
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

  // เปลี่ยน return type จาก int เป็น String
  String _requireDriverId() {
    final id = _driverId;
    if (_token == null || id == null) {
      throw const ApiException('Please log in before using this feature.');
    }
    return id;
  }

  /// Shared logic for login / register / google-login responses:
  /// they all return the same { token, driver_id, name, avatar_url, status } shape.
  Map<String, dynamic> _applyAuthResponse(
    Map<String, dynamic> response,
    String errorMessage,
  ) {
    final token = response['token']?.toString();
    // เปลี่ยนจาก _toInt เป็น _toString เพราะ driverId เป็น String
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
        response = await _client.delete(uri, headers: headers);
      default:
        throw ApiException('Unsupported request method: $method');
    }

    final decoded = _decodeResponse(response);

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

  // เปลี่ยนเป็น _toString ที่ convert ค่าเป็น String แทน int
  String? _toString(dynamic value) {
    if (value is String) return value;
    if (value is int) return value.toString();
    if (value is num) return value.toInt().toString();
    return null;
  }

  /// ดึง Alert ล่าสุดของ driver คนนี้ (ใช้เอา device_id ตอนเด้ง AlertScreen)
  Future<Map<String, dynamic>?> latestAlert() async {
    final response = await _request(
      'GET',
      'driver-latest-alert',
      query: {'driver_id': _requireDriverId()},  // ส่งเป็น String แล้ว
      requireAuth: false,
    );
    return _nullableDataMap(response);
  }
}