import 'dart:async';
import 'dart:developer';

/// Rate limiter لتجنّب تجاوز حدود الاستدعاء (مثل 429).
///
/// يتم ضمان عدم تجاوز [maxRequestsPerSecond] تقريبًا عبر فرض حد أدنى بين
/// "بداية" كل استدعاء وآخره.
class EdgeFunctionRateLimiter {
  EdgeFunctionRateLimiter._();

  static final EdgeFunctionRateLimiter instance = EdgeFunctionRateLimiter._();

  final int maxRequestsPerSecond = 5;

  // 5 req/sec => 200ms بين بداية كل طلب وآخره.
  Duration get minInterval => const Duration(milliseconds: 200);

  // سلسلة Future لضمان الترتيب (serialization).
  Future<void> _queue = Future.value();

  // متى يمكن تنفيذ الطلب التالي.
  DateTime _nextAllowed = DateTime.fromMillisecondsSinceEpoch(0);

  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();

    _queue = _queue.then((_) async {
      final now = DateTime.now();
      final wait = _nextAllowed.difference(now);
      if (wait > Duration.zero) {
        // سجلات التهدئة تساعد في debug 429.
        log('⏳ EdgeFunctionRateLimiter waiting ${wait.inMilliseconds}ms');
        await Future<void>.delayed(wait);
      }

      // تحديد وقت التنفيذ التالي قبل تنفيذ action لضمان التباعد بين start times.
      _nextAllowed = DateTime.now().add(minInterval);

      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });

    return completer.future;
  }
}

