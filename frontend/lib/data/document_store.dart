import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'api_client.dart';

// A local document API preserves the screens and the portable CSV schema.
// Every read/write goes to our own server, never to a third-party SDK.
class Timestamp {
  final DateTime _date;
  Timestamp.fromDate(DateTime date) : _date = date.toUtc();
  Timestamp.now() : _date = DateTime.now().toUtc();
  DateTime toDate() => _date.toLocal();
  int get millisecondsSinceEpoch => _date.millisecondsSinceEpoch;
}

class GeoPoint {
  final double latitude;
  final double longitude;
  const GeoPoint(this.latitude, this.longitude);
}

class FieldValue {
  final String operation;
  final num? value;
  const FieldValue._(this.operation, [this.value]);
  static FieldValue increment(num value) => FieldValue._('increment', value);
  static FieldValue serverTimestamp() => const FieldValue._('serverTimestamp');
}

dynamic encodeValue(dynamic value) {
  if (value is Timestamp)
    return {'_type': 'timestamp', 'value': value._date.toIso8601String()};
  if (value is DateTime) return encodeValue(Timestamp.fromDate(value));
  if (value is GeoPoint)
    return {
      '_type': 'geoPoint',
      'latitude': value.latitude,
      'longitude': value.longitude,
    };
  if (value is DocumentReference)
    return {'_type': 'reference', 'path': value.path};
  if (value is FieldValue)
    return {
      '_op': value.operation,
      if (value.value != null) 'value': value.value,
    };
  if (value is Map)
    return value.map((k, v) => MapEntry(k.toString(), encodeValue(v)));
  if (value is List) return value.map(encodeValue).toList();
  return value;
}

dynamic decodeValue(dynamic value) {
  if (value is List) return value.map(decodeValue).toList();
  if (value is Map) {
    if (value['_type'] == 'timestamp')
      return Timestamp.fromDate(DateTime.parse(value['value']));
    if (value['_type'] == 'geoPoint')
      return GeoPoint(
        (value['latitude'] as num).toDouble(),
        (value['longitude'] as num).toDouble(),
      );
    if (value['_type'] == 'reference')
      return DocumentStore.instance.doc(value['path']);
    return value.map((k, v) => MapEntry(k.toString(), decodeValue(v)));
  }
  return value;
}

String newDocumentId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

class SetOptions {
  final bool merge;
  const SetOptions({this.merge = false});
}

class DocumentStore {
  static final instance = DocumentStore._();
  DocumentStore._();
  final _changes = StreamController<void>.broadcast();
  final Map<String, Future<Map<String, dynamic>>> _cache = {};
  int _generation = 0;
  void clear() {
    _cache.clear();
    _generation++;
    _changes.add(null);
  }

  CollectionReference<Map<String, dynamic>> collection(String path) =>
      CollectionReference(path);
  DocumentReference<Map<String, dynamic>> doc(String path) =>
      DocumentReference(path);
  WriteBatch batch() => WriteBatch();

  Future<Map<String, dynamic>> read(String route, Map<String, dynamic> body) {
    final key = '$route:${jsonEncode(body)}';
    return _cache.putIfAbsent(key, () async {
      try {
        return await ApiClient.instance.request(route, body);
      } catch (_) {
        _cache.remove(key);
        rethrow;
      }
    });
  }

  Future<void> commit(List<Map<String, dynamic>> operations) async {
    await ApiClient.instance.request('documents/commit', {
      'requestId': newDocumentId(),
      'operations': operations,
    });
    clear();
  }
}

class DocumentReference<T extends Map<String, dynamic>> {
  final String path;
  DocumentReference(this.path);
  String get id => path.split('/').last;
  CollectionReference<T> get parent =>
      CollectionReference(path.substring(0, path.lastIndexOf('/')));
  CollectionReference<Map<String, dynamic>> collection(String name) =>
      CollectionReference('$path/$name');
  Future<DocumentSnapshot<T>> get() async {
    final result = await DocumentStore.instance.read('documents/get', {
      'path': path,
    });
    return DocumentSnapshot<T>(
      this,
      result['data'] == null ? null : decodeValue(result['data']) as T,
    );
  }

  Future<void> set(T data, [SetOptions? options]) =>
      DocumentStore.instance.commit([
        {
          'path': path,
          'action': 'set',
          'merge': options?.merge ?? false,
          'data': encodeValue(data),
        },
      ]);
  Future<void> update(Map<String, dynamic> data) =>
      DocumentStore.instance.commit([
        {'path': path, 'action': 'update', 'data': encodeValue(data)},
      ]);
  Future<void> delete() => DocumentStore.instance.commit([
    {'path': path, 'action': 'delete'},
  ]);
}

