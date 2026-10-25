import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/widgets/account_autofill_group.dart';

void main() {
  testWidgets(
    'Confirmation secrets share a native autofill form with an untabbable username',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccountAutofillGroup(
              username: 'alice@example.test',
              child: TextField(
                obscureText: true,
                autofillHints: [AutofillHints.password],
                decoration: InputDecoration(labelText: 'Mot de passe actuel'),
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<Opacity>(
              find.descendant(
                of: find.byType(AutofillIdentifier),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        0,
      );
      await tester.showKeyboard(find.byType(TextField).last);
      final message = tester.testTextInput.log.lastWhere(
        (entry) => entry.method == 'TextInput.setClient',
      );
      final config = (message.arguments as List)[1] as Map;
      final fields = config['fields'] as List;
      final username = fields.cast<Map>().singleWhere(
        (field) => ((field['autofill'] as Map)['hints'] as List).contains(
          AutofillHints.username,
        ),
      );
      expect(
        ((username['autofill'] as Map)['editingValue'] as Map)['text'],
        'alice@example.test',
      );
      expect(
        fields.any(
          (field) => ((field['autofill'] as Map)['hints'] as List).contains(
            AutofillHints.password,
          ),
        ),
        true,
      );
      final hidden = tester.widget<TextField>(
        find.byType(TextField, skipOffstage: false).first,
      );
      expect(hidden.focusNode!.canRequestFocus, false);
      expect(hidden.focusNode!.skipTraversal, true);
      await tester.pumpWidget(const SizedBox());
      expect(
        tester.testTextInput.log
            .lastWhere(
              (entry) => entry.method == 'TextInput.finishAutofillContext',
            )
            .arguments,
        false,
      );
    },
  );

  testWidgets('PIN confirmations stay in the form with HTML autocomplete off', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AccountAutofillGroup(
            username: 'alice@example.test',
            child: TextField(
              obscureText: true,
              keyboardType: TextInputType.number,
              autofillHints: AccountAutofillGroup.pinHints,
            ),
          ),
        ),
      ),
    );
    await tester.showKeyboard(find.byType(TextField).last);
    final message = tester.testTextInput.log.lastWhere(
      (entry) => entry.method == 'TextInput.setClient',
    );
    final config = (message.arguments as List)[1] as Map;
    expect((config['autofill'] as Map)['hints'], ['off']);
    expect(config['fields'], hasLength(2));
  });
}
