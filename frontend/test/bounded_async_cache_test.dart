import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/data/bounded_async_cache.dart';

void main() {
  test(
    'Ready values are synchronous; invalidation and late reads cannot restore stale content',
    () async {
      final cache = BoundedAsyncCache<int, int>(capacity: 2);
      final pending = Completer<int>();
      final first = cache.load(1, () => pending.future);
      expect(cache.peek(1), isNull);
      pending.complete(42);
      await first;
      expect(cache.peek(1), 42);
      final late = Completer<int>();
      final old = cache.load(2, () => late.future);
      cache.store(2, 20);
      late.complete(99);
      await old;
      expect(cache.peek(2), 20);
      cache.store(3, 30);
      expect(cache.peek(1), isNull);
      cache.clear();
      expect(cache.peek(2), isNull);
      expect(cache.peek(3), isNull);
    },
  );
  test(
    'Concurrent consumers share one read; recent results survive eviction',
    () async {
      final cache = BoundedAsyncCache<int, int>(capacity: 2);
      var reads = 0;
      final pending = Completer<int>();
      Future<int> read() {
        reads++;
        return pending.future;
      }

      final first = cache.load(1, read), second = cache.load(1, read);
      expect(identical(first, second), isTrue);
      expect(reads, 1);
      pending.complete(42);
      expect(await first, 42);
      await cache.load(2, () async => 2);
      expect(await cache.load(1, () async => -1), 42);
      await cache.load(3, () async => 3);
      expect(await cache.load(2, () async => 200), 200);
    },
  );

  test(
    'Failed reads retry and cannot remove a replacement after invalidation',
    () async {
      final cache = BoundedAsyncCache<int, int>(capacity: 6);
      final oldRead = Completer<int>();
      final oldResult = cache.load(1, () => oldRead.future);
      final failure = expectLater(oldResult, throwsStateError);
      cache.clear();
      expect(await cache.load(1, () async => 20), 20);
      oldRead.completeError(StateError('old request'));
      await failure;
      expect(await cache.load(1, () async => -1), 20);
      await expectLater(
        cache.load(2, () async => throw StateError('offline')),
        throwsStateError,
      );
      expect(await cache.load(2, () async => 30), 30);
      cache.clear();
      expect(await cache.load(1, () async => 99), 99);
    },
  );
}
