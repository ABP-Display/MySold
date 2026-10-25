import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mysold/data/api_client.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:mysold/login_page.dart';
import 'package:mysold/services/auth_service.dart';

class _Auth extends AuthService {
  int attempts = 0;
  bool expired = false;
  @override
  Future<User?> signIn({
    required String email,
    required String password,
  }) async => throw const MfaRequired('challenge-for-this-login');

  @override
  Future<User> verifySecondFactor({
    required String challenge,
    required String code,
  }) async {
    expect(challenge, 'challenge-for-this-login');
    attempts++;
    throw ApiException(
      expired ? 'mfa-expired' : 'invalid-mfa',
      expired ? 'Vérification expirée.' : 'Code incorrect.',
    );
  }
}

void main() {
  testWidgets(
    'Login requests MFA after credentials and handles invalid and expired codes',
    (tester) async {
      tester.view.physicalSize = const Size(360, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = _Auth();
      await tester.pumpWidget(
        Provider<AuthService>.value(
          value: auth,
          child: const MaterialApp(home: LoginPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'alice@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'MySold-Test-123!',
      );
      await tester.ensureVisible(find.text('Se connecter'));
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();
      expect(find.text('Vérification en deux étapes'), findsOneWidget);
      expect(find.text('Mot de passe'), findsNothing);
      await tester.ensureVisible(find.text('Vérifier le code'));
      await tester.tap(find.text('Vérifier le code'));
      await tester.pumpAndSettle();
      expect(auth.attempts, 0);
      await tester.enterText(find.byKey(const ValueKey('mfa-code')), '123456');
      await tester.ensureVisible(find.text('Vérifier le code'));
      await tester.tap(find.text('Vérifier le code'));
      await tester.pumpAndSettle();
      expect(auth.attempts, 1);
      expect(find.text('Code incorrect.'), findsOneWidget);
      auth.expired = true;
      await tester.tap(find.text('Vérifier le code'));
      await tester.pumpAndSettle();
      expect(find.text('Votre espace personnel'), findsOneWidget);
      expect(find.text('Vérification expirée.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
