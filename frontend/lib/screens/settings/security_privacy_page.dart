import 'package:mysold/widgets/app_design.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mysold/data/document_store.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mysold/services/auth_service.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/login_page.dart';
import 'package:mysold/providers/user_data_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/services/security_gate.dart';

int _compareImportDocuments(_ImportDocument a, _ImportDocument b) {
  const collections = [
    'accounts',
    'categories',
    'investments',
    'transactions',
    'budgetAlerts',
  ];
  int priority(String path) {
    final parts = path.split('/');
    return parts.length == 2 ? -1 : collections.indexOf(parts[2]);
  }

  final order = priority(a.path).compareTo(priority(b.path));
  return order != 0 ? order : a.path.compareTo(b.path);
}

class SecurityPrivacyPage extends StatefulWidget {
  const SecurityPrivacyPage({super.key});

  @override
  State<SecurityPrivacyPage> createState() => _SecurityPrivacyPageState();
}

class _SecurityPrivacyPageState extends State<SecurityPrivacyPage> {
  String _frequency = 'never';
  int _lockDelayMinutes = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isDeleting = false;

  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  static const _exportCollections = [
    'accounts',
    'categories',
    'investments',
    'transactions',
    'budgetAlerts',
  ];

  DocumentReference<Map<String, dynamic>>? get _userRef {
    final uid = LocalAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return DocumentStore.instance.collection('users').doc(uid);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  String _normalizeLockFrequency(dynamic value) {
    final raw = (value ?? 'never').toString().toLowerCase().trim();
    if (raw == 'always' ||
        raw == 'toujours' ||
        raw == 'chaque ouverture' ||
        raw == 'chaque ouverture de l app' ||
        raw == 'chaque ouverture de l\'app') {
      return 'always';
    }
    return 'never';
  }

  int _normalizeLockDelay(dynamic value) {
    if (value is num) return value.toInt().clamp(0, 1440).toInt();
    return int.tryParse((value ?? '0').toString())?.clamp(0, 1440).toInt() ?? 0;
  }

  Future<void> _load() async {
    final ref = _userRef;
    if (ref == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final data = (await ref.get()).data() ?? {};
    if (!mounted) return;
    setState(() {
      _frequency = _normalizeLockFrequency(data['reconnectionFrequency']);
      _lockDelayMinutes = _normalizeLockDelay(data['lockDelayMinutes']);
      _isLoading = false;
    });
  }

  Future<void> _saveSecurity() async {
    final authorized = await SecurityGate.requestPin(
      context,
      title: context.tr('Securite'),
      message: context.tr('Confirmez votre PIN avant de modifier la securite.'),
    );
    if (!authorized || !mounted) return;

    final ref = _userRef;
    if (ref == null) return;

    final pin = _pinCtrl.text.trim();
    final confirmPin = _confirmPinCtrl.text.trim();

    final update = <String, dynamic>{
      'reconnectionFrequency': _frequency,
      'lockDelayMinutes': _lockDelayMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (pin.isNotEmpty || confirmPin.isNotEmpty) {
      if (pin.length != 6 || pin != confirmPin) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Le PIN doit faire 6 chiffres identiques'),
            ),
          ),
        );
        return;
      }
      update['pin'] = _hashPin(pin);
    }

    setState(() => _isSaving = true);
    try {
      await ref.set(update, SetOptions(merge: true));
      _pinCtrl.clear();
      _confirmPinCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Parametres de securite enregistres')),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _exportUserData() async {
    final authorized = await SecurityGate.requestPin(
      context,
      title: context.tr('Exporter mes donnees'),
      message: context.tr('Confirmez votre PIN avant d exporter vos donnees.'),
    );
    if (!authorized || !mounted) return;

    final ref = _userRef;
    if (ref == null) return;

    setState(() => _isExporting = true);
    try {
      final lines = <List<String>>[_exportHeader()];
      final generatedAt = DateTime.now().toUtc().toIso8601String();

      lines.add([
        'meta',
        '0',
        '',
        '',
        '',
        '',
        '',
        'exportSchemaVersion',
        'string',
        '3',
        'Format MySold restaurable sans UID: utiliser documentPath + fieldPath.',
      ]);
      lines.add([
        'meta',
        '0',
        '',
        '',
        '',
        '',
        '',
        'generatedAt',
        'timestamp',
        generatedAt,
        'Date UTC de generation de l export.',
      ]);
      lines.add([
        'meta',
        '0',
        'user',
        'user',
        '',
        'user',
        'user',
        'rootDocumentPath',
        'documentPath',
        'user',
        'Document utilisateur racine. L UID courant est applique uniquement a l import.',
      ]);

      final userDoc = await ref.get();
      lines.add(_collectionRow(collectionPath: 'user'));
      _appendDocumentRows(
        lines,
        userDoc,
        parentDocumentPath: '',
        userRootPath: ref.path,
      );

      for (final collection in _exportCollections) {
        final collectionRef = ref.collection(collection);
        final snapshot = await collectionRef.get();
        lines.add(
          _collectionRow(
            collectionPath: _relativeExportPath(collectionRef.path, ref.path),
            parentDocumentPath: 'user',
          ),
        );

        for (final doc in snapshot.docs) {
          _appendDocumentRows(
            lines,
            doc,
            parentDocumentPath: 'user',
            userRootPath: ref.path,
          );
        }
      }

      final csv = lines.map(_csvLine).join('\n');
      final bytes = Uint8List.fromList(utf8.encode(csv));
      await FileSaver.instance.saveAs(
        name: 'mysold_export_complet',
        bytes: bytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Export des donnees lance.'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('Export impossible')} : $e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importUserData() async {
    final authorized = await SecurityGate.requestPin(
      context,
      title: context.tr('Importer mes donnees'),
      message: context.tr('Confirmez votre PIN avant d importer des donnees.'),
    );
    if (!authorized || !mounted) return;

    final uid = LocalAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ImportProgressPage(uid: uid)),
    );
    if (!mounted) return;
    context.read<UserDataProvider>().invalidateReferences();
  }

