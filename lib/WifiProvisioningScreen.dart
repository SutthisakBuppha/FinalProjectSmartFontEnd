import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class WifiProvisioningScreen extends StatefulWidget {
  final String serialNumber; // รับมาจากหน้าลงทะเบียนก่อนหน้า
  const WifiProvisioningScreen({super.key, required this.serialNumber});

  @override
  State<WifiProvisioningScreen> createState() => _WifiProvisioningScreenState();
}

class _WifiProvisioningScreenState extends State<WifiProvisioningScreen> {
  BluetoothDevice? _targetDevice;
  bool _isScanning = false;
  bool _isStartingScan = false;
  bool _isConnected = false;
  bool _isSending = false;
  bool _permissionPermanentlyDenied = false;
  String _statusMessage = "กำลังเตรียมพร้อม...";

  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // เก็บ subscription ไว้เพื่อ cancel ตอนออกจากหน้านี้ (ป้องกัน setState หลัง dispose)
  StreamSubscription<List<ScanResult>>? _scanResultsSub;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSub;
  Timer? _scanTimeoutTimer;

  // UUID ของ Service และ Characteristic ที่ฝั่ง Hardware (กล้อง) กำหนดไว้
  // (อันนี้ต้องตรงกับที่โปรแกรมเมอร์ฝั่ง Hardware เขียนไว้ในกล้อง)
  static const String _serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String _characteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  @override
  void initState() {
    super.initState();
    _initBleAndScan();
  }

  @override
  void dispose() {
    // ยกเลิก stream ทั้งหมดเมื่อออกจากหน้านี้ กัน setState() ทำงานตอน widget ถูก dispose ไปแล้ว
    _scanResultsSub?.cancel();
    _adapterStateSub?.cancel();
    _scanTimeoutTimer?.cancel();
    FlutterBluePlus.stopScan();
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 0. ขอ permission ก่อน แล้วค่อยเริ่มสแกน (สำคัญมาก ถ้าข้ามขั้นนี้จะหาไม่เจอเลย)
  Future<void> _initBleAndScan() async {
    if (!mounted) return;

    // Browsers do not support permission_handler's bluetooth permissions.
    // Web Bluetooth must be started by a direct user gesture instead.
    if (kIsWeb) {
      setState(() {
        _isScanning = false;
        _statusMessage =
            'กด “ลองค้นหาใหม่” เพื่อให้ Chrome เปิดหน้าต่างค้นหาอุปกรณ์ Bluetooth';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _statusMessage = "กำลังขอสิทธิ์ Bluetooth และ Location...";
    });

    Map<Permission, PermissionStatus> statuses;
    try {
      statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _statusMessage = 'ขอสิทธิ์ Bluetooth ไม่สำเร็จ: $e';
      });
      return;
    }

    debugPrint("Permission statuses: $statuses");

    final bluetoothGranted =
        statuses[Permission.bluetoothScan]?.isGranted == true &&
        statuses[Permission.bluetoothConnect]?.isGranted == true;
    final permanentlyDenied = statuses.values.any(
      (status) => status.isPermanentlyDenied,
    );

    if (!mounted) return;

    if (!bluetoothGranted) {
      setState(() {
        _isScanning = false;
        _permissionPermanentlyDenied = permanentlyDenied;
        _statusMessage =
            "กรุณาอนุญาตสิทธิ์ Bluetooth ในตั้งค่าเครื่อง แล้วลองใหม่";
      });
      return;
    }

    // เช็คว่า Bluetooth บนเครื่องเปิดอยู่ไหม
    _adapterStateSub = FlutterBluePlus.adapterState.listen((state) {
      debugPrint("Bluetooth adapter state: $state");
      if (!mounted) return;
      if (state == BluetoothAdapterState.on) {
        if (_targetDevice == null && !_isScanning && !_isStartingScan) {
          _startScan();
        }
      } else {
        _scanTimeoutTimer?.cancel();
        FlutterBluePlus.stopScan();
        setState(() {
          _isScanning = false;
          _statusMessage = "กรุณาเปิด Bluetooth บนเครื่องก่อน";
        });
      }
    });

    final currentState = await FlutterBluePlus.adapterState.first;
    if (!mounted) return;
    if (currentState == BluetoothAdapterState.on) {
      await _startScan();
    } else {
      setState(() {
        _isScanning = false;
        _statusMessage = 'กรุณาเปิด Bluetooth บนเครื่องก่อน';
      });
    }
  }

