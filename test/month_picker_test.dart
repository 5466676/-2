import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greeting_cleaner/widgets/month_picker.dart';

void main() {
  testWidgets('lists months newest first and reports the tapped one',
      (tester) async {
    (int, int)? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthPicker(
            now: DateTime(2026, 2, 10),
            onPicked: (y, m) => picked = (y, m),
          ),
        ),
      ),
    );

    expect(find.text('شباط 2026'), findsOneWidget);
    expect(find.text('الشهر الحالي'), findsOneWidget);

    await tester.tap(find.text('كانون الأول 2025'));
    expect(picked, (2025, 12));
  });
}
