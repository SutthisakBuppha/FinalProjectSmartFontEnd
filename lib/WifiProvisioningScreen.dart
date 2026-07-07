import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'devices_screen.dart'; // เพิ่มเข้ามา เพื่อ navigate ไปหน้ารายการอุปกรณ์หลังเชื่อมต่อสำเร็จ

class WifiProvisioningScreen extends StatefulWidget {
  final String serialNumber; // รับมาจากหน้าลงทะเบียนก่อนหน้า
  const WifiProvisioningScreen({super.key, required this.serialNumber});

  @override
  State<WifiProvisioningScreen> createState() => _WifiProvisioningScreenState();
}

class _WifiProvisioningScreenState extends State<WifiProvisioningScreen> {
  BluetoothDevice? _targetDevice;
  bool _isScanning = false;
  bool _isConnected = false;
  String _statusMessage = "กำลังเตรียมพร้อม...";

  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // เก็บ subscription ไว้เพื่อ cancel ตอนออกจากหน้านี้ (ป้องกัน setState หลัง dispose)
  StreamSubscription<List<ScanResult>>? _scanResultsSub;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSub;
  Timer? _scanTimeoutTimer;

  // UUID ของ Service และ Characteristic ที่ฝั่ง Hardware (กล้อง) กำหนดไว้
  // (อันนี้ต้องตรงกับที่โปรแกรมเมอร์ฝั่ง Hardware เขียนไว้ในกล้อง)
  final String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

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
    setState(() {
      _isScanning = true;
      _statusMessage = "กำลังขอสิทธิ์ Bluetooth และ Location...";
    });

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    debugPrint("Permission statuses: $statuses");

    final allGranted = statuses.values.every((s) => s.isGranted);

    if (!mounted) return;

    if (!allGranted) {
      setState(() {
        _isScanning = false;
        _statusMessage = "กรุณาอนุญาตสิทธิ์ Bluetooth และ Location ในตั้งค่าเครื่อง แล้วลองใหม่";
      });
      return;
    }

    // เช็คว่า Bluetooth บนเครื่องเปิดอยู่ไหม
    _adapterStateSub = FlutterBluePlus.adapterState.listen((state) {
      debugPrint("Bluetooth adapter state: $state");
      if (!mounted) return;
      if (state != BluetoothAdapterState.on) {
        setState(() {
          _statusMessage = "กรุณาเปิด Bluetooth บนเครื่องก่อน";
        });
      }
    });