  List<List<String>> _parseCsv(String source) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < source.length; i++) {
      final char = source[i];
      final next = i + 1 < source.length ? source[i + 1] : '';

      if (char == '"') {
        if (inQuotes && next == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }

      if (!inQuotes && char == ',') {
        row.add(cell.toString());
        cell.clear();
        continue;
      }

      if (!inQuotes && (char == '\n' || char == '\r')) {
        if (char == '\r' && next == '\n') i++;
        row.add(cell.toString());
        cell.clear();
        if (row.any((value) => value.isNotEmpty)) rows.add(row);
        row = <String>[];
        continue;
      }

      cell.write(char);
    }

    row.add(cell.toString());
    if (row.any((value) => value.isNotEmpty)) rows.add(row);
    return rows;
  }

  List<_ImportDocument> _buildImportDocuments(
    List<List<String>> rows,
    String currentUid,
  ) {
    if (rows.length < 2) return [];

    final header = rows.first;
    final index = <String, int>{
      for (var i = 0; i < header.length; i++) header[i]: i,
    };
    for (final requiredColumn in [
      'rowType',
      'documentPath',
      'fieldPath',
      'valueType',
      'value',
    ]) {
      if (!index.containsKey(requiredColumn)) {
        throw Exception('Colonne manquante: $requiredColumn');
      }
    }

    final sourceRoot = _detectSourceRoot(rows, index);
    final targetRoot = 'users/$currentUid';
    final documents = <String, _ImportDocument>{};

    for (final row in rows.skip(1)) {
      final rowType = _cell(row, index, 'rowType');
      if (rowType != 'document' && rowType != 'field') continue;

      final rawPath = _cell(row, index, 'documentPath');
      if (rawPath.isEmpty) continue;
      final documentPath = _remapImportPath(rawPath, sourceRoot, targetRoot);
      if (!_isSafeImportPath(documentPath, targetRoot)) {
        throw Exception('Chemin non autorise: $documentPath');
      }

      final doc = documents.putIfAbsent(
        documentPath,
        () => _ImportDocument(path: documentPath),
      );

      if (rowType != 'field') continue;
      final fieldPath = _cell(row, index, 'fieldPath');
      final valueType = _cell(row, index, 'valueType');
      if (valueType == 'emptyDocument' || fieldPath.isEmpty) continue;
      if (documentPath == targetRoot &&
          (!_allowedRootImportFields.contains(fieldPath) ||
              _protectedRootImportFields.contains(fieldPath))) {
        continue;
      }

      doc.data[fieldPath] = _restoreValue(
        valueType: valueType,
        value: _cell(row, index, 'value'),
        sourceRoot: sourceRoot,
        targetRoot: targetRoot,
      );
    }

    final result = documents.values.toList()..sort(_compareImportDocuments);
    return result;
  }

  static const _protectedRootImportFields = {
    'pin',
    'email',
    'authProvider',
    'createdAt',
    'lastConnection',
  };

  static const _allowedRootImportFields = {
    'firstName',
    'lastName',
    'phone',
    'theme',
    'currency',
    'currencyCode',
    'language',
    'languageCode',
    'reconnectionFrequency',
    'lockDelayMinutes',
    'updatedAt',
  };

  String _cell(List<String> row, Map<String, int> index, String column) {
    final cellIndex = index[column];
    if (cellIndex == null || cellIndex >= row.length) return '';
    return row[cellIndex].trim();
  }

  String _detectSourceRoot(List<List<String>> rows, Map<String, int> index) {
    for (final row in rows.skip(1)) {
      final fieldPath = _cell(row, index, 'fieldPath');
      if (fieldPath == 'rootUserPath' || fieldPath == 'rootDocumentPath') {
        final value = _cell(row, index, 'value');
        if (value == 'user') return '';
        if (value.startsWith('users/')) return value;
      }
    }
    for (final row in rows.skip(1)) {
      final path = _cell(row, index, 'documentPath');
      final parts = path.split('/');
      if (parts.length >= 2 && parts.first == 'users') {
        return '${parts[0]}/${parts[1]}';
      }
    }
    return '';
  }

  String _remapImportPath(String path, String sourceRoot, String targetRoot) {
    final cleanPath = path.trim().replaceAll('\\', '/');
    if (cleanPath.isEmpty || cleanPath == 'user' || cleanPath == '.') {
      return targetRoot;
    }
    if (sourceRoot.isNotEmpty && cleanPath == sourceRoot) return targetRoot;
    if (sourceRoot.isNotEmpty && cleanPath.startsWith('$sourceRoot/')) {
      return '$targetRoot/${cleanPath.substring(sourceRoot.length + 1)}';
    }
    final parts = cleanPath.split('/');
    if (parts.length >= 2 && parts.first == 'users') {
      final suffix = parts.skip(2).join('/');
      return suffix.isEmpty ? targetRoot : '$targetRoot/$suffix';
    }
    if (_exportCollections.contains(parts.first)) {
      return '$targetRoot/$cleanPath';
    }
    return cleanPath;
  }

  bool _isSafeImportPath(String path, String targetRoot) {
    final parts = path.split('/');
    if (parts.length.isOdd) return false;
    if (path == targetRoot) return true;
    if (!path.startsWith('$targetRoot/')) return false;
    if (parts.length != 4) return false;
    return _exportCollections.contains(parts[2]);
  }

  dynamic _restoreValue({
    required String valueType,
    required String value,
    required String sourceRoot,
    required String targetRoot,
  }) {
    switch (valueType) {
      case 'null':
        return null;
      case 'boolean':
        return value.toLowerCase() == 'true';
      case 'integer':
        return int.tryParse(value) ?? 0;
      case 'double':
      case 'number':
        return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
      case 'timestamp':
        return Timestamp.fromDate(DateTime.parse(value));
      case 'geoPoint':
        final jsonValue = _tryJsonDecode(value);
        if (jsonValue is Map) {
          return GeoPoint(
            (jsonValue['latitude'] as num).toDouble(),
            (jsonValue['longitude'] as num).toDouble(),
          );
        }
        final parts = value.split(',');
        return GeoPoint(
          double.tryParse(parts.first.trim()) ?? 0,
          double.tryParse(parts.length > 1 ? parts[1].trim() : '0') ?? 0,
        );
      case 'documentReference':
        final referencePath = _remapImportPath(value, sourceRoot, targetRoot);
        if (!_isSafeImportPath(referencePath, targetRoot)) {
          throw Exception('Reference non autorisee: $referencePath');
        }
        return DocumentStore.instance.doc(referencePath);
      case 'array':
      case 'map':
        return _tryJsonDecode(value);
      default:
        return value;
    }
  }

  dynamic _tryJsonDecode(String value) {
    if (value.isEmpty) return value;
    try {
      return jsonDecode(value);
    } catch (_) {
      return value;
    }
  }

  Future<int> _countDuplicateDocuments(List<_ImportDocument> documents) async {
    var count = 0;
    for (final doc in documents) {
      if ((await DocumentStore.instance.doc(doc.path).get()).exists) {
        count++;
      }
    }
    return count;
  }

  Future<bool> _confirmImport(int documents, int duplicates) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Importer mes donnees')),
        content: Text(
          dialogContext
              .tr(
                'Le fichier contient {documents} documents. {duplicates} existent deja dans votre espace. Vous pourrez choisir quoi faire pour les doublons.',
              )
              .replaceAll('{documents}', documents.toString())
              .replaceAll('{duplicates}', duplicates.toString()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('Annuler')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('Continuer')),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<_ImportResult> _restoreDocuments(
    List<_ImportDocument> documents,
  ) async {
    var duplicateMode = _DuplicateDecision.ask;
    var created = 0;
    var replaced = 0;
    var skipped = 0;

    for (final importDoc in documents) {
      final ref = DocumentStore.instance.doc(importDoc.path);
      final exists = (await ref.get()).exists;
      var decision = _DuplicateDecision.replaceOne;

      if (exists) {
        decision = duplicateMode;
        if (decision == _DuplicateDecision.ask) {
          if (!mounted) break;
          decision = await _askDuplicateDecision(
            documentPath: importDoc.path,
            documentLabel: _importDocumentLabel(importDoc),
          );
          if (decision == _DuplicateDecision.cancel) break;
          if (decision == _DuplicateDecision.replaceAll ||
              decision == _DuplicateDecision.skipAll) {
            duplicateMode = decision;
          }
        }
      }

      if (exists &&
          (decision == _DuplicateDecision.skipOne ||
              decision == _DuplicateDecision.skipAll)) {
        skipped++;
        continue;
      }

      final isRoot = importDoc.path == _userRef?.path;
      await ref.set(
        importDoc.data,
        isRoot ? SetOptions(merge: true) : SetOptions(merge: !exists),
      );
      exists ? replaced++ : created++;
    }

    return _ImportResult(
      created: created,
      replaced: replaced,
      skipped: skipped,
    );
  }

  Future<_DuplicateDecision> _askDuplicateDecision({
    required String documentPath,
    required String documentLabel,
  }) async {
    final decision = await showDialog<_DuplicateDecision>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Doublon detecte')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                dialogContext
                    .tr('Cet element existe deja: {name}')
                    .replaceAll('{name}', documentLabel),
              ),
              const SizedBox(height: 8),
              Text(
                documentPath,
                style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    dialogContext,
                  ).colorScheme.onSurface.withOpacity(0.55),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, _DuplicateDecision.skipOne),
                child: Text(dialogContext.tr('Ne pas copier')),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, _DuplicateDecision.skipAll),
                child: Text(
                  dialogContext.tr('Ne pas copier tous les doublons'),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, _DuplicateDecision.replaceOne),
                child: Text(dialogContext.tr('Remplacer')),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, _DuplicateDecision.replaceAll),
                child: Text(dialogContext.tr('Tous remplacer les doublons')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _DuplicateDecision.cancel),
            child: Text(dialogContext.tr('Annuler')),
          ),
        ],
      ),
    );
    return decision ?? _DuplicateDecision.cancel;
  }

  String _importDocumentLabel(_ImportDocument doc) {
    final parts = doc.path.split('/');
    final collection = parts.length >= 3 ? parts[2] : 'document';
    final name =
        (doc.data['name'] ??
                doc.data['description'] ??
                doc.data['type'] ??
                parts.last)
            .toString();

    switch (collection) {
      case 'accounts':
        return "compte '$name'";
      case 'categories':
        return "categorie '$name'";
      case 'investments':
        return "investissement '$name'";
      case 'transactions':
        return "transaction '$name'";
      case 'budgetAlerts':
        return "alerte budgetaire '$name'";
      default:
        return "document '$name'";
    }
  }

  List<String> _exportHeader() {
    return [
      'rowType',
      'level',
      'collectionPath',
      'documentPath',
      'parentDocumentPath',
      'collectionId',
      'documentId',
      'fieldPath',
      'valueType',
      'value',
      'restoreHint',
    ];
  }

  String _relativeExportPath(String path, String userRootPath) {
    if (path == userRootPath) return 'user';
    if (path.startsWith('$userRootPath/')) {
      return path.substring(userRootPath.length + 1);
    }
    if (path == 'users') return 'user';
    return path;
  }

  List<String> _collectionRow({
    required String collectionPath,
    String parentDocumentPath = '',
  }) {
    final parts = collectionPath.split('/');
    final collectionId = parts.isEmpty ? collectionPath : parts.last;
    return [
      'collection',
      _collectionLevel(collectionPath).toString(),
      collectionPath,
      '',
      parentDocumentPath,
      collectionId,
      '',
      '',
      'collection',
      collectionPath,
      parentDocumentPath.isEmpty
          ? 'Collection racine.'
          : 'Sous-collection de $parentDocumentPath.',
    ];
  }

  void _appendDocumentRows(
    List<List<String>> lines,
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String parentDocumentPath,
    required String userRootPath,
  }) {
    final documentPath = _relativeExportPath(doc.reference.path, userRootPath);
    final collectionPath = _relativeExportPath(
      doc.reference.parent.path,
      userRootPath,
    );
    final collectionId = documentPath == 'user'
        ? 'user'
        : doc.reference.parent.id;
    final documentId = documentPath == 'user' ? 'user' : doc.id;
    final data = doc.data() ?? {};

    lines.add([
      'document',
      _documentLevel(documentPath).toString(),
      collectionPath,
      documentPath,
      parentDocumentPath,
      collectionId,
      documentId,
      '',
      'document',
      documentPath,
      'Creer le document puis appliquer les lignes field du meme documentPath.',
    ]);

    if (data.isEmpty) {
      lines.add([
        'field',
        _documentLevel(documentPath).toString(),
        collectionPath,
        documentPath,
        parentDocumentPath,
        collectionId,
        documentId,
        '',
        'emptyDocument',
        '',
        'Document vide a recreer tel quel.',
      ]);
      return;
    }

    final sortedEntries = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in sortedEntries) {
      _appendFieldRows(
        lines,
        collectionPath: collectionPath,
        documentPath: documentPath,
        parentDocumentPath: parentDocumentPath,
        collectionId: collectionId,
        documentId: documentId,
        fieldPath: entry.key,
        value: entry.value,
        userRootPath: userRootPath,
      );
    }
  }

  void _appendFieldRows(
    List<List<String>> lines, {
    required String collectionPath,
    required String documentPath,
    required String parentDocumentPath,
    required String collectionId,
    required String documentId,
    required String fieldPath,
    required dynamic value,
    required String userRootPath,
    String rowType = 'field',
  }) {
    final valueType = _valueType(value);
    lines.add([
      rowType,
      _documentLevel(documentPath).toString(),
      collectionPath,
      documentPath,
      parentDocumentPath,
      collectionId,
      documentId,
      fieldPath,
      valueType,
      _csvValue(value, userRootPath),
      rowType == 'fieldDetail'
          ? 'Detail lisible du champ parent. Ne pas restaurer si le champ parent map est restaure.'
          : _restoreHint(valueType),
    ]);

    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      for (final entry in entries) {
        _appendFieldRows(
          lines,
          collectionPath: collectionPath,
          documentPath: documentPath,
          parentDocumentPath: parentDocumentPath,
          collectionId: collectionId,
          documentId: documentId,
          fieldPath: '$fieldPath.${entry.key}',
          value: entry.value,
          userRootPath: userRootPath,
          rowType: 'fieldDetail',
        );
      }
    }
  }

  int _collectionLevel(String collectionPath) {
    return ((collectionPath.split('/').length + 1) / 2).floor();
  }

  int _documentLevel(String documentPath) {
    return (documentPath.split('/').length / 2).floor();
  }

  String _valueType(dynamic value) {
    if (value == null) return 'null';
    if (value is Timestamp || value is DateTime) return 'timestamp';
    if (value is GeoPoint) return 'geoPoint';
    if (value is DocumentReference) return 'documentReference';
    if (value is bool) return 'boolean';
    if (value is int) return 'integer';
    if (value is double) return 'double';
    if (value is num) return 'number';
    if (value is List) return 'array';
    if (value is Map) return 'map';
    return 'string';
  }

  String _restoreHint(String valueType) {
    switch (valueType) {
      case 'map':
        return 'Objet JSON complet. Les lignes enfants detaillees aident a relire la structure.';
      case 'array':
        return 'Tableau JSON a restaurer sur fieldPath.';
      case 'timestamp':
        return 'Convertir la date ISO-8601 en horodatage.';
      case 'geoPoint':
        return 'Convertir latitude,longitude en GeoPoint.';
      case 'documentReference':
        return 'Restaurer la référence au document si nécessaire.';
      case 'emptyDocument':
        return 'Creer un document vide.';
      default:
        return 'Restaurer value sur fieldPath dans documentPath.';
    }
  }

  String _csvValue(dynamic value, String userRootPath) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is GeoPoint) return '${value.latitude},${value.longitude}';
    if (value is DocumentReference) {
      return _relativeExportPath(value.path, userRootPath);
    }
    if (value is List || value is Map) {
      return jsonEncode(_jsonReady(value, userRootPath));
    }
    return (value ?? '').toString();
  }

  dynamic _jsonReady(dynamic value, String userRootPath) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is GeoPoint) {
      return {'latitude': value.latitude, 'longitude': value.longitude};
    }
    if (value is DocumentReference) {
      return _relativeExportPath(value.path, userRootPath);
    }
    if (value is List) {
      return value.map((item) => _jsonReady(item, userRootPath)).toList();
    }
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _jsonReady(entry.value, userRootPath),
      };
    }
    return value;
  }

  String _csvLine(List<String> cells) {
    return cells
        .map((cell) {
          final escaped = cell.replaceAll('"', '""');
          return '"$escaped"';
        })
        .join(',');
  }

  void _showTextPage({required String title, required String body}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LegalTextPage(title: title, body: body),
      ),
    );
  }

  Future<void> _deleteCollection(
    DocumentReference<Map<String, dynamic>> ref,
    String collection,
  ) async {
    while (true) {
      final snapshot = await ref.collection(collection).limit(400).get();
      if (snapshot.docs.isEmpty) return;

      final batch = DocumentStore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<String?> _askDeletionPassword() {
    final passwordCtrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(dialogContext.tr('Verification du compte')),
          content: TextField(
            controller: passwordCtrl,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(
              labelText: dialogContext.tr('Mot de passe'),
              prefixIcon: const Icon(Icons.lock_outline),
            ),
            onSubmitted: (_) {
              Navigator.pop(dialogContext, passwordCtrl.text);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.tr('Annuler')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, passwordCtrl.text),
              child: Text(dialogContext.tr('Confirmer')),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _showDeleteConfirmationDialog() {
    final confirmCtrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final confirmation = confirmCtrl.text.trim().toUpperCase();
            final canDelete =
                confirmation == 'SUPPRIMER' || confirmation == 'DELETE';
            return AlertDialog(
              title: Text(
                dialogContext.tr('Supprimer definitivement le compte ?'),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dialogContext.tr(
                        'Cette action est irreversible. Toutes vos donnees seront supprimees sans retour en arriere possible.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      dialogContext.tr(
                        'Nous vous conseillons fortement d exporter vos donnees avant de continuer.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmCtrl,
                      decoration: InputDecoration(
                        labelText: dialogContext.tr('Tapez SUPPRIMER'),
                        prefixIcon: const Icon(Icons.warning_amber_outlined),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(dialogContext.tr('Annuler')),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, 'export'),
                  icon: const Icon(Icons.file_download_outlined),
                  label: Text(dialogContext.tr('Exporter avant')),
                ),
                FilledButton.icon(
                  onPressed: canDelete
                      ? () => Navigator.pop(dialogContext, 'delete')
                      : null,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: Text(dialogContext.tr('Supprimer')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteAccountAndData() async {
    final action = await _showDeleteConfirmationDialog();
    if (!mounted || action == null) return;

    if (action == 'export') {
      await _exportUserData();
      return;
    }

    final authorized = await SecurityGate.requestPin(
      context,
      title: context.tr('Supprimer mon compte et mes donnees'),
      message: context.tr(
        'Confirmez votre PIN avant la suppression definitive.',
      ),
    );
    if (!authorized || !mounted) return;

    final ref = _userRef;
    final user = LocalAuth.instance.currentUser;
    if (ref == null || user == null) return;

    String? password;
    final hasPasswordProvider = user.providerData.any(
      (provider) => provider.providerId == 'password',
    );
    if (hasPasswordProvider) {
      password = await _askDeletionPassword();
      if (!mounted || password == null || password.trim().isEmpty) return;
    }

    setState(() => _isDeleting = true);
    try {
      final authService = context.read<AuthService>();
      final reauthenticated = await authService
          .reauthenticateForAccountDeletion(password: password);
      if (!reauthenticated) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'Verification impossible. Reconnectez-vous puis reessayez.',
              ),
            ),
          ),
        );
        return;
      }

      // The server deletes the account, documents and sessions atomically.
      final deletedAuth = await authService.deleteCurrentAuthUser();
      if (!deletedAuth) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'Les donnees ont ete supprimees, mais le compte doit etre supprime apres reconnexion.',
              ),
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      context.read<UserDataProvider>().setUser(null);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('Suppression impossible')} : $e')),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: appPageBar(
          context,
          title: Text(context.tr('Securite et confidentialite')),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: appPageBar(
        context,
        title: Text(context.tr('Securite et confidentialite')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _Panel(
            icon: Icons.lock_outline,
            title: context.tr('Securite de l application'),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _frequency,
                  decoration: InputDecoration(
                    labelText: context.tr('Demande du PIN'),
                    prefixIcon: const Icon(Icons.lock_clock_outlined),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'never',
                      child: Text(context.tr('Jamais')),
                    ),
                    DropdownMenuItem(
                      value: 'always',
                      child: Text(context.tr('Toujours')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _frequency = value);
                  },
                ),
                if (_frequency == 'always') ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: _lockDelayMinutes,
                    decoration: InputDecoration(
                      labelText: context.tr('Delai avant verrouillage'),
                      prefixIcon: const Icon(Icons.timer_outlined),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 0,
                        child: Text(context.tr('Immediat')),
                      ),
                      DropdownMenuItem(
                        value: 1,
                        child: Text(context.tr('Apres 1 minute')),
                      ),
                      DropdownMenuItem(
                        value: 5,
                        child: Text(context.tr('Apres 5 minutes')),
                      ),
                      DropdownMenuItem(
                        value: 15,
                        child: Text(context.tr('Apres 15 minutes')),
                      ),
                      DropdownMenuItem(
                        value: 60,
                        child: Text(context.tr('Apres 1 heure')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _lockDelayMinutes = value);
                      }
                    },
                  ),
                ],
                const SizedBox(height: 14),
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: context
                        .watch<PrivacyProvider>()
                        .persistentHideAmounts,
                    onChanged: (value) async {
                      await context.read<PrivacyProvider>().setHideAmounts(
                        value,
                      );
                      if (mounted) setState(() {});
                    },
                    title: Text(context.tr('Masquer les montants')),
                    subtitle: Text(
                      context.tr(
                        'Remplace les montants visibles par des symboles',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _pinCtrl,
                  maxLength: 6,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.tr('Nouveau PIN'),
                    prefixIcon: const Icon(Icons.pin_outlined),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _confirmPinCtrl,
                  maxLength: 6,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.tr('Confirmer le PIN'),
                    prefixIcon: const Icon(Icons.verified_user_outlined),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveSecurity,
                  icon: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(context.tr('Enregistrer')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Panel(
            icon: Icons.policy_outlined,
            title: context.tr('Documents legaux'),
            child: Column(
              children: [
                _ActionRow(
                  icon: Icons.description_outlined,
                  title: context.tr('Conditions generales d utilisation'),
                  subtitle: context.tr(
                    'Consulter les regles d utilisation de MySold',
                  ),
                  onTap: () => _showTextPage(
                    title: context.tr('Conditions generales d utilisation'),
                    body: _termsText(context),
                  ),
                ),
                const Divider(height: 1),
                _ActionRow(
                  icon: Icons.privacy_tip_outlined,
                  title: context.tr('Politique de confidentialite'),
                  subtitle: context.tr(
                    'Comprendre comment vos donnees sont utilisees',
                  ),
                  onTap: () => _showTextPage(
                    title: context.tr('Politique de confidentialite'),
                    body: _privacyText(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Panel(
            icon: Icons.manage_accounts_outlined,
            title: context.tr('Mes donnees'),
            child: Column(
              children: [
                _ActionRow(
                  icon: Icons.file_download_outlined,
                  title: context.tr('Exporter mes donnees'),
                  subtitle: context.tr(
                    'Telecharger les donnees de votre espace en CSV',
                  ),
                  loading: _isExporting,
                  onTap: _isExporting ? null : _exportUserData,
                ),
                const Divider(height: 1),
                _ActionRow(
                  icon: Icons.upload_file_outlined,
                  title: context.tr('Importer mes donnees'),
                  subtitle: context.tr('Restaurer un export CSV MySold'),
                  loading: _isImporting,
                  onTap: _isImporting ? null : _importUserData,
                ),
                const Divider(height: 1),
                _ActionRow(
                  icon: Icons.delete_forever_outlined,
                  title: context.tr('Supprimer mon compte et mes donnees'),
                  subtitle: context.tr('Action irreversible avec confirmation'),
                  destructive: true,
                  loading: _isDeleting,
                  onTap: _isDeleting ? null : _deleteAccountAndData,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _termsText(BuildContext context) {
    return context.tr('legal_terms_full');
  }

  String _privacyText(BuildContext context) {
    return context.tr('privacy_policy_full');
  }
}

class _Panel extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _Panel({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;
  final bool loading;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = destructive ? Colors.redAccent : colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: destructive ? Colors.redAccent : null,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _LegalTextPage extends StatelessWidget {
  final String title;
  final String body;

  const _LegalTextPage({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appPageBar(context, title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Text(
            body,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ImportProgressPage extends StatefulWidget {
  final String uid;

  const _ImportProgressPage({required this.uid});

  @override
  State<_ImportProgressPage> createState() => _ImportProgressPageState();
}

class _ImportProgressPageState extends State<_ImportProgressPage> {
  double _progress = 0.04;
  String _message = 'Selectionnez un fichier CSV MySold.';
  final List<String> _logs = [];
  _ImportResult? _result;
  Object? _error;
  bool _started = false;
  bool _isPicking = false;

  static const _collections = [
    'accounts',
    'categories',
    'investments',
    'transactions',
    'budgetAlerts',
  ];

  static const _protectedRootImportFields = {
    'pin',
    'email',
    'authProvider',
    'createdAt',
    'lastConnection',
  };

  static const _allowedRootImportFields = {
    'firstName',
    'lastName',
    'phone',
    'theme',
    'currency',
    'currencyCode',
    'language',
    'languageCode',
    'reconnectionFrequency',
    'lockDelayMinutes',
    'updatedAt',
  };

  void _step(double progress, String message, {String? log}) {
    if (!mounted) return;
    setState(() {
      _progress = progress.clamp(0.0, 1.0).toDouble();
      _message = message;
      if (log != null) {
        _logs.insert(0, log);
        if (_logs.length > 80) _logs.removeLast();
      }
    });
  }

  Future<void> _pause() {
    return Future<void>.delayed(const Duration(milliseconds: 16));
  }

  Future<void> _pickAndRunImport() async {
    if (_isPicking || _started) return;

    setState(() {
      _isPicking = true;
      _message = context.tr('Ouverture du selecteur de fichier...');
      _logs.insert(0, context.tr('Ouverture du selecteur de fichier...'));
    });

    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
        cancelUploadOnWindowBlur: false,
      );
      if (!mounted) return;

      if (picked == null || picked.files.isEmpty) {
        setState(() {
          _isPicking = false;
          _message = context.tr('Aucun fichier selectionne.');
          _logs.insert(0, context.tr('Aucun fichier selectionne.'));
        });
        return;
      }

      setState(() {
        _started = true;
        _isPicking = false;
      });
      await _runImport(picked.files.single);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPicking = false;
        _error = e;
        _message = context.tr('Import impossible');
      });
    }
  }

  Future<void> _runImport(PlatformFile selectedFile) async {
    try {
      _step(0.08, context.tr('Lecture du fichier CSV...'));
      await _pause();
      final bytes = await _readSelectedFileBytes(selectedFile);
      if (bytes.isEmpty) {
        throw Exception(context.tr('Fichier CSV illisible.'));
      }
      final csv = utf8.decode(bytes, allowMalformed: true);
      await _runImportFromCsv(csv);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _message = context.tr('Import impossible');
      });
    }
  }

  Future<void> _runImportFromCsv(String csv) async {
    try {
      final rows = _parseCsv(csv);
      _step(0.18, context.tr('Analyse de la structure des données...'));
      await _pause();
      final documents = _buildImportDocuments(rows);
      if (documents.isEmpty) {
        throw Exception(context.tr('Aucune donnee compatible a importer.'));
      }

      _step(0.30, context.tr('Recherche des doublons...'));
      final duplicates = await _countDuplicateDocuments(documents);
      if (!mounted) return;
      final confirmed = await _confirmImport(documents.length, duplicates);
      if (!confirmed) {
        _step(
          1,
          context.tr('Import annule.'),
          log: context.tr('Import annule.'),
        );
        return;
      }

      _step(0.42, context.tr('Import des documents...'));
      final result = await _restoreDocuments(documents);
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _result = result;
        _message = context.tr('Import termine.');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _message = context.tr('Import impossible');
      });
    }
  }

  Future<Uint8List> _readSelectedFileBytes(PlatformFile selectedFile) async {
    final directBytes = selectedFile.bytes;
    if (directBytes != null && directBytes.isNotEmpty) {
      _step(
        0.10,
        context.tr('Lecture du fichier CSV...'),
        log: context
            .tr('Fichier charge: {name}')
            .replaceAll('{name}', selectedFile.name),
      );
      return directBytes;
    }

    _step(
      0.11,
      context.tr('Lecture du fichier CSV...'),
      log: context.tr('Lecture via le chemin du fichier...'),
    );
    final fallbackBytes = await selectedFile.xFile.readAsBytes();
    if (fallbackBytes.isNotEmpty) {
      _step(
        0.12,
        context.tr('Lecture du fichier CSV...'),
        log: context
            .tr('Fichier charge: {name}')
            .replaceAll('{name}', selectedFile.name),
      );
    }
    return fallbackBytes;
  }

  List<List<String>> _parseCsv(String source) {
    final cleanSource = source.startsWith('\ufeff')
        ? source.substring(1)
        : source;
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < cleanSource.length; i++) {
      final char = cleanSource[i];
      final next = i + 1 < cleanSource.length ? cleanSource[i + 1] : '';

      if (char == '"') {
        if (inQuotes && next == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }

      if (!inQuotes && char == ',') {
        row.add(cell.toString());
        cell.clear();
        continue;
      }

      if (!inQuotes && (char == '\n' || char == '\r')) {
        if (char == '\r' && next == '\n') i++;
        row.add(cell.toString());
        cell.clear();
        if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
        row = <String>[];
        continue;
      }

      cell.write(char);
    }

    row.add(cell.toString());
    if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
    return rows;
  }

  List<_ImportDocument> _buildImportDocuments(List<List<String>> rows) {
    if (rows.length < 2) return [];

    final header = rows.first
        .map((cell) => cell.replaceFirst('\ufeff', '').trim())
        .toList();
    final index = <String, int>{
      for (var i = 0; i < header.length; i++) header[i]: i,
    };

    for (final requiredColumn in [
      'rowType',
      'documentPath',
      'fieldPath',
      'valueType',
      'value',
    ]) {
      if (!index.containsKey(requiredColumn)) {
        throw Exception('Colonne manquante: $requiredColumn');
      }
    }

    final targetRoot = 'users/${widget.uid}';
    final documents = <String, _ImportDocument>{};

    for (final row in rows.skip(1)) {
      final rowType = _cell(row, index, 'rowType');
      if (rowType != 'document' && rowType != 'field') continue;

      final rawPath = _cell(row, index, 'documentPath');
      if (rawPath.isEmpty) continue;
      final documentPath = _remapImportPath(rawPath, targetRoot);
      if (!_isSafeImportPath(documentPath, targetRoot)) {
        throw Exception('Chemin non autorise: $documentPath');
      }

      final doc = documents.putIfAbsent(
        documentPath,
        () => _ImportDocument(path: documentPath),
      );

      if (rowType != 'field') continue;
      final fieldPath = _cell(row, index, 'fieldPath');
      final valueType = _cell(row, index, 'valueType');
      if (valueType == 'emptyDocument' || fieldPath.isEmpty) continue;
      if (documentPath == targetRoot &&
          (!_allowedRootImportFields.contains(fieldPath) ||
              _protectedRootImportFields.contains(fieldPath))) {
        continue;
      }

      doc.data[fieldPath] = _restoreValue(
        valueType: valueType,
        value: _cell(row, index, 'value'),
        targetRoot: targetRoot,
      );
    }

    final result = documents.values.toList()..sort(_compareImportDocuments);
    return result;
  }

  String _cell(List<String> row, Map<String, int> index, String column) {
    final cellIndex = index[column];
    if (cellIndex == null || cellIndex >= row.length) return '';
    return row[cellIndex].trim();
  }

  String _remapImportPath(String path, String targetRoot) {
    final cleanPath = path.trim().replaceAll('\\', '/');
    if (cleanPath.isEmpty || cleanPath == 'user' || cleanPath == '.') {
      return targetRoot;
    }
    final parts = cleanPath.split('/');
    if (parts.length >= 2 && parts.first == 'users') {
      final suffix = parts.skip(2).join('/');
      return suffix.isEmpty ? targetRoot : '$targetRoot/$suffix';
    }
    if (_collections.contains(parts.first)) {
      return '$targetRoot/$cleanPath';
    }
    return cleanPath;
  }

  bool _isSafeImportPath(String path, String targetRoot) {
    final parts = path.split('/');
    if (parts.length.isOdd) return false;
    if (path == targetRoot) return true;
    if (!path.startsWith('$targetRoot/')) return false;
    if (parts.length != 4) return false;
    return _collections.contains(parts[2]);
  }

  dynamic _restoreValue({
    required String valueType,
    required String value,
    required String targetRoot,
  }) {
    switch (valueType) {
      case 'null':
        return null;
      case 'boolean':
        return value.toLowerCase() == 'true';
      case 'integer':
        return int.tryParse(value) ?? 0;
      case 'double':
      case 'number':
        return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
      case 'timestamp':
        return Timestamp.fromDate(DateTime.parse(value));
      case 'geoPoint':
        final jsonValue = _tryJsonDecode(value);
        if (jsonValue is Map) {
          return GeoPoint(
            (jsonValue['latitude'] as num).toDouble(),
            (jsonValue['longitude'] as num).toDouble(),
          );
        }
        final parts = value.split(',');
        return GeoPoint(
          double.tryParse(parts.first.trim()) ?? 0,
          double.tryParse(parts.length > 1 ? parts[1].trim() : '0') ?? 0,
        );
      case 'documentReference':
        final referencePath = _remapImportPath(value, targetRoot);
        if (!_isSafeImportPath(referencePath, targetRoot)) {
          throw Exception('Reference non autorisee: $referencePath');
        }
        return DocumentStore.instance.doc(referencePath);
      case 'array':
      case 'map':
        return _tryJsonDecode(value);
      default:
        return value;
    }
  }

  dynamic _tryJsonDecode(String value) {
    if (value.isEmpty) return value;
    try {
      return jsonDecode(value);
    } catch (_) {
      return value;
    }
  }

  Future<int> _countDuplicateDocuments(List<_ImportDocument> documents) async {
    var count = 0;
    final targetRoot = 'users/${widget.uid}';
    for (var i = 0; i < documents.length; i++) {
      final doc = documents[i];
      _step(
        0.30 + (0.10 * ((i + 1) / documents.length)),
        context.tr('Recherche des doublons...'),
        log: context
            .tr('Verification de {path}')
            .replaceAll('{path}', doc.path),
      );
      if (doc.path != targetRoot &&
          (await DocumentStore.instance.doc(doc.path).get()).exists) {
        count++;
      }
      await _pause();
    }
    return count;
  }

  Future<bool> _confirmImport(int documents, int duplicates) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Importer mes donnees')),
        content: Text(
          dialogContext
              .tr(
                'Le fichier contient {documents} documents. {duplicates} existent deja dans votre espace. Vous pourrez choisir quoi faire pour les doublons.',
              )
              .replaceAll('{documents}', documents.toString())
              .replaceAll('{duplicates}', duplicates.toString()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('Annuler')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('Continuer')),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<_ImportResult> _restoreDocuments(
    List<_ImportDocument> documents,
  ) async {
    var duplicateMode = _DuplicateDecision.ask;
    var created = 0;
    var replaced = 0;
    var skipped = 0;
    final targetRoot = 'users/${widget.uid}';

    for (var i = 0; i < documents.length; i++) {
      final importDoc = documents[i];
      final ref = DocumentStore.instance.doc(importDoc.path);
      final exists = (await ref.get()).exists;
      var decision = _DuplicateDecision.replaceOne;
      final label = _documentLabel(importDoc);
      final action = exists ? 'Mise a jour' : 'Creation';

      _step(
        0.42 + (0.52 * ((i + 1) / documents.length)),
        '$action de $label...',
        log: '$action de $label',
      );

      if (exists && importDoc.path != targetRoot) {
        decision = duplicateMode;
        if (decision == _DuplicateDecision.ask) {
          if (!mounted) break;
          decision = await _askDuplicateDecision(
            documentPath: importDoc.path,
            documentLabel: label,
          );
          if (decision == _DuplicateDecision.cancel) break;
          if (decision == _DuplicateDecision.replaceAll ||
              decision == _DuplicateDecision.skipAll) {
            duplicateMode = decision;
          }
        }
      }

      if (exists &&
          (decision == _DuplicateDecision.skipOne ||
              decision == _DuplicateDecision.skipAll)) {
        skipped++;
        await _pause();
        continue;
      }

      final isRoot = importDoc.path == targetRoot;
      await ref.set(
        importDoc.data,
        isRoot ? SetOptions(merge: true) : SetOptions(merge: !exists),
      );
      exists ? replaced++ : created++;
      await _pause();
    }

    return _ImportResult(
      created: created,
      replaced: replaced,
      skipped: skipped,
    );
  }

  String _documentLabel(_ImportDocument doc) {
    final parts = doc.path.split('/');
    final collection = parts.length >= 3 ? parts[2] : 'document';
    final name =
        (doc.data['name'] ??
                doc.data['description'] ??
                doc.data['type'] ??
                parts.last)
            .toString();
    switch (collection) {
      case 'accounts':
        return "du compte '$name'";
      case 'categories':
        return "de la categorie '$name'";
      case 'investments':
        return "de l investissement '$name'";
      case 'transactions':
        return "de la transaction '$name'";
      case 'budgetAlerts':
        return "de l alerte budgetaire '$name'";
      default:
        return "du document '$name'";
    }
  }

  Future<_DuplicateDecision> _askDuplicateDecision({
    required String documentPath,
    required String documentLabel,
  }) async {
    final decision = await showDialog<_DuplicateDecision>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Doublon detecte')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                dialogContext
                    .tr('Cet element existe deja: {name}')
                    .replaceAll('{name}', documentLabel),
              ),
              const SizedBox(height: 8),
              Text(
                documentPath,
                style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    dialogContext,
                  ).colorScheme.onSurface.withOpacity(0.55),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, _DuplicateDecision.skipOne),
                child: Text(dialogContext.tr('Ne pas copier')),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, _DuplicateDecision.skipAll),
                child: Text(
                  dialogContext.tr('Ne pas copier tous les doublons'),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, _DuplicateDecision.replaceOne),
                child: Text(dialogContext.tr('Remplacer')),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, _DuplicateDecision.replaceAll),
                child: Text(dialogContext.tr('Tous remplacer les doublons')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _DuplicateDecision.cancel),
            child: Text(dialogContext.tr('Annuler')),
          ),
        ],
      ),
    );
    return decision ?? _DuplicateDecision.cancel;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final done = _result != null || _error != null;
    final canClose = done || !_started;

    return PopScope(
      canPop: canClose,
      child: Scaffold(
        appBar: appPageBar(
          context,
          title: Text(context.tr('Import des donnees')),
        ),
        body: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.outline.withOpacity(0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _error == null
                              ? Icons.upload_file_outlined
                              : Icons.error_outline,
                          color: _error == null ? colors.primary : Colors.red,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _message,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: _error == null ? _progress : null,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _error == null
                          ? '${(_progress * 100).clamp(0, 100).toStringAsFixed(0)} %'
                          : _error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_result != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        context
                            .tr(
                              'Import termine: {created} crees, {replaced} remplaces, {skipped} ignores.',
                            )
                            .replaceAll(
                              '{created}',
                              _result!.created.toString(),
                            )
                            .replaceAll(
                              '{replaced}',
                              _result!.replaced.toString(),
                            )
                            .replaceAll(
                              '{skipped}',
                              _result!.skipped.toString(),
                            ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.outline.withValues(alpha: 0.30),
                    ),
                  ),
                  child: _logs.isEmpty
                      ? Center(
                          child: Text(context.tr('En attente des taches...')),
                        )
                      : ListView.separated(
                          itemCount: _logs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(log)),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 14),
              if (!_started && _error == null)
                FilledButton.icon(
                  onPressed: _isPicking ? null : _pickAndRunImport,
                  icon: _isPicking
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined),
                  label: Text(context.tr('Choisir le fichier CSV')),
                )
              else
                FilledButton.icon(
                  onPressed: done ? () => Navigator.pop(context) : null,
                  icon: const Icon(Icons.check),
                  label: Text(context.tr('Fermer')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportDocument {
  final String path;
  final Map<String, dynamic> data = {};

  _ImportDocument({required this.path});
}

class _ImportResult {
  final int created;
  final int replaced;
  final int skipped;

  const _ImportResult({
    required this.created,
    required this.replaced,
    required this.skipped,
  });
}

enum _DuplicateDecision {
  ask,
  skipOne,
  replaceOne,
  skipAll,
  replaceAll,
  cancel,
}
