import 'package:flutter_test/flutter_test.dart';
import 'package:point/Services/notification_navigation/notification_destination.dart';
import 'package:point/Services/notification_navigation/notification_destination_parser.dart';

void main() {
  group('NotificationDestinationParser', () {
    test('skips silent-sync payloads', () {
      expect(
        NotificationDestinationParser.parseStringMap({
          'silentSync': '1',
          'notificationType': 'employee_task_assigned',
          'taskId': 't1',
        }),
        isNull,
      );
      expect(
        NotificationDestinationParser.parseStringMap({
          'fcmSilentSync': 'true',
          'notificationType': 'chat_message',
        }),
        isNull,
      );
    });

    test('chat_message with chatId opens chat', () {
      final dest = NotificationDestinationParser.parseStringMap({
        'notificationType': 'chat_message',
        'chatId': 'c1',
        'chatTitle': 'Sara',
        'isGroup': '0',
      });
      expect(dest, isNotNull);
      expect(dest!.kind, NotificationDestinationKind.chat);
      expect(dest.chatId, 'c1');
      expect(dest.chatTitle, 'Sara');
      expect(dest.isGroup, isFalse);
    });

    test('chatId aliases chat_id', () {
      final dest = NotificationDestinationParser.parseStringMap({
        'notificationType': 'chat_message',
        'chat_id': 'abc',
      });
      expect(dest!.chatId, 'abc');
      expect(dest.kind, NotificationDestinationKind.chat);
    });

    test('chat_message without chatId falls back to chat list', () {
      final dest = NotificationDestinationParser.parseStringMap({
        'notificationType': 'chat_message',
      });
      expect(dest!.kind, NotificationDestinationKind.chatList);
    });

    test('legacy type=chat_message is treated as chat', () {
      final dest = NotificationDestinationParser.parseStringMap({
        'type': 'chat_message',
        'chatId': 'c2',
      });
      expect(dest!.kind, NotificationDestinationKind.chat);
      expect(dest.chatId, 'c2');
    });

    test('chat_unread_digest opens chat list', () {
      final dest = NotificationDestinationParser.parseStringMap({
        'notificationType': 'chat_unread_digest',
      });
      expect(dest!.kind, NotificationDestinationKind.chatList);
    });

    test('task types map to task even without taskId', () {
      final dest = NotificationDestinationParser.parseStringMap({
        'notificationType': 'employee_task_assigned',
      });
      expect(dest!.kind, NotificationDestinationKind.task);
      expect(dest.taskId, isNull);
    });

    test('task extras are read', () {
      final dest = NotificationDestinationParser.parseStringMap({
        'notificationType': 'manager_task_overdue',
        'taskId': 'tid',
        'taskType': '1',
      });
      expect(dest!.kind, NotificationDestinationKind.task);
      expect(dest.taskId, 'tid');
      expect(dest.taskType, '1');
    });

    test('content and publish kinds', () {
      expect(
        NotificationDestinationParser.parseStringMap({
          'notificationType': 'client_content_pending_approval',
          'contentId': 'cid',
        })!.kind,
        NotificationDestinationKind.content,
      );
      expect(
        NotificationDestinationParser.parseStringMap({
          'notificationType': 'publish_post_one_hour',
          'contentId': 'cid',
        })!.kind,
        NotificationDestinationKind.publish,
      );
    });

    test('attendance and home kinds', () {
      expect(
        NotificationDestinationParser.parseStringMap({
          'notificationType': 'employee_attendance_check_in',
        })!.kind,
        NotificationDestinationKind.attendance,
      );
      expect(
        NotificationDestinationParser.parseStringMap({
          'notificationType': 'broadcast_topic',
        })!.kind,
        NotificationDestinationKind.home,
      );
    });

    test('unknown type returns null', () {
      expect(
        NotificationDestinationParser.parseStringMap({
          'notificationType': 'not_a_real_type',
        }),
        isNull,
      );
    });

    test('empty or missing type returns null', () {
      expect(NotificationDestinationParser.parseStringMap({}), isNull);
      expect(NotificationDestinationParser.parse(null), isNull);
    });
  });
}
