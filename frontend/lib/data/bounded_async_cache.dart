/// Reuse in-flight reads as well as completed results, with a bounded LRU.
/// Failed or superseded reads must never poison a later retry.
class BoundedAsyncCache<K, V> {
  final int capacity;
  final _entries = <K, Future<V>>{};
  final _values = <K, V>{};
  BoundedAsyncCache({required this.capacity}) : assert(capacity > 0);

  Future<V> load(K key, Future<V> Function() loader) {
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      return cached;
    }
    late final Future<V> pending;
    pending = Future<V>.sync(loader).then(
      (value) {
        if (identical(_entries[key], pending)) _values[key] = value;
        return value;
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_entries[key], pending)) _entries.remove(key);
        Error.throwWithStackTrace(error, stack);
      },
    );
    if (_entries.length == capacity) remove(_entries.keys.first);
    _entries[key] = pending;
    return pending;
  }

  V? peek(K key) => _values[key];

  void store(K key, V value) {
    remove(key);
    if (_entries.length == capacity) remove(_entries.keys.first);
    _entries[key] = Future.value(value);
    _values[key] = value;
  }

  void clear() {
    _entries.clear();
    _values.clear();
  }

  void remove(K key) {
    _entries.remove(key);
    _values.remove(key);
  }
}
