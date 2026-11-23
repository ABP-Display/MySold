import 'package:flutter/material.dart';
import 'package:mysold/data/api_client.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/widgets/app_design.dart';

enum LegalDocument {
  terms('Conditions générales d’utilisation', ['terms'], 'legal_terms_full'),
  privacy('Politique de confidentialité', ['privacy'], 'privacy_policy_full'),
  notices('Mentions légales et cookies', ['legal', 'cookies']),
  cookies('Cookies et stockage local', ['cookies']);

  const LegalDocument(this.title, this.paths, [this.fallback]);
  final String title;
  final List<String> paths;
  final String? fallback;

  void open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => LegalDocumentPage(document: this)));
}

class LegalDocumentPage extends StatefulWidget {
  const LegalDocumentPage({super.key, required this.document});
  final LegalDocument document;

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  late var _paragraphs = _load();

  Future<List<(String, bool)>> _load() async {
    final result = <(String, bool)>[];
    for (final path in widget.document.paths) {
      if (path == 'cookies' && result.isNotEmpty) {
        result.add(('Cookies et stockage local', true));
      }
      final doc = await ApiClient.instance.request('legal/$path');
      for (final item in doc['paragraphs'] as List) {
        result.add((item['text'] as String, item['heading'] == true));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appPageBar(context, title: Text(context.tr(widget.document.title))),
    body: FutureBuilder(
      future: _paragraphs,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final fallback = widget.document.fallback;
        final paragraphs =
            snapshot.data ??
            (fallback == null ? null : [(context.tr(fallback), false)]);
        if (paragraphs == null) {
          return Center(
            child: FilledButton(
              onPressed: () => setState(() => _paragraphs = _load()),
              child: Text(context.tr('Réessayer')),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: SelectionArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (text, heading) in paragraphs)
                        Padding(
                          padding: EdgeInsets.only(
                            top: heading ? 12 : 0,
                            bottom: 12,
                          ),
                          child: Text(
                            text,
                            style: heading
                                ? Theme.of(context).textTheme.titleLarge
                                : Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.copyWith(height: 1.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
