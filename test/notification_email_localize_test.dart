import 'package:flutter_test/flutter_test.dart';
import 'package:point/Services/NotificationService.dart';
import 'package:point/Services/notification_email_fields.dart';
import 'package:point/Services/task_client_name_resolver.dart';

void main() {
  group('NotificationService.localizeTaskEmailContext', () {
    test('translates priority imp for ar and en', () {
      const ctx = TaskEmailContext(taskTitle: 'Test', priority: 'imp');

      final ar = NotificationService.localizeTaskEmailContext('ar', ctx);
      expect(ar.priority, 'مهم');

      final en = NotificationService.localizeTaskEmailContext('en', ctx);
      expect(en.priority, 'Important');
    });

    test('localizes department type index 6 to programming department', () {
      const ctx = TaskEmailContext(taskTitle: 'Test', department: '6');

      final ar = NotificationService.localizeTaskEmailContext('ar', ctx);
      expect(ar.department, 'قسم البرمجة');

      final en = NotificationService.localizeTaskEmailContext('en', ctx);
      expect(en.department, 'Programming');
    });

    test('keeps already-localized priority text when not a storage key', () {
      const ctx = TaskEmailContext(taskTitle: 'Test', priority: 'custom label');

      final localized = NotificationService.localizeTaskEmailContext('ar', ctx);
      expect(localized.priority, 'custom label');
    });
  });

  group('taskClientRefLooksLikeTechnicalId', () {
    test('detects UUID-like client refs', () {
      expect(
        taskClientRefLooksLikeTechnicalId(
          '29c30918-ac00-42ab-b929-6176dee99c7c',
        ),
        isTrue,
      );
      expect(taskClientRefLooksLikeTechnicalId('Acme Corp'), isFalse);
      expect(taskClientRefLooksLikeTechnicalId(''), isFalse);
    });
  });
}
