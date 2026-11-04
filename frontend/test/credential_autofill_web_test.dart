import 'dart:js_interop';
// Run with: flutter test --platform chrome test/credential_autofill_web_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter/semantics.dart';
import 'package:mysold/widgets/credential_autofill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/widgets/credential_autofill_web.dart' as bridge;
import 'package:web/web.dart' as web;

void fill(web.HTMLInputElement input, String value, {String? event = 'input'}) {
  input.value = value;
  if (event != null)
    input.dispatchEvent(web.Event(event, web.EventInit(bubbles: true)));
}

void main() {
  late TextEditingController username, password;
  late web.HTMLFormElement form;
  late web.HTMLInputElement email, secret;
  web.HTMLInputElement input(String id) {
    final wrapper = web.document.createElement('div')
      ..setAttribute('flt-semantics-identifier', id);
    final field = web.document.createElement('input') as web.HTMLInputElement;
    wrapper.appendChild(field);
    form.appendChild(wrapper);
    return field;
  }

  setUp(() async {
    username = TextEditingController();
    password = TextEditingController();
    form = web.document.createElement('form') as web.HTMLFormElement;
    web.document.body!.appendChild(form);
    email = input('fixture-email');
    secret = input('fixture-password');
    bridge.setCredentialScope('fixture', true);
    bridge.registerCredential(
      'fixture-email',
      'fixture',
      username,
      'username',
      'username',
      'text',
    );
    bridge.registerCredential(
      'fixture-password',
      'fixture',
      password,
      'password',
      'current-password',
      'password',
    );
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() {
    bridge.unregisterCredential('fixture-email');
    bridge.unregisterCredential('fixture-password');
    bridge.setCredentialScope('fixture', false);
    form.remove();
    username.dispose();
    password.dispose();
  });
  test(
    'Unfocused input and change events update both controllers, with standard form metadata',
    () {
      expect(email.autocomplete, 'username');
      expect(email.type, 'text');
      expect(secret.autocomplete, 'current-password');
      expect(secret.type, 'password');
      expect(email.name, 'username');
      expect(secret.name, 'password');
      expect(email.id, isNot(secret.id));
      expect(email.form, form);
      expect(secret.form, form);
      final focus = web.document.activeElement;
      fill(email, 'alice@example.test');
      fill(secret, 'Not-a-real-secret-123! €', event: 'change');
      expect(username.text, 'alice@example.test');
      expect(password.text, 'Not-a-real-secret-123! €');
      expect(web.document.activeElement, focus);
    },
  );
  test('Silent autofill is reconciled before form validation', () {
    fill(email, 'new@example.test', event: null);
    fill(secret, 'Generated-password-123!', event: null);
    bridge.syncCredentials();
    expect(username.text, 'new@example.test');
    expect(password.text, 'Generated-password-123!');
  });
  test(
    'Clearing removes native secrets, read-only values are ignored, and listeners are released',
    () {
      fill(secret, 'Temporary-password-123!');
      password.clear();
      expect(secret.value, isEmpty);
      secret.readOnly = true;
      fill(secret, 'Ignored');
      bridge.syncCredentials();
      expect(password.text, isEmpty);
      secret.readOnly = false;
      bridge.setCredentialScope('fixture', false);
      fill(secret, 'Stale-field-write');
      bridge.syncCredentials();
      expect(password.text, isEmpty);
      bridge.unregisterCredential('fixture-password');
      fill(secret, 'Disposed-field-write');
      bridge.syncCredentials();
      expect(password.text, isEmpty);
    },
  );
  test(
    'Generated passwords and confirmation have independent stable identities',
    () async {
      final confirmation = TextEditingController();
      final confirm = input('fixture-confirm');
      bridge.registerCredential(
        'fixture-password',
        'fixture',
        password,
        'new-password',
        'new-password',
        'password',
      );
      bridge.registerCredential(
        'fixture-confirm',
        'fixture',
        confirmation,
        'confirm-password',
        'new-password',
        'password',
      );
      await Future<void>.delayed(Duration.zero);
      try {
        expect(secret.id, isNot(confirm.id));
        expect(confirm.autocomplete, 'new-password');
        fill(secret, 'Generated-123!');
        fill(confirm, 'Generated-123!', event: 'change');
        expect(password.text, confirmation.text);
        fill(confirm, 'Mismatch-123!');
        expect(password.text, 'Generated-123!');
      } finally {
        bridge.unregisterCredential('fixture-confirm');
        confirmation.dispose();
      }
    },
  );
  test(
    'The focused editor handles IME composition before reconciliation',
    () async {
      email.focus();
      username.value = const TextEditingValue(
        text: 'に',
        composing: TextRange(start: 0, end: 1),
      );
      final changes = <TextRange>[];
      void changed() => changes.add(username.value.composing);
      username.addListener(changed);
      final engine = ((web.Event _) {
        username.value = TextEditingValue(
          text: email.value,
          composing: TextRange(start: 0, end: email.value.length),
        );
      }).toJS;
      email.addEventListener('input', engine);
      try {
        fill(email, '日本');
        await Future<void>.delayed(Duration.zero);
        expect(username.text, '日本');
        expect(changes, [const TextRange(start: 0, end: 2)]);
      } finally {
        email.removeEventListener('input', engine);
        username.removeListener(changed);
      }
    },
  );

  testWidgets('Autofill never forces or disables browser accessibility', (
    tester,
  ) async {
    final before = SemanticsBinding.instance.debugOutstandingSemanticsHandles;
    await tester.pumpWidget(
      const TickerMode(
        enabled: true,
        child: CredentialAutofillScope(child: SizedBox()),
      ),
    );
    expect(SemanticsBinding.instance.debugOutstandingSemanticsHandles, before);
    await tester.pumpWidget(
      const TickerMode(
        enabled: false,
        child: CredentialAutofillScope(child: SizedBox()),
      ),
    );
    expect(SemanticsBinding.instance.debugOutstandingSemanticsHandles, before);
    await tester.pumpWidget(const SizedBox());
    expect(SemanticsBinding.instance.debugOutstandingSemanticsHandles, before);
  });
}