class DocumentSnapshot<T extends Map<String, dynamic>> {
  final DocumentReference<T> reference;
  final T? _data;
  DocumentSnapshot(this.reference, this._data);
  String get id => reference.id;
  bool get exists => _data != null;
  T? data() => _data;
  dynamic operator [](String key) => _data?[key];
}

class QueryDocumentSnapshot<T extends Map<String, dynamic>>
    extends DocumentSnapshot<T> {
  QueryDocumentSnapshot(DocumentReference<T> reference, T data)
    : super(reference, data);
  @override
  T data() => super.data()!;
}

class QuerySnapshot<T extends Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<T>> docs;
  QuerySnapshot(this.docs);
  int get size => docs.length;
}

class Query<T extends Map<String, dynamic>> {
  final String path;
  final List<Map<String, dynamic>> filters;
  final String? order;
  final bool descending;
  final int? maximum;
  Query(
    this.path, {
    this.filters = const [],
    this.order,
    this.descending = false,
    this.maximum,
  });
  Query<T> where(
    String field, {
    dynamic isEqualTo,
    dynamic isGreaterThanOrEqualTo,
    dynamic isLessThan,
  }) {
    final op = isGreaterThanOrEqualTo != null
        ? 'gte'
        : isLessThan != null
        ? 'lt'
        : 'eq';
    return Query<T>(
      path,
      filters: [
        ...filters,
        {
          'field': field,
          'op': op,
          'value': encodeValue(
            isGreaterThanOrEqualTo ?? isLessThan ?? isEqualTo,
          ),
        },
      ],
      order: order,
      descending: descending,
      maximum: maximum,
    );
  }

  Query<T> orderBy(String field, {bool descending = false}) => Query<T>(
    path,
    filters: filters,
    order: field,
    descending: descending,
    maximum: maximum,
  );
  Query<T> limit(int count) => Query<T>(
    path,
    filters: filters,
    order: order,
    descending: descending,
    maximum: count,
  );
  Future<QuerySnapshot<T>> get() async {
    final docs = <QueryDocumentSnapshot<T>>[];
    String? cursor;
    do {
      final result = await DocumentStore.instance.read('documents/query', {
        'path': path,
        'filters': filters,
        'order': order,
        'descending': descending,
        'limit': maximum,
        'cursor': cursor,
      });
      for (final row in result['documents'] as List) {
        docs.add(
          QueryDocumentSnapshot<T>(
            DocumentReference<T>(row['path']),
            decodeValue(row['data']) as T,
          ),
        );
      }
      cursor = result['cursor'] as String?;
    } while (cursor != null && (maximum == null || docs.length < maximum!));
    return QuerySnapshot(docs);
  }

  Stream<QuerySnapshot<T>> snapshots() async* {
    final store = DocumentStore.instance;
    // Subscribe before the first read so a mutation during that read is kept.
    final subscription = StreamIterator(store._changes.stream);
    try {
      var generation = store._generation;
      yield await get();
      while (await subscription.moveNext()) {
        if (generation == store._generation) continue;
        generation = store._generation;
        yield await get();
      }
    } finally {
      await subscription.cancel();
    }
  }
}

class CollectionReference<T extends Map<String, dynamic>> extends Query<T> {
  CollectionReference(super.path);
  String get id => path.split('/').last;
  DocumentReference<T> doc([String? id]) =>
      DocumentReference('$path/${id ?? newDocumentId()}');
  Future<DocumentReference<T>> add(T data) async {
    final ref = doc();
    await ref.set(data);
    return ref;
  }
}

class WriteBatch {
  final _operations = <Map<String, dynamic>>[];
  void set<T extends Map<String, dynamic>>(
    DocumentReference<T> ref,
    T data, [
    SetOptions? options,
  ]) => _operations.add({
    'path': ref.path,
    'action': 'set',
    'merge': options?.merge ?? false,
    'data': encodeValue(data),
  });
  void update(DocumentReference ref, Map<String, dynamic> data) => _operations
      .add({'path': ref.path, 'action': 'update', 'data': encodeValue(data)});
  void delete(DocumentReference ref) =>
      _operations.add({'path': ref.path, 'action': 'delete'});
  Future<void> commit() => DocumentStore.instance.commit(_operations);
}
