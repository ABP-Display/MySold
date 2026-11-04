import 'package:flutter/material.dart';
import 'credential_autofill_stub.dart'
    if (dart.library.js_interop) 'credential_autofill_web.dart'
    as platform;

int _nextCredentialId = 0;

/// Supplement native AutofillGroup inputs when browser accessibility is active.
/// Do not force semantics for autofill: the web engine retains that activation
/// and buffers touch gestures starting on semantic buttons for up to 200 ms.
class CredentialAutofillScope extends StatefulWidget {
  final Widget child;
  const CredentialAutofillScope({super.key, required this.child});

  /// Some managers set DOM values without sending input/change. Read them at
  /// explicit form submission as well, before Flutter validates the form.
  static void sync() => platform.syncCredentials();

  @override
  State<CredentialAutofillScope> createState() =>
      _CredentialAutofillScopeState();
}

class _CredentialAutofillScopeState extends State<CredentialAutofillScope> {
  final _id = 'mysold-form-${_nextCredentialId++}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.of(context);
    platform.setCredentialScope(_id, active);
  }

  @override
  void dispose() {
    platform.setCredentialScope(_id, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _CredentialScopeId(id: _id, child: widget.child);
}

class _CredentialScopeId extends InheritedWidget {
  final String id;
  const _CredentialScopeId({required this.id, required super.child});
  @override
  bool updateShouldNotify(_CredentialScopeId oldWidget) => id != oldWidget.id;
}

/// Keep Flutter's layout, validation, keyboard and accessibility while mapping
/// browser input/change events to the controller even when the field is unfocused.
class CredentialAutofillField extends StatefulWidget {
  final TextEditingController controller;
  final String name, autocomplete;
  final bool obscure;
  final Widget child;
  const CredentialAutofillField({
    super.key,
    required this.controller,
    required this.name,
    required this.autocomplete,
    this.obscure = false,
    required this.child,
  });

  @override
  State<CredentialAutofillField> createState() =>
      _CredentialAutofillFieldState();
}

class _CredentialAutofillFieldState extends State<CredentialAutofillField> {
  final _id = 'mysold-credential-${_nextCredentialId++}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register();
  }

  @override
  void didUpdateWidget(CredentialAutofillField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _register();
  }

  void _register() {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_CredentialScopeId>();
    assert(scope != null, 'Credentials need a CredentialAutofillScope.');
    platform.registerCredential(
      _id,
      scope?.id ?? '',
      widget.controller,
      widget.name,
      widget.autocomplete,
      // Flutter uses selection APIs unsupported by HTML type=email. Keep its
      // normal text input; username + the existing email inputmode identify it.
      widget.obscure ? 'password' : 'text',
    );
  }

  @override
  void dispose() {
    platform.unregisterCredential(_id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Semantics(container: true, identifier: _id, child: widget.child);
}
