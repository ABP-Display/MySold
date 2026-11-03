import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/data/bounded_async_cache.dart';

void main() {
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
