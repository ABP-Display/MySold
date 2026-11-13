import 'package:mysold/data/document_store.dart';

/// One cached summary shared by all three management lists and their details.
Future<Map<String, dynamic>> readAnnualAnalysis(int year) =>
    DocumentStore.instance.read('analysis/annual', {
      'year': year,
      'day': DateTime.now().toUtc().toIso8601String().substring(0, 10),
    });

Map<String, Map<String, dynamic>> annualEntities(Map<String, dynamic>? data) =>
    {
      for (final entity in data?['entities'] as List? ?? const [])
        (entity['path'] as String): Map<String, dynamic>.from(entity as Map),
    };
