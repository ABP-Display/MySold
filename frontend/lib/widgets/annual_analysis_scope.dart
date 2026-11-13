import 'package:flutter/material.dart';
import 'package:mysold/data/document_store.dart';
import 'package:mysold/services/annual_analysis_service.dart';

class AnnualAnalysisScope extends StatefulWidget {
  final Widget Function(BuildContext, Map<String, Map<String, dynamic>>)
  builder;
  const AnnualAnalysisScope({super.key, required this.builder});

  @override
  State<AnnualAnalysisScope> createState() => _AnnualAnalysisScopeState();
}

class _AnnualAnalysisScopeState extends State<AnnualAnalysisScope> {
  Object? _version;
  late Future<Map<String, dynamic>> _summary;
  bool _failed = false;
  DateTime _retryAfter = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void didUpdateWidget(covariant AnnualAnalysisScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Theme animation frames must not repeatedly retry an unavailable server.
    if (_failed && DateTime.now().isAfter(_retryAfter)) _version = null;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final version = (
      DocumentStore.instance.generation,
      now.year,
      now.month,
      now.day,
    );
    if (_version != version) {
      _version = version;
      _retryAfter = DateTime.now().add(const Duration(seconds: 5));
      _summary = readAnnualAnalysis(now.year);
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: _summary,
      // Keep the existing list usable while its small summary loads or retries.
      builder: (context, snapshot) {
        _failed = snapshot.hasError;
        return widget.builder(
          context,
          snapshot.connectionState == ConnectionState.done && !snapshot.hasError
              ? annualEntities(snapshot.data)
              : const {},
        );
      },
    );
  }
}
