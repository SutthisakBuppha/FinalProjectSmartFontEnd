import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls the language shown throughout the application.
///
/// Thai remains the canonical language used by the current API and database.
/// Only the presentation layer is translated, so changing language never
/// changes alert types, trip records, or values sent back to the server.
class LanguageController extends ChangeNotifier {
  LanguageController._();

  static final LanguageController instance = LanguageController._();

  static const _prefsKey = 'app_language_code';
  static const supportedLocales = <Locale>[Locale('th'), Locale('en')];

  String _languageCode = 'th';

  String get languageCode => _languageCode;
  Locale get locale => Locale(_languageCode);
  bool get isEnglish => _languageCode == 'en';

  int displayYear(int gregorianYear) =>
      isEnglish ? gregorianYear : gregorianYear + 543;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_prefsKey);
    if (savedCode == 'th' || savedCode == 'en') {
      _languageCode = savedCode!;
    }
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    if (languageCode != 'th' && languageCode != 'en') return;
    if (_languageCode == languageCode) return;

    _languageCode = languageCode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, languageCode);
  }

  String translate(String source) {
    if (source.isEmpty) return source;

    if (!isEnglish) {
      return _thaiByEnglish[source] ?? source;
    }

    final exact = _englishByThai[source];
    if (exact != null) return exact;

    // Interpolated strings arrive here after their values have been inserted.
    // Replacing known phrases and units also translates those dynamic labels.
    var result = source;
    for (final entry in _englishReplacementEntries) {
      if (result.contains(entry.key)) {
        result = result.replaceAll(entry.key, entry.value);
      }
    }
    return result;
  }

  static final List<MapEntry<String, String>> _englishReplacementEntries =
      _englishByThai.entries.toList()
        ..sort((a, b) => b.key.length.compareTo(a.key.length));

  static const Map<String, String> _thaiByEnglish = {
    'Home': 'หน้าหลัก',
    'History': 'ประวัติ',
    'Notification': 'แจ้งเตือน',
    'Device': 'อุปกรณ์',
    'Report': 'รายงาน',
    'Profile': 'โปรไฟล์',
    'Login': 'เข้าสู่ระบบ',
    'Sign up': 'สมัครสมาชิก',
    'Start Date – End Date': 'วันที่เริ่มต้น – วันที่สิ้นสุด',
    'No Username': 'ไม่มีชื่อผู้ใช้',
  };

  static const Map<String, String> _englishByThai = {
    // Common actions and navigation.
    'หน้าหลัก': 'Home',
    'ประวัติ': 'History',
    'ประวัติการขับขี่': 'Driving History',
    'ประวัติการเดินทางล่าสุด': 'Recent Trips',
    'ประวัติการแจ้งเตือน': 'Notification History',
    'แจ้งเตือน': 'Notifications',
    'อุปกรณ์': 'Devices',
    'รายงาน': 'Report',
    'โปรไฟล์': 'Profile',
    'ตั้งค่าอุปกรณ์': 'Device Settings',
    'การตั้งค่าอุปกรณ์': 'Device Settings',
    'แก้ไขโปรไฟล์': 'Edit Profile',
    'เข้าสู่ระบบ': 'Log In',
    'เข้าสู่ระบบใหม่': 'Log In Again',
    'สมัครสมาชิก': 'Sign Up',
    'ลงทะเบียน': 'Register',
    'ลงทะเบียนอุปกรณ์': 'Register Device',
    'ออกจากระบบ': 'Log Out',
    'ยกเลิก': 'Cancel',
    'ตกลง': 'OK',
    'ลบ': 'Delete',
    'เปิด': 'Enable',
    'ปิด': 'Disable',
    'ลองใหม่': 'Retry',
    'ลองใหม่อีกครั้ง': 'Try Again',
    'ลองอีกครั้ง': 'Try Again',
    'ลองค้นหาใหม่': 'Search Again',
    'หยุด': 'Stop',
    'กำหนดเอง': 'Custom',
    'ทั้งหมด': 'All',
    'วันนี้': 'Today',
    'ใช้ตัวกรอง': 'Apply Filter',
    'ใช้วันที่นี้': 'Use This Date',
    'กำหนดวันที่': 'Select Dates',
    'เลือกวันที่อ้างอิง': 'Select Reference Date',
    'รีเฟรชข้อมูล': 'Refresh Data',
    'กำลังโหลด...': 'Loading...',
    'กำลังเตรียมพร้อม...': 'Getting Ready...',
    'กำลังตรวจสอบ': 'Checking',
    'กำลังเปิด...': 'Enabling...',
    'กำลังอัปโหลด...': 'Uploading...',

    // Profile and display preferences.
    'การตั้งค่าการแสดงผล': 'Display Settings',
    'เลือกขนาดตัวอักษรที่อ่านสบายตา': 'Choose a comfortable text size',
    'ขนาดตัวอักษร': 'Text Size',
    'ภาษา': 'Language',
    'เลือกภาษาที่ใช้ในแอป': 'Choose the app language',
    'ไทย': 'ไทย',
    'อังกฤษ': 'English',
    'เล็ก': 'Small',
    'ปกติ': 'Normal',
    'ใหญ่': 'Large',
    'ใหญ่มาก': 'Extra Large',
    'ตัวอย่างข้อความในแอป': 'Example text in the app',
    'แตะเพื่อเปลี่ยนรูปโปรไฟล์': 'Tap to change profile picture',
    'เลือกรูปจากคลังภาพ': 'Choose from gallery',
    'ถ่ายรูปใหม่': 'Take a new photo',
    'ชื่อ-นามสกุลคนขับ': 'Driver Name',
    'บันทึกข้อมูลส่วนตัว': 'Save Personal Information',
    'อัปเดตข้อมูลสำเร็จเรียบร้อย': 'Information updated successfully',
    'ยืนยันการออกจากระบบ': 'Confirm Log Out',
    'คุณต้องการออกจากระบบใช่หรือไม่?': 'Are you sure you want to log out?',
    'ไม่ระบุชื่อ': 'Name not provided',
    'ไม่มีชื่อผู้ใช้': 'No username',
    'ระยะทางรวม': 'Total Distance',
    'เวลาขับขี่': 'Driving Time',

    // Authentication.
    'ยินดีต้อนรับ!': 'Welcome!',
    'ยินดีต้อนรับกลับ': 'Welcome Back',
    'ยินดีต้อนรับกลับมา': 'Welcome Back',
    'กรุณากรอกข้อมูลเพื่อเข้าสู่ระบบ': 'Enter your information to log in',
    'ชื่อผู้ใช้ (Username)': 'Username',
    'รหัสผ่าน': 'Password',
    'ยืนยันรหัสผ่าน': 'Confirm Password',
    'อีเมล': 'Email',
    'ลืมรหัสผ่าน?': 'Forgot Password?',
    'ยังไม่มีบัญชี?': "Don't have an account?",
    'มีบัญชีอยู่แล้วใช่ไหม?': 'Already have an account?',
    'หรือเข้าสู่ระบบด้วย': 'Or log in with',
    'หรือสมัครด้วยอีเมล': 'Or sign up with email',
    'สมัครสมาชิกด้วย Google': 'Sign up with Google',
    'ลงทะเบียนเพื่อเริ่มติดตามการขับขี่ของคุณ':
        'Register to start tracking your driving',
    'อย่างน้อย 8 ตัวอักษร': 'At least 8 characters',
    'ชื่อผู้ใช้ต้องไม่มีช่องว่าง': 'Username must not contain spaces',
    'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร':
        'Password must contain at least 8 characters',
    'รหัสผ่านยืนยันไม่ตรงกัน': 'Passwords do not match',
    'รหัสผ่านและยืนยันรหัสผ่านไม่ตรงกัน': 'Passwords do not match',
    'กรุณากรอกข้อมูลให้ครบทุกช่อง': 'Please complete every field',
    'กรุณากรอกชื่อผู้ใช้และรหัสผ่าน': 'Please enter your username and password',
    'กรุณากรอกอีเมล': 'Please enter your email',
    'ไม่ต้องกังวล! กรุณากรอกอีเมลที่เชื่อมโยงกับบัญชีของคุณ เราจะส่งรหัสยืนยัน 6 หลักไปที่อีเมลของคุณเพื่อตั้งรหัสผ่านใหม่':
        "Don't worry. Enter the email linked to your account and we will send a 6-digit verification code.",
    'เกิดข้อผิดพลาดในการเชื่อมต่อ': 'Connection error',
    'เกิดข้อผิดพลาดในการเชื่อมต่อเครือข่าย': 'Network connection error',
    'เกิดข้อผิดพลาดในการดึงข้อมูล': 'Failed to load data',
    'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง':
        'Something went wrong. Please try again.',
    'เข้าสู่ระบบไม่สำเร็จ กรุณาลองใหม่': 'Login failed. Please try again.',
    'เข้าสู่ระบบด้วย Google ไม่สำเร็จ กรุณาลองใหม่':
        'Google login failed. Please try again.',
    'เข้าสู่ระบบด้วย Google ไม่สำเร็จ': 'Google login failed',
    'สมัครสมาชิกด้วย Google ไม่สำเร็จ กรุณาลองใหม่':
        'Google sign-up failed. Please try again.',
    'เซสชันหมดอายุ กรุณาล็อกอินใหม่อีกครั้ง':
        'Your session has expired. Please log in again.',
    'ไม่พบข้อมูลการเข้าสู่ระบบ กรุณาล็อกอินใหม่อีกครั้ง':
        'Login information was not found. Please log in again.',
    'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาตรวจสอบอินเทอร์เน็ต':
        'Unable to reach the server. Check your internet connection.',
    'ไม่สามารถเชื่อมต่อระบบได้ กรุณาลองใหม่อีกครั้ง':
        'Unable to connect. Please try again.',
    'เซิร์ฟเวอร์ตอบกลับช้าเกินไป กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่':
        'The server took too long to respond. Check your connection and retry.',
    'เซิร์ฟเวอร์ตอบกลับผิดรูปแบบ': 'The server returned an invalid response',
    'เซิร์ฟเวอร์ส่งข้อมูล JSON ที่ไม่สมบูรณ์':
        'The server returned incomplete JSON data',

    // Password reset.
    'ส่งลิงก์รีเซ็ตรหัสผ่าน': 'Send Password Reset Link',
    'ส่งรหัสยืนยันรีเซ็ตรหัสผ่าน': 'Send Reset Verification Code',
    'กรอกรหัสยืนยัน': 'Enter Verification Code',
    'รหัสยืนยัน (OTP)': 'Verification Code (OTP)',
    'รหัสผ่านใหม่': 'New Password',
    'ยืนยันรหัสผ่านใหม่': 'Confirm New Password',
    'ยืนยันรหัสและตั้งรหัสผ่านใหม่': 'Verify Code and Set New Password',
    'ยืนยันตั้งรหัสผ่านใหม่': 'Confirm New Password',
    'ส่งรหัสยืนยันสำเร็จ!': 'Verification code sent!',
    'กรอกรหัสยืนยัน 6 หลักที่ส่งไปยัง':
        'Enter the 6-digit verification code sent to',
    'พร้อมตั้งรหัสผ่านใหม่': 'and set a new password',
    'กรุณาตรวจสอบอีเมลของคุณ\nเพื่อนำรหัส OTP มากรอกตั้งรหัสผ่านใหม่':
        'Check your email for the OTP code to set a new password.',
    'เปลี่ยนรหัสผ่านสำเร็จ กรุณาเข้าสู่ระบบใหม่':
        'Password changed successfully. Please log in again.',

    // Trips and history.
    'การเดินทางปัจจุบัน': 'Current Trip',
    'เริ่มทริป': 'Start Trip',
    'จบทริป': 'End Trip',
    'กำลังเริ่มทริป...': 'Starting Trip...',
    'เริ่มบันทึกทริปไม่สำเร็จ': 'Failed to start trip recording',
    'กำลังจบทริป...': 'Ending Trip...',
    'ยืนยันจบทริป': 'Confirm End Trip',
    'เดินทางต่อ': 'Continue Trip',
    'จบเส้นทางไปจุดพัก': 'End Route to Rest Stop',
    'ระบบจะหยุดบันทึกตำแหน่งและสรุประยะทางของทริปนี้ลงใน History':
        'The system will stop tracking and save this trip to History.',
    'กรุณาเริ่มทริปหลักก่อนนำทางไปจุดพักรถ':
        'Start the main trip before navigating to a rest stop.',
    'กรุณาจบเส้นทางไปจุดพักในหน้าแผนที่ก่อนจบทริปหลัก':
        'End the rest-stop route on the map before ending the main trip.',
    'ไม่พบประวัติการเดินทางของท่าน': 'No trip history found',
    'ไม่มีข้อมูลเส้นทางการเดินทางเก็บไว้': 'No route data was saved',
    'ภาพรวมเส้นทาง': 'Route Overview',
    'จุดหมายหลัก': 'Main Destination',
    'จุดหมาย': 'Destination',
    'จุดพัก/ปั๊ม': 'Rest Stop / Gas Station',
    'จุดพักรถ': 'Rest Stop',
    'สถานที่ใกล้เคียง': 'Nearby Places',
    'ปั๊มน้ำมันหรือจุดพักรถใกล้ฉัน': 'Gas Stations or Rest Stops Near Me',
    'นำทาง': 'Navigate',
    'เปิด Google Maps': 'Open Google Maps',
    'กำลังค้นหาตำแหน่งของคุณ...': 'Finding your location...',
    'กำลังค้นหาจุดพักรถ...': 'Finding rest stops...',
    'กำลังบันทึกเส้นทางไปยัง': 'Recording route to',
    'กำลังคำนวณระยะทางจากตำแหน่ง GPS':
        'Calculating distance from your GPS location',
    'ไม่พบปั๊มน้ำมันหรือจุดพักรถในระยะ':
        'No gas stations or rest stops found within',
    'ในระยะ': 'Within',
    'กรุณาเปิดสัญญาณ GPS ของเครื่องก่อนใช้งานแผนที่':
        'Enable GPS before using the map.',
    'สิทธิ์เข้าถึงตำแหน่งถูกปิดถาวร กรุณาไปเปิดในตั้งค่าแอปด้วยตนเอง':
        'Location permission is permanently denied. Enable it in app settings.',
    'แอปต้องการสิทธิ์เข้าถึงตำแหน่งเพื่อค้นหาจุดพักรถที่ใกล้ที่สุด':
        'Location access is needed to find the nearest rest stop.',
    'ไม่สามารถเปิด Google Maps ได้': 'Unable to open Google Maps',
    'เปิด Google Maps ไม่สำเร็จ': 'Failed to open Google Maps',
    'เปิดการตั้งค่าแอป': 'Open App Settings',
    'เส้นทางไปจุดพัก': 'Route to Rest Stop',
    'การเดินทางหลัก': 'Main Trip',
    'ทริป': 'Trip',
    'มุ่งสู่': 'To',
    'พิกัด': 'Coordinates',

    // Alerts and reports.
    'แจ้งเตือนทั้งหมด': 'Total Alerts',
    'รายละเอียดการแจ้งเตือน': 'Notification Details',
    'รายละเอียดความเสี่ยง': 'Risk Details',
    'เหตุการณ์ความเสี่ยง': 'Risk Events',
    'เหตุการณ์ความเสี่ยงรวม': 'Total Risk Events',
    'เหตุการณ์เสี่ยง': 'Risk Events',
    'เหตุการณ์': 'events',
    'ระดับ': 'Level',
    'แนวโน้มความเสี่ยง': 'Risk Trend',
    'กราฟสถิติและรายละเอียดความเสี่ยงจากการขับขี่':
        'Driving risk charts and details',
    'ตรวจสอบระดับความเสี่ยงย้อนหลังและเหตุการณ์ที่เกิดขึ้นในวันนี้':
        "Review today's risk level and events",
    'ข้อมูลตามตัวกรอง': 'Filtered data',
    'แกน X: ช่วงวันที่เกิดเหตุการณ์  •  แกน Y: จำนวนการแจ้งเตือน (ครั้ง)':
        'X-axis: event date range  •  Y-axis: alert count',
    'ไม่สามารถโหลดข้อมูลความเสี่ยงได้': 'Unable to load risk data',
    'ยอดเยี่ยม! ไม่พบความเสี่ยงในช่วงเวลานี้':
        'Excellent! No risks were detected during this period.',
    'ไม่พบเหตุการณ์ความเสี่ยงในการเดินทางนี้ 🎉':
        'No risk events were detected on this trip 🎉',
    'ความเสี่ยงสูง': 'High Risk',
    'ความเสี่ยงสูงสุด': 'Highest Risk',
    'ปานกลาง': 'Medium',
    'ปลอดภัย': 'Safe',
    'ผู้ขับขี่ปลอดภัย': 'Driver Safe',
    'พบพฤติกรรมที่อาจทำให้เกิดความไม่ปลอดภัย':
        'Potentially unsafe behavior detected',
    'ตรวจพบพฤติกรรมเสี่ยงขณะขับขี่': 'Risky driving behavior detected',
    'ระบบแจ้งเตือนความปลอดภัยกำลังทำงาน\nโปรดหาที่จอดพักที่ปลอดภัยทันที':
        'The safety alert is active. Find a safe place to stop immediately.',
    'แจ้งเตือนความเสี่ยงขณะขับขี่': 'Driving Risk Alert',
    'แจ้งเตือนเมื่อพบพฤติกรรมเสี่ยงครบตามเงื่อนไข':
        'Alerts when risky behavior reaches the configured threshold',
    'ง่วงนอน': 'Drowsiness',
    'ตรวจพบความง่วงนอน': 'Drowsiness Detected',
    'ตรวจพบความง่วงนอนหลับใน!': 'Drowsiness Detected!',
    'ระยะเวลาการหลับตาเกินกำหนดความปลอดภัย':
        'Eyes were closed longer than the safe limit',
    'หลับตานาน': 'Prolonged Eye Closure',
    'เหม่อลอย': 'Inattention',
    'ไม่กระพริบตาเป็นเวลานาน': 'Inattention',
    'ตรวจพบอาการเหม่อลอย': 'Inattention Detected',
    'ไม่มองถนน': 'Eyes Off Road',
    'ไม่มองทาง': 'Eyes Off Road',
    'เสียสมาธิ': 'Distraction',
    'เสียสมาธิ / ไม่มองทาง': 'Distraction / Eyes Off Road',
    'หันหน้าออกจากกล้องนาน': 'Face Turned Away',
    'ใบหน้าหรือสายตาหันเหออกจากทิศทางขับขี่เป็นเวลานาน':
        'The driver looked away from the road for too long',
    'สายตาของผู้ขับขี่ไม่ได้จับจ้องที่พื้นผิวถนน':
        "The driver's eyes were not focused on the road",
    'ใช้โทรศัพท์': 'Phone Use',
    'ใช้โทรศัพท์ขณะขับขี่': 'Phone Use While Driving',
    'ตรวจพบผู้ขับขี่ยกโทรศัพท์ขึ้นมาใช้ในสายตากล้อง':
        'The driver was detected using a phone',
    'ขับรถเร็ว': 'Speeding',
    'เบรกกะทันหัน': 'Harsh Braking',
    'หาว': 'Yawning',
    'สัญญาณอาการล้า (หาว)': 'Fatigue Sign (Yawning)',
    'ผู้ขับขี่มีการอ้าปากหาว สัญญาณเริ่มต้นความง่วงนอน':
        'Yawning detected, an early sign of drowsiness',
    'ยังไม่มีการแจ้งเตือน': 'No notifications yet',

    // Date filters and time.
    'วันที่อ้างอิง': 'Reference Date',
    'เลือกช่วงวันที่เดินทาง': 'Select Trip Date Range',
    'เลือกช่วงวันที่วิเคราะห์ความเสี่ยง': 'Select Risk Analysis Date Range',
    'รายสัปดาห์': 'Week',
    'สัปดาห์': 'Week',
    'รายเดือน': 'Month',
    'เดือน': 'Month',
    'รายปี': 'Year',
    'ปี': 'Year',
    'เวลา': 'Time',
    'ระยะเวลา': 'Duration',
    'ระยะทาง': 'Distance',
    'ความเร็ว': 'Speed',
    'ครั้ง': 'times',
    'นาที': 'min',
    'ชั่วโมง': 'hours',
    'ชม.': 'hr',
    'วิ': 'sec',
    'กม.': 'km',
    'กม./ชม.': 'km/h',
    'ม.': 'm',
    'ล่าสุด': 'Latest',
    'จันทร์': 'Monday',
    'อังคาร': 'Tuesday',
    'พุธ': 'Wednesday',
    'พฤหัสบดี': 'Thursday',
    'ศุกร์': 'Friday',
    'เสาร์': 'Saturday',
    'อาทิตย์': 'Sunday',
    'จ.': 'Mon',
    'อ.': 'Tue',
    'พ.': 'Wed',
    'พฤ.': 'Thu',
    'ศ.': 'Fri',
    'ส.': 'Sat',
    'อา.': 'Sun',
    'ม.ค.': 'Jan',
    'ก.พ.': 'Feb',
    'มี.ค.': 'Mar',
    'เม.ย.': 'Apr',
    'พ.ค.': 'May',
    'มิ.ย.': 'Jun',
    'ก.ค.': 'Jul',
    'ส.ค.': 'Aug',
    'ก.ย.': 'Sep',
    'ต.ค.': 'Oct',
    'พ.ย.': 'Nov',
    'ธ.ค.': 'Dec',

    // Rest mode.
    'โหมดพักรถ': 'Rest Mode',
    'เปิดโหมดพักรถ': 'Enable Rest Mode',
    'กำลังอยู่ในโหมดพักรถ': 'Rest Mode Active',
    'สถานะโหมดพักรถ': 'Rest Mode Status',
    'กำหนดเหตุผลและเวลา': 'Set Reason and Duration',
    'เลือกเหตุผลที่พักรถ': 'Select a reason for resting',
    'เหตุผลที่พักรถ': 'Rest Reason',
    'เหตุผลอื่น': 'Other Reason',
    'จอดพักผ่อน': 'Taking a Break',
    'นอนพักในรถ': 'Sleeping in the Car',
    'จอดรถชั่วคราว': 'Temporary Stop',
    'หยิบของหรือทำธุระ': 'Running an Errand',
    'กำหนดเวลา 1–480 นาที (สูงสุด 8 ชั่วโมง)':
        'Set 1–480 minutes (maximum 8 hours)',
    'ระบบจะไม่แจ้งเตือนตามเวลาที่เลือก':
        'Alerts will be paused for the selected duration',
    'AI จะหยุดสั่ง Buzzer และไม่บันทึกเหตุการณ์ใหม่จนกว่าโหมดพักจะสิ้นสุด':
        'AI, the buzzer, and event recording will pause until rest mode ends.',
    'จอดพัก/นอน/หยิบของ? กดเปิดเพื่อไม่ให้ระบบรบกวน':
        "Stopping, sleeping, or running an errand? Enable rest mode to pause alerts.",
    'ระงับการแจ้งเตือนชั่วคราว': 'Alerts temporarily paused',
    'เปิดโหมดพักรถแล้ว': 'Rest mode enabled for',
    'เปิดโหมดพักรถไม่สำเร็จ': 'Failed to enable rest mode',
    'เปิดหน้าพักรถไม่สำเร็จ กรุณาลองใหม่':
        'Unable to open rest mode. Please try again.',
    'คุณถึงจุดพักรถแล้วหรือยัง?': 'Have you reached the rest stop?',
    'ไม่ได้เปิดโหมดพักรถอยู่': 'Rest mode is not active',
    'ยกเลิกโหมดพักรถแล้ว กลับมาแจ้งเตือนตามปกติ':
        'Rest mode ended. Alerts are active again.',
    'ยกเลิกโหมดพักรถไม่สำเร็จ': 'Failed to end rest mode',
    'หมดเวลาพักรถแล้ว': 'Rest Time Ended',
    'โหมดพักรถใกล้สิ้นสุด': 'Rest Mode Ending Soon',
    'แจ้งเตือนก่อนระบบกลับมาตรวจจับพฤติกรรม':
        'Notifies you before driving detection resumes',
    'แจ้งสถานะการเปิดและปิดโหมดพักรถ': 'Rest mode start and end notifications',
    'ถึงเวลากลับมาเดินทางต่อ กดปุ่มด้านล่างเพื่อปิดเสียงปลุก':
        'Time to continue your trip. Tap below to stop the alarm.',
    'ถึงเวลาตื่นและเตรียมพร้อมเดินทาง ระบบกลับมาตรวจจับตามปกติแล้ว':
        'Time to wake up. Driving detection is active again.',
    'ปิดเสียงปลุก': 'Stop Alarm',
    'ระบบจะกลับมาตรวจจับพฤติกรรมและแจ้งเตือนอีกครั้งใน 1 นาที':
        'Detection and alerts will resume in 1 minute.',

    // Devices, connection, and audio.
    'รายการอุปกรณ์': 'Devices',
    'อุปกรณ์นี้': 'This device',
    'อุปกรณ์ใหม่': 'New Device',
    'ไม่ระบุชื่ออุปกรณ์': 'Unnamed Device',
    'ไม่พบอุปกรณ์ในหมวดหมู่นี้': 'No devices in this category',
    'ไม่พบอุปกรณ์สำหรับเปิดโหมดพักรถ': 'No device is available for rest mode',
    'กรุณาลงทะเบียนอุปกรณ์ของคุณเพื่อเริ่มต้นใช้งานระบบตรวจจับ':
        'Register your device to start using driving detection.',
    'หมายเลข Serial Number อุปกรณ์': 'Device Serial Number',
    'เช่น SD-AI-2024XXXX': 'e.g. SD-AI-2024XXXX',
    'คำแนะนำ: หมายเลข Serial Number จะอยู่บนสติกเกอร์ที่ติดอยู่กับตัวเครื่องโปรดตรวจสอบให้ถูกต้อง':
        'Tip: Check the serial number printed on the device label.',
    'กรุณากรอกหมายเลข Serial Number อุปกรณ์':
        'Please enter the device serial number',
    'เช่น รอรับผู้โดยสาร': 'e.g. waiting for a passenger',
    'ลงทะเบียนอุปกรณ์สำเร็จแล้ว': 'Device registered successfully',
    'ลบอุปกรณ์': 'Delete Device',
    'ต้องการลบ': 'Do you want to delete',
    'ออกจากบัญชีหรือไม่?': 'from your account?',
    'ลบอุปกรณ์ออกจากบัญชีแล้ว': 'Device removed from your account',
    'ล้างการตั้งค่า Wi-Fi ของอุปกรณ์ด้วย':
        'Also clear the device Wi-Fi settings',
    'หากไม่เลือกล้าง Wi-Fi คุณสามารถลงทะเบียนอุปกรณ์กลับมาใหม่ได้ทันที':
        'Without clearing Wi-Fi, you can register the device again immediately.',
    'ออนไลน์': 'Online',
    'ออฟไลน์': 'Offline',
    'เชื่อมต่อแล้ว': 'Connected',
    'การเชื่อมต่อ': 'Connection',
    'ไม่มีสถานะ': 'No status',
    'สถานะไฟเลี้ยง': 'Power Status',
    'ปฏิบัติงานปกติ': 'Operating Normally',
    'ระบบปิดการทำงานอยู่': 'System Inactive',
    'ระบบจะเริ่มทำงานอัตโนมัติเมื่อจ่ายไฟเข้าอุปกรณ์':
        'The system starts automatically when the device receives power.',
    'กำลังตรวจสอบพฤติกรรมการขับขี่แบบเรียลไทม์...':
        'Monitoring driving behavior in real time...',
    'ระบบ AI กำลังคุ้มครองคุณ': 'AI is protecting you',
    'ระบบติดตามอัจฉริยะ เพื่อการขับขี่ที่ปลอดภัย':
        'Smart monitoring for safer driving',
    'หยุดการตรวจจับ': 'Stop Detection',
    'เริ่มตรวจจับ': 'Start Detection',
    'เสียงเตือน': 'Alert Sound',
    'เลือกเสียงที่จะใช้แจ้งเตือนเมื่อระบบตรวจพบความเสี่ยง':
        'Choose the sound played when a risk is detected',
    'เสียงคลาสสิก (Classic)': 'Classic Sound',
    'เสียงสัญญาณสั้น (Beep)': 'Short Beep',
    'เสียงแจ้งเตือนไซเรน (Siren)': 'Warning Siren',
    'เสียงที่คุณอัปโหลดเอง': 'Your Uploaded Sounds',
    'ทดลองฟัง': 'Preview',
    'แตะเพื่อเปิดเสียงเตือน': 'Tap to preview the alert sound',
    'อัปโหลดเสียงใหม่': 'Upload New Sound',
    'อัปโหลดเสียงได้สูงสุด 5 เสียงต่ออุปกรณ์ โดยไม่นับเสียงหลัก 3 เสียง':
        'Upload up to 5 sounds per device, excluding the 3 built-in sounds.',
    'รองรับเฉพาะไฟล์ MP3, WAV, M4A, AAC, OGG, OPUS, FLAC และ MP4':
        'Supported formats: MP3, WAV, M4A, AAC, OGG, OPUS, FLAC, and MP4',
    'ไฟล์เสียงต้องมีขนาดไม่เกิน 10 MB': 'Audio files must not exceed 10 MB',
    'บันทึกการตั้งค่าทั้งหมด': 'Save All Settings',
    'บันทึกปรับแต่งฮาร์ดแวร์สำเร็จแล้ว': 'Hardware settings saved successfully',
    'ลบไฟล์เสียง': 'Delete Audio',
    'ลบไฟล์เสียงสำเร็จ': 'Audio deleted successfully',
    'ชื่อ Wi-Fi (SSID)': 'Wi-Fi Name (SSID)',
    'รหัสผ่าน Wi-Fi': 'Wi-Fi Password',
    'ส่งข้อมูลให้กล้องเชื่อมต่อเน็ต': 'Connect Camera to Wi-Fi',
    'กำลังส่งข้อมูล Wi-Fi ไปยังกล้อง...':
        'Sending Wi-Fi information to the camera...',
    'เชื่อมต่อสำเร็จ': 'Connected Successfully',
    'กล้องเชื่อมต่อ Wi-Fi สำเร็จแล้ว':
        'The camera connected to Wi-Fi successfully',
    'กล้องเชื่อมต่อ Wi-Fi สำเร็จแล้ว เมื่อกดตกลงระบบจะบันทึกอุปกรณ์ลงฐานข้อมูลให้อัตโนมัติ':
        'The camera is connected to Wi-Fi. Tap OK to save the device automatically.',
    'กล้องเชื่อมต่อ Wi-Fi แล้ว แต่บันทึกอุปกรณ์ไม่สำเร็จ กรุณากดลองบันทึกอีกครั้ง':
        'The camera is online, but the device could not be saved. Please retry.',
    'ข้อมูล Wi-Fi ไม่ถูกต้อง': 'Invalid Wi-Fi information',
    'สแกน QR Code': 'Scan QR Code',
    'เล็งกล้องไปที่ QR Code บนตัวอุปกรณ์':
        'Point the camera at the QR code on the device',
    'สแกน QR Code สำเร็จ': 'QR Code scanned successfully',
    'ลิงก์จาก QR Code': 'QR Code Link',
    'แสดงลิงก์ที่อ่านได้จาก QR Code': 'Shows the link read from the QR code',
    'ไม่พบข้อมูลในลิงก์ QR Code': 'No data found in the QR code link',
    'ดึงข้อมูลจากลิงก์มาใส่ในช่องเรียบร้อยแล้ว':
        'The information from the link was added successfully',
    'สแกนสำเร็จ': 'Scan successful',

    // Risk-event and sound settings.
    'ตรวจพบพฤติกรรมเสี่ยง': 'Risky behavior detected',
    'ปิดเสียง': 'Stop Sound',
    'รับทราบ': 'Acknowledge',
    'เสียงแจ้งเตือน': 'Alert Sounds',
    'เสียงแจ้งเตือนทั่วไป (ครั้งที่ 1–2)':
        'General alert sound (detections 1–2)',
    'กำหนดเสียงทั่วไปและเสียงระดับเสี่ยงสูงแยกจากกัน':
        'Choose separate sounds for general and high-risk alerts',
    'เสียงระดับเสี่ยงสูง (ครบ 3 ครั้ง)':
        'High-risk sound (3 detections)',
    'เสียงที่เล่นในหน้าแจ้งเตือนและจากอุปกรณ์':
        'Sound used on the critical alert screen and device',

    // General status and error fragments used by interpolated messages.
    'สำเร็จแล้ว': 'completed successfully',
    'ไม่สำเร็จ': 'failed',
    'เกิดข้อผิดพลาด': 'An error occurred',
    'โหลดข้อมูลโปรไฟล์ล้มเหลว': 'Failed to load profile',
    'โหลดข้อมูลอุปกรณ์ล้มเหลว': 'Failed to load devices',
    'โหลดรายละเอียดแจ้งเตือนไม่สำเร็จ': 'Failed to load notification details',
    'บันทึกข้อมูลล้มเหลว': 'Failed to save information',
    'บันทึกขนาดตัวอักษรไม่สำเร็จ': 'Failed to save text size',
    'บันทึกภาษาไม่สำเร็จ': 'Failed to save language',
    'อัปโหลดรูปภาพไม่สำเร็จ': 'Failed to upload image',
    'เลือกไฟล์เสียงไม่สำเร็จ': 'Failed to choose an audio file',
    'อัปโหลดไฟล์เสียงไม่สำเร็จ': 'Failed to upload audio',
    'อัปโหลดไฟล์เสียงสำเร็จแล้ว และตั้งเป็นเสียงที่ใช้งานให้อัตโนมัติ':
        'Audio uploaded and set as the active sound automatically',
    'ลบไฟล์เสียงไม่สำเร็จ': 'Failed to delete audio',
    'ลบอุปกรณ์ไม่สำเร็จ': 'Failed to delete device',
    'ล้มเหลวในการอ่านการตั้งค่าปัจจุบัน': 'Failed to read the current settings',
    'ไม่สามารถทดลองฟังไฟล์เสียงนี้ได้': 'Unable to preview this audio file',
    'ไม่สามารถบันทึกได้': 'Unable to save',
    'ไม่สามารถอ่านข้อมูลจากลิงก์ QR Code ได้':
        'Unable to read data from the QR code link',
    'Chrome ไม่สามารถเล่นเสียงได้': 'Chrome could not play the audio',
    'ส่งคำขอไม่สำเร็จ กรุณาลองใหม่': 'Request failed. Please try again.',
    'สำหรับผู้ขับรถ': 'For Drivers',
    'ตรวจพบความเสี่ยง\nง่วงนอนหลับใน!': 'Risk detected\nDrowsiness warning!',
    'ตรวจพบพฤติกรรมเสี่ยง\nระหว่างการขับขี่':
        'Risky driving behavior\ndetected',
    'จบทริปไม่สำเร็จ': 'Failed to end trip',
    'จบทริปและบันทึกลง History แล้ว ระยะทาง':
        'Trip ended and saved to History. Distance',
    'ทำรายการไม่สำเร็จ กรุณาลองใหม่': 'The operation failed. Please try again.',
    'ไม่มีข้อมูล': 'No data',
    'ยังไม่ได้ระบุ': 'Not specified',
    'ไม่ระบุประเภท': 'Type not specified',
    'รวม': 'Total',
    'จาก': 'from',
    'ถึง': 'to',
    'เหลือ': 'remaining',
    'นาน': 'for',
  };
}