    _startScan();
  }

  // 1. ค้นหากล้องที่มี S/N ตรงกัน
  void _startScan() async {
    if (!mounted) return;
    setState(() {
      _isScanning = true;
      _statusMessage = "กำลังค้นหาบลูทูธของกล้องใกล้คุณ...";
    });

    debugPrint("กำลังค้นหา S/N: '${widget.serialNumber}'");

    // ยกเลิก subscription เก่าก่อน (กันสมัคร listener ซ้ำเวลากด "ลองค้นหาใหม่")
    await _scanResultsSub?.cancel();
    _scanTimeoutTimer?.cancel();

    // เริ่มสแกน BLE
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

    _scanResultsSub = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      debugPrint("จำนวนอุปกรณ์ที่เจอตอนนี้: ${results.length}");
      for (ScanResult r in results) {
        debugPrint("Found device: '${r.device.platformName}'");
        // แนะนำให้ฝั่ง Hardware ตั้งชื่อ Bluetooth ให้มี S/N อยู่ด้วย เช่น "DashCam_SN12345"
        if (r.device.platformName.contains(widget.serialNumber)) {
          FlutterBluePlus.stopScan();
          setState(() {
            _targetDevice = r.device;
            _isScanning = false;
          });
          _connectToDevice(); // เจอแล้วให้เชื่อมต่อทันที
          break;
        }
      }
    });

    // ถ้าสแกนครบเวลาแล้วยังไม่เจอ ให้แจ้ง user
    _scanTimeoutTimer = Timer(const Duration(seconds: 16), () {
      if (mounted && _targetDevice == null) {
        setState(() {
          _isScanning = false;
          _statusMessage = "ไม่พบกล้อง กรุณาตรวจสอบว่ากล้องเปิดอยู่และอยู่ใกล้เครื่อง แล้วลองใหม่";
        });
      }
    });
  }

  // 2. เชื่อมต่อ Bluetooth กับกล้อง
  void _connectToDevice() async {
    if (_targetDevice == null) return;
    try {
      await _targetDevice!.connect();
      if (!mounted) return;
      setState(() => _isConnected = true);
    } catch (e) {
      debugPrint("เชื่อมต่อล้มเหลว: $e");
      if (!mounted) return;
      setState(() {
        _statusMessage = "เชื่อมต่อกับกล้องล้มเหลว กรุณาลองใหม่";
      });
    }
  }

  // 3. ส่งข้อมูล Wi-Fi ไปยังกล้อง
  void _sendWifiCredentials() async {
    if (_targetDevice == null || !_isConnected) return;

    // ค้นหา Service และ Characteristic ของกล้อง
    List<BluetoothService> services = await _targetDevice!.discoverServices();
    BluetoothCharacteristic? targetCharacteristic;

    for (BluetoothService s in services) {
      if (s.uuid.toString() == SERVICE_UUID) {
        for (BluetoothCharacteristic c in s.characteristics) {
          if (c.uuid.toString() == CHARACTERISTIC_UUID) {
            targetCharacteristic = c;
            break;
          }
        }
      }
    }

    if (targetCharacteristic != null) {
      // จับข้อมูล Wi-Fi มัดรวมเป็น JSON String (ต้องตรงกับฝั่ง ESP32 ที่ parse ด้วย ArduinoJson)
      Map<String, String> wifiData = {
        "ssid": _ssidController.text,
        "pass": _passwordController.text,
      };
      String jsonString = jsonEncode(wifiData);

      // แปลงเป็น Bytes แล้วเขียน (Write) ลงตัวกล้องผ่าน BLE
      await targetCharacteristic.write(utf8.encode(jsonString));

      if (!mounted) return;
      // แสดง Alert บอกลูกค้าว่าส่งข้อมูลเรียบร้อย กำลังรอระบบกล้องต่อเน็ต
      _showSuccessDialog();
    } else {
      if (!mounted) return;
      setState(() {
        _statusMessage = "ไม่พบ Service/Characteristic ที่ถูกต้องบนกล้อง";
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("ส่งข้อมูลสำเร็จ"),
        content: const Text("กล้องกำลังทำการเชื่อมต่ออินเทอร์เน็ต กรุณารอประมาณ 1-2 นาที จากนั้นตรวจสอบสถานะที่หน้าหลัก"),
        actions: [
          TextButton(
            onPressed: () {
              // ปิด dialog ก่อนเสมอ
              Navigator.of(dialogContext).pop();

              // เด้งไปหน้ารายการอุปกรณ์ตรงๆ พร้อมเคลียร์ stack เก่าทิ้งทั้งหมด
              // (หน้าใหม่จะโหลดรายการอุปกรณ์ใหม่ทันทีใน initState -> เห็นอุปกรณ์ที่เพิ่งลงทะเบียนขึ้นมาเลย)
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const DeviceManagementScreen()),
                (route) => false,
              );
            },
            child: const Text("ตกลง"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("ตั้งค่าเครือข่ายกล้อง S/N: ${widget.serialNumber}")),
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
                    _isConnected ? "เชื่อมต่อกับกล้องสำเร็จแล้ว" : _statusMessage,
                    style: TextStyle(
                      color: _isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (!_isConnected)
                    TextButton.icon(
                      onPressed: _startScan,
                      icon: const Icon(Icons.refresh),
                      label: const Text("ลองค้นหาใหม่"),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ssidController,
                    decoration: const InputDecoration(labelText: "ชื่อ Wi-Fi (SSID)", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "รหัสผ่าน Wi-Fi", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isConnected ? _sendWifiCredentials : null,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2646)),
                      child: const Text("ส่งข้อมูลให้กล้องเชื่อมต่อเน็ต", style: TextStyle(color: Colors.white)),
                    ),
                  )
                ],
              ),
      ),
    );
  }
}