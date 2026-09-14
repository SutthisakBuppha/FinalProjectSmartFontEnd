import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mockup_project/services/language_service.dart';
import 'package:mockup_project/theme/app_theme.dart';

void main() {
  testWidgets('เปลี่ยนภาษาไทยและอังกฤษพร้อมบันทึกค่าที่เลือก', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = LanguageController.instance;
    await controller.setLanguage('th');

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppText('โปรไฟล์'))),
    );
    expect(find.text('โปรไฟล์'), findsOneWidget);

    await controller.setLanguage('en');
    await tester.pump();

    expect(find.text('Profile'), findsOneWidget);
    expect(controller.translate('แจ้งเตือน 3 ครั้ง'), 'Notifications 3 times');
    expect(
      controller.translate('เปิดโหมดพักรถแล้ว 15 นาที'),
      'Rest mode enabled for 15 min',
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_language_code'), 'en');

    await controller.setLanguage('th');
  });
}
