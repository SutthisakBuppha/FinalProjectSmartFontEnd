import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ตัวควบคุมขนาดตัวอักษรของทั้งแอป (Global Text Scale)
/// เมื่อค่านี้เปลี่ยน ทุกหน้าที่อยู่ใต้ MaterialApp จะปรับขนาดตัวอักษรตามทันที
class TextScaleController extends ChangeNotifier {
  TextScaleController._();
  static final TextScaleController instance = TextScaleController._();

  static const _prefsKey = 'app_text_scale_factor';
  static const double defaultScale = 1.0;

  double _scaleFactor = defaultScale;
  double get scaleFactor => _scaleFactor;

  /// ตัวเลือกขนาดตัวอักษรที่ให้ผู้ใช้เลือก (label -> scale factor)
  static const Map<String, double> presets = {
    'เล็ก': 0.85,
    'ปกติ': 1.0,
    'ใหญ่': 1.15,
    'ใหญ่มาก': 1.3,
  };

  /// เรียกครั้งเดียวตอนแอปเริ่มทำงาน เพื่อโหลดค่าที่เคยบันทึกไว้
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _scaleFactor = prefs.getDouble(_prefsKey) ?? defaultScale;
    notifyListeners();
  }

  /// บันทึกขนาดใหม่และแจ้งทุกหน้าจอให้ปรับตัวอักษรทันที
  Future<void> setScale(double value) async {
    _scaleFactor = value.clamp(0.7, 1.6);
    notifyListeners(); // ปรับ UI ทั้งแอปทันที ไม่ต้องรอ await เสร็จ

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKey, _scaleFactor);
  }
}