  // 1. ค้นหากล้องที่มี S/N ตรงกัน
  String _normalizeBleIdentifier(String value) =>
      value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  Future<void> _startScan() async {
    if (!mounted || _isStartingScan || _isConnected) return;
    _isStartingScan = true;
    setState(() {
      _isScanning = true;
      _permissionPermanentlyDenied = false;
      _targetDevice = null;
      _statusMessage = "กำลังค้นหาบลูทูธของกล้องใกล้คุณ...";
    });

    debugPrint("กำลังค้นหา S/N: '${widget.serialNumber}'");

    // ยกเลิก subscription เก่าก่อน (กันสมัคร listener ซ้ำเวลากด "ลองค้นหาใหม่")
    await _scanResultsSub?.cancel();
    _scanTimeoutTimer?.cancel();
    await FlutterBluePlus.stopScan();

    // สมัคร listener ก่อนเริ่ม scan เพื่อไม่ให้พลาด advertisement ช่วงแรก
    _scanResultsSub = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      debugPrint("จำนวนอุปกรณ์ที่เจอตอนนี้: ${results.length}");
      final expectedSerial = _normalizeBleIdentifier(widget.serialNumber);
      final expectedSuffix = expectedSerial.length > 6
          ? expectedSerial.substring(expectedSerial.length - 6)
          : expectedSerial;
      final serviceCandidates = <ScanResult>[];
      ScanResult? matchedByName;

      for (final r in results) {
        final platformName = r.device.platformName;
        final advertisedName = r.advertisementData.advName;
        final hasProvisioningService = r.advertisementData.serviceUuids.any(
          (uuid) => uuid.toString().toLowerCase() == _serviceUuid,
        );
        debugPrint(
          "Found BLE: platform='$platformName', advertised='$advertisedName', provisioning=$hasProvisioningService",
        );
        final normalizedNames = _normalizeBleIdentifier(
          '$platformName$advertisedName',
        );
        if (expectedSerial.isNotEmpty &&
            (normalizedNames.contains(expectedSerial) ||
                normalizedNames.contains(expectedSuffix))) {
          matchedByName = r;
          break;
        }
        if (hasProvisioningService) serviceCandidates.add(r);
      }

      // UUID fallback supports older firmware whose long BLE name may be
      // omitted by Android. Only auto-select when exactly one board is found.
      final match =
          matchedByName ??
          (serviceCandidates.length == 1 ? serviceCandidates.first : null);
      if (match != null) {
        FlutterBluePlus.stopScan();
        _scanTimeoutTimer?.cancel();
        setState(() {
          _targetDevice = match.device;
          _isScanning = false;
        });
        _connectToDevice();
      }
    });

    // Always stop the loading state, even when the native scan callback stalls.
    _scanTimeoutTimer = Timer(const Duration(seconds: 16), () {
      if (mounted && _targetDevice == null) {
        FlutterBluePlus.stopScan();
        setState(() {
          _isScanning = false;
          _statusMessage =
              "ไม่พบอุปกรณ์ S/N ${widget.serialNumber}\nกรุณาตรวจว่าบอร์ดแสดง 'BLE Active' ใน Serial Monitor แล้วลองใหม่";
        });
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _statusMessage =
            'เริ่มค้นหา Bluetooth ไม่สำเร็จ กรุณาเปิด Bluetooth และ Location แล้วลองใหม่\n$e';
      });
      return;
    } finally {
      _isStartingScan = false;
    }
  }

  // 2. เชื่อมต่อ Bluetooth กับกล้อง
  void _connectToDevice() async {
    if (_targetDevice == null) return;
    try {
      await _targetDevice!
          .connect(timeout: const Duration(seconds: 12))
          .timeout(const Duration(seconds: 15));
      // Wi-Fi JSON is normally longer than the default BLE payload (20 bytes).
      // Android needs a larger MTU before writing the credentials in one piece.
      if (!kIsWeb) {
        try {
          await _targetDevice!.requestMtu(247);
        } catch (e) {
          debugPrint("BLE MTU request was not accepted: $e");
        }
      }
      if (!mounted) return;
      setState(() {
        _isConnected = true;
        _statusMessage = "เชื่อมต่อกับกล้องแล้ว กรุณากรอกข้อมูล Wi-Fi";
      });
    } catch (e) {
      debugPrint("เชื่อมต่อล้มเหลว: $e");
      if (!mounted) return;
      setState(() {
        _statusMessage = "เชื่อมต่อกับกล้องล้มเหลว กรุณาลองใหม่";
      });
    }
  }

  // 3. ส่งข้อมูล Wi-Fi ไปยังกล้อง
  Future<void> _sendWifiCredentials() async {
    if (_targetDevice == null || !_isConnected || _isSending) return;

    final ssid = _ssidController.text.trim();
    final password = _passwordController.text;
    if (ssid.isEmpty) {
      setState(() => _statusMessage = "กรุณากรอกชื่อ Wi-Fi (SSID)");
      return;
    }

    setState(() {
      _isSending = true;
      _statusMessage = "กำลังส่งข้อมูล Wi-Fi ไปยังกล้อง...";
    });

    StreamSubscription<List<int>>? statusSubscription;
    try {
      // ค้นหา Service และ Characteristic ของกล้อง
      final services = await _targetDevice!
          .discoverServices()
          .timeout(const Duration(seconds: 12));
      BluetoothCharacteristic? targetCharacteristic;

      for (final service in services) {
        if (service.uuid.toString().toLowerCase() == _serviceUuid) {
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() ==
                _characteristicUuid) {
              targetCharacteristic = characteristic;
              break;
            }
          }
        }
      }

      if (targetCharacteristic == null) {
        throw Exception("ไม่พบช่องทางส่งข้อมูล Wi-Fi บนกล้อง");
      }

      final connectionResult = Completer<String>();
      statusSubscription = targetCharacteristic.onValueReceived.listen((value) {
        final status = utf8.decode(value).trim().toLowerCase();
        debugPrint("สถานะ Wi-Fi จากกล้อง: $status");
        if ((status == 'connected' || status == 'failed' || status == 'invalid') &&
            !connectionResult.isCompleted) {
          connectionResult.complete(status);
        }
      });
      await targetCharacteristic.setNotifyValue(true);

      // จับข้อมูล Wi-Fi มัดรวมเป็น JSON String (ต้องตรงกับฝั่ง ESP32 ที่ parse ด้วย ArduinoJson)
      Map<String, String> wifiData = {
        "ssid": ssid,
        "pass": password,
        // Production API host sent to ESP32 via BLE.
        "server_ip": "smartdriver.lnw.mn",

        // Local fallback for a real phone/ESP32 on the same Wi-Fi as the PC.
        // Replace the production entry above with this entry and change the IP:
        // "server_ip": "192.168.1.100",
      };
      String jsonString = jsonEncode(wifiData);

      // แปลงเป็น Bytes แล้วเขียน (Write) ลงตัวกล้องผ่าน BLE
      await targetCharacteristic
          .write(utf8.encode(jsonString), withoutResponse: false)
          .timeout(const Duration(seconds: 12));

      if (mounted) {
        setState(() {
          _statusMessage =
              "ส่งข้อมูลแล้ว กำลังรอกล้องทดสอบการเชื่อมต่อ Wi-Fi...";
        });
      }

      final connectionStatus = await connectionResult.future.timeout(
        const Duration(seconds: 25),
      );
      if (connectionStatus != 'connected') {
        throw Exception(
          connectionStatus == 'failed'
              ? "กล้องเชื่อมต่อ Wi-Fi ไม่สำเร็จ กรุณาตรวจสอบ SSID และรหัสผ่าน"
              : "ข้อมูล Wi-Fi ไม่ถูกต้อง",
        );
      }

      if (!mounted) return;
      setState(() => _statusMessage = "กล้องเชื่อมต่อ Wi-Fi สำเร็จแล้ว");
      await _showSuccessDialog();
    } catch (e) {
      debugPrint("ส่งข้อมูล Wi-Fi ผ่าน BLE ไม่สำเร็จ: $e");
      if (!mounted) return;
      setState(() {
        _statusMessage =
            "ส่งข้อมูล Wi-Fi ไม่สำเร็จ\nกรุณาอยู่ใกล้กล้องแล้วลองใหม่: $e";
      });
    } finally {
      await statusSubscription?.cancel();
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("เชื่อมต่อสำเร็จ"),
        content: const Text(
          "กล้องเชื่อมต่อ Wi-Fi สำเร็จแล้ว เมื่อกดตกลงระบบจะบันทึกอุปกรณ์ลงฐานข้อมูลให้อัตโนมัติ",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text("ตกลง"),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("ตั้งค่าเครือข่ายกล้อง S/N: ${widget.serialNumber}"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _isScanning
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_statusMessage, textAlign: TextAlign.center),
                  ],
                ),
              )
            : Column(
                children: [
                  Text(
                    _isConnected
                        ? "เชื่อมต่อกับกล้องสำเร็จแล้ว"
                        : _statusMessage,
                    style: TextStyle(
                      color: _isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (!_isConnected)
                    Column(
                      children: [
                        TextButton.icon(
                          onPressed: _isScanning ? null : _startScan,
                          icon: const Icon(Icons.refresh),
                          label: const Text("ลองค้นหาใหม่"),
                        ),
                        if (_permissionPermanentlyDenied)
                          TextButton.icon(
                            onPressed: openAppSettings,
                            icon: const Icon(Icons.settings),
                            label: const Text('เปิดการตั้งค่าแอป'),
                          ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ssidController,
                    decoration: const InputDecoration(
                      labelText: "ชื่อ Wi-Fi (SSID)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "รหัสผ่าน Wi-Fi",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed:
                          _isConnected && !_isSending
                              ? _sendWifiCredentials
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cFF0F2647,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "ส่งข้อมูลให้กล้องเชื่อมต่อเน็ต",
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
