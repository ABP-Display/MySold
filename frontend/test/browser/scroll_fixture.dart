// Browser-only regression fixture. No API, credentials or user data.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:mysold/widgets/credential_autofill.dart';
import 'package:mysold/widgets/lazy_section_list.dart';
import 'package:mysold/widgets/web_scroll_scope.dart';
import 'package:web/web.dart' as web;

void main() => runApp(const MaterialApp(home: _Fixture()));

class _Fixture extends StatefulWidget {
  const _Fixture();
  @override
  State<_Fixture> createState() => _FixtureState();
}

class _FixtureState extends State<_Fixture> {
  bool _form = true;
  int _clicks = 0;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailKey = GlobalKey();
  final _continueKey = GlobalKey();
  @override
  Widget build(BuildContext context) => WebScrollScope(
    child: Scaffold(
      body: _form
          ? CredentialAutofillScope(
              child: Center(
                child: AutofillGroup(
                  child: Form(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CredentialAutofillField(
                          controller: _email,
                          name: 'username',
                          autocomplete: 'username',
                          child: TextField(
                            key: _emailKey,
                            controller: _email,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                          ),
                        ),
                        CredentialAutofillField(
                          controller: _password,
                          name: 'password',
                          autocomplete: 'current-password',
                          obscure: true,
                          child: TextField(
                            controller: _password,
                            obscureText: true,
                            autofillHints: const [AutofillHints.password],
                            decoration: const InputDecoration(
                              labelText: 'Password',
                            ),
                          ),
                        ),
                        FilledButton(
                          key: _continueKey,
                          onPressed: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            setState(() => _form = false);
                          },
                          child: const Text('Continue'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : NotificationListener<ScrollNotification>(
              onNotification: (event) {
                web.document.body!.setAttribute(
                  'data-scroll-offset',
                  event.metrics.pixels.toString(),
                );
                web.document.body!.setAttribute(
                  'data-scroll-time',
                  web.window.performance.now().toString(),
                );
                return false;
              },
              child: LazySectionList(
                padding: EdgeInsets.zero,
                sections: [
                  (_) => SizedBox(
                    height: 280,
                    child: Center(
                      child: FilledButton(
                        onPressed: () {
                          _clicks++;
                          web.document.body!.setAttribute(
                            'data-clicks',
                            '$_clicks',
                          );
                        },
                        child: const Text('Action'),
                      ),
                    ),
                  ),
                  (_) => const SizedBox(height: 1800),
                ],
                gaps: const [0],
              ),
            ),
    ),
  );

  @override
  void initState() {
    super.initState();
    // Keep an explicit comparison mode for the engine's semantics path.
    if (Uri.base.queryParameters['semantics'] == 'forced') {
      _forced = SemanticsBinding.instance.ensureSemantics();
    }
    Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      for (final entry in {
        'email': _emailKey,
        'continue': _continueKey,
      }.entries) {
        final box = entry.value.currentContext!.findRenderObject() as RenderBox;
        final center = box.localToGlobal(box.size.center(Offset.zero));
        web.document.body!.setAttribute('data-${entry.key}-x', '${center.dx}');
        web.document.body!.setAttribute('data-${entry.key}-y', '${center.dy}');
      }
      web.document.body!.setAttribute('data-fixture-ready', 'true');
    });
    _email.addListener(_checkAutofill);
    _password.addListener(_checkAutofill);
  }

  void _checkAutofill() => web.document.body!.setAttribute(
    'data-native-filled',
    '${_email.text == 'fixture@example.test' && _password.text == 'Fixture-only-123!'}',
  );

  SemanticsHandle? _forced;
  @override
  void dispose() {
    _forced?.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }
}
