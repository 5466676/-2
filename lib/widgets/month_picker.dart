import 'package:flutter/material.dart';

import '../config.dart';

const arabicMonths = [
  'كانون الثاني',
  'شباط',
  'آذار',
  'نيسان',
  'أيار',
  'حزيران',
  'تموز',
  'آب',
  'أيلول',
  'تشرين الأول',
  'تشرين الثاني',
  'كانون الأول',
];

String monthLabel(int year, int month) => '${arabicMonths[month - 1]} $year';

/// لستة الشهور الأخيرة (الأحدث فوق).
class MonthPicker extends StatelessWidget {
  const MonthPicker({super.key, required this.onPicked, this._now});

  final void Function(int year, int month) onPicked;
  final DateTime? _now;

  @override
  Widget build(BuildContext context) {
    final now = _now ?? DateTime.now();
    final months = [
      for (var i = 0; i < AppConfig.monthsBack; i++)
        DateTime(now.year, now.month - i),
    ];
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: months.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final m = months[i];
        return ListTile(
          leading: const Icon(Icons.calendar_month_outlined),
          title: Text(monthLabel(m.year, m.month)),
          subtitle: i == 0 ? const Text('الشهر الحالي') : null,
          trailing: const Icon(Icons.chevron_left),
          onTap: () => onPicked(m.year, m.month),
        );
      },
    );
  }
}
