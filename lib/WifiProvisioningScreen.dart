import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';

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
  
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // UUID ของ Service และ Characteristic ที่ฝั่ง Hardware (กล้อง) กำหนดไว้
  // (อันนี้ต้องตรงกับที่โปรแกรมเมอร์ฝั่ง Hardware เขียนไว้ในกล้องนะครับ)
  final String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  // 1. ค้นหากล้องที่มี S/N ตรงกัน
  void _startScan() async {
    setState(() => _isScanning = true);
    
    // เริ่มสแกน BLE
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
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
  }

  // 2. เชื่อมต่อ Bluetooth กับกล้อง
  void _connectToDevice() async {
    if (_targetDevice == null) return;
    try {
      await _targetDevice!.connect();
      setState(() => _isConnected = true);
    } catch (e) {
      print("เชื่อมต่อล้มเหลว: $e");
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
      // จับข้อมูล Wi-Fi มัดรวมเป็น JSON String
      Map<String, String> wifiData = {
        "ssid": _ssidController.text,
        "pass": _passwordController.text,
      };
      String jsonString = jsonEncode(wifiData);

      // แปลงเป็น Bytes แล้วเขียน (Write) ลงตัวกล้องผ่าน BLE
      await targetCharacteristic.write(utf8.encode(jsonString));
      
      // แสดง Alert บอกลูกค้าว่าส่งข้อมูลเรียบร้อย กำลังรอระบบกล้องต่อเน็ต
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ส่งข้อมูลสำเร็จ"),
        content: const Text("กล้องกำลังทำการเชื่อมต่ออินเทอร์เน็ต กรุณารอประมาณ 1-2 นาที จากนั้นตรวจสอบสถานะที่หน้าหลัก"),
        actions: [
          TextButton(
            onPressed: () {
              // ปิดหน้าจอ และเด้งกลับไปหน้า รายการอุปกรณ์ (Devices Screen)
              Navigator.pop(context); // ปิด dialog
              Navigator.pop(context); // กลับหน้าหลัก
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
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("กำลังค้นหาบลูทูธของกล้องใกล้คุณ..."),
              ],
            ))
          : Column(
              children: [
                Text(
                  _isConnected ? "เชื่อมต่อกับกล้องสำเร็จแล้ว" : "ไม่พบกล้อง กรุณาขยับเข้าใกล้กล้อง", 
                  style: TextStyle(color: _isConnected ? Colors.green : Colors.red, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 24),
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