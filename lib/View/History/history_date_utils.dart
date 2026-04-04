import 'package:point/Models/ContentModel.dart';

/// أشهر وسنوات بين أول وآخر [publishDate] في القائمة (للفلاتر).
List<String> historyExtractMonthsAndYears(List<ContentModel> contents) {
  final dates =
      contents
          .where((c) => c.publishDate != null)
          .map((c) => c.publishDate!)
          .toList();

  if (dates.isEmpty) return [];

  final first = dates.reduce((a, b) => a.isBefore(b) ? a : b);
  final last = dates.reduce((a, b) => a.isAfter(b) ? a : b);

  final List<String> result = [];
  DateTime current = DateTime(first.year, first.month);

  while (current.isBefore(DateTime(last.year, last.month + 1))) {
    final formatted =
        "${current.year}-${current.month.toString().padLeft(2, '0')}";
    result.add(formatted);
    current = DateTime(current.year, current.month + 1);
  }

  return result;
}
