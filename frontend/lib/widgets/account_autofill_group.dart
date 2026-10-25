import 'package:flutter/material.dart';

/// Keep the account identifier in the same native form as a confirmation secret.
/// The identifier stays in the autofill and accessibility forms without a
/// visible or tabbable field. Cancelling the scope prevents PIN confirmations from being saved as
/// account credentials when the dialog or settings page closes.
class AccountAutofillGroup extends StatefulWidget {
  final String username;
  final Widget child;
  const AccountAutofillGroup({
    super.key,
    required this.username,
    required this.child,
  });

  // A non-null HTML autocomplete hint keeps Flutter's native form enabled,
  // while "off" declines credential autofill for the local PIN (Web app only).
  static const pinHints = <String>['off'];

  @override
  State<AccountAutofillGroup> createState() => _AccountAutofillGroupState();
}

class _AccountAutofillGroupState extends State<AccountAutofillGroup> {
  late final _username = TextEditingController(text: widget.username);

  @override
  void didUpdateWidget(covariant AccountAutofillGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.username != widget.username) _username.text = widget.username;
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AutofillGroup(
    onDisposeAction: AutofillContextAction.cancel,
    child: Form(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AutofillIdentifier(controller: _username),
          widget.child,
        ],
      ),
    ),
  );
}

/// A one-pixel, transparent identifier is kept in the semantics form as well as
/// Flutter's autofill scope. Offstage would remove it from the accessibility DOM
/// and recreate the password-only form when assistive technology is enabled.
class AutofillIdentifier extends StatefulWidget {
  final TextEditingController controller;
  const AutofillIdentifier({super.key, required this.controller});

  @override
  State<AutofillIdentifier> createState() => _AutofillIdentifierState();
}

class _AutofillIdentifierState extends State<AutofillIdentifier> {
  final _focus = FocusNode(canRequestFocus: false, skipTraversal: true);

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1,
    child: Opacity(
      opacity: 0,
      alwaysIncludeSemantics: true,
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        canRequestFocus: false,
        readOnly: true,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.username],
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(fontSize: 1, height: 1),
        decoration: const InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: 'Identifiant du compte',
        ),
      ),
    ),
  );
}
