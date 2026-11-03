/// Reuse in-flight reads as well as completed results, with a bounded LRU.
/// Failed or superseded reads must never poison a later retry.
class BoundedAsyncCache<K, V> {
  final int capacity;
  final _entries = <K, Future<V>>{};
  BoundedAsyncCache({required this.capacity}) : assert(capacity > 0);

  Future<V> load(K key, Future<V> Function() loader) {
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      return cached;
    }
    late final Future<V> pending;
    pending = Future<V>.sync(loader).then(
      (value) => value,
      onError: (Object error, StackTrace stack) {
        if (identical(_entries[key], pending)) _entries.remove(key);
        Error.throwWithStackTrace(error, stack);
      },
    );
    if (_entries.length == capacity) _entries.remove(_entries.keys.first);
    _entries[key] = pending;
    return pending;
  }

  void clear() => _entries.clear();
  void remove(K key) => _entries.remove(key);
}
