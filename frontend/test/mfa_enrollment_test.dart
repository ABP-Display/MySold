// Browser-only API imports: flutter test --platform chrome.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/data/api_client.dart';
import 'package:mysold/widgets/auth_layout.dart';
import 'package:mysold/widgets/mfa_enrollment.dart';
import 'package:mysold/widgets/totp_qr_code.dart';

const secret = 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP';
const uri =
    'otpauth://totp/MySold:alice@example.test?secret=$secret&issuer=MySold';
final recoveryCodes = List.generate(10, (i) => 'ABCDE-12345-ABCDE-1234$i');

void main() {
  Future<void> open(
    WidgetTester tester, {
    required MfaRequest request,
    Size size = const Size(360, 640),
    double scale = 1,
    VoidCallback? onEnabled,
    Future<void> Function()? onFinished,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: AuthScaffold(
          formBuilder: (context, compact) => Padding(
            padding: const EdgeInsets.all(22),
            child: MfaEnrollment(
              password: 'MySold-Test-123!',
              request: request,
              onEnabled: onEnabled ?? () {},
              onFinished: onFinished ?? () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final finder = find.text(label);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final (size, scale) in [
    (const Size(320, 400), 2.0),
    (const Size(360, 640), 1.0),
    (const Size(768, 700), 1.0),
    (const Size(1440, 900), 1.0),
  ]) {
    testWidgets('QR, manual key and recovery codes fit $size at $scale', (
      tester,
    ) async {
      var enabled = 0;
      var finished = 0;
      var verified = 0;
      await open(
        tester,
        size: size,
        scale: scale,
        onEnabled: () => enabled++,
        onFinished: () async {
          finished++;
        },
        request: (path, [body]) async {
          if (path.endsWith('/setup')) return {'secret': secret, 'uri': uri};
          expect(body!['password'], 'MySold-Test-123!');
          expect(body['code'], '123456');
          verified++;
          return {'ok': true, 'recovery_codes': recoveryCodes};
        },
      );
      expect(find.byType(TotpQrCode), findsOneWidget);
      expect(find.text(secret), findsOneWidget);
      expect(enabled, 0);
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.byKey(const ValueKey('enrollment-mfa-code')),
        '123456',
      );
      await tap(tester, 'Activer la 2FA');
      expect(verified, 1);
      expect(enabled, 1);
      expect(finished, 0);
      expect(
        find.text('La double authentification est activée.'),
        findsOneWidget,
      );
      expect(find.text(secret), findsNothing);
      expect(find.text('Passer pour le moment'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Accéder à mon espace'),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, 'J’ai sauvegardé mes codes');
      await tap(tester, 'Accéder à mon espace');
      expect(finished, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('An incorrect or incomplete code never enables MFA', (
    tester,
  ) async {
    var attempts = 0;
    var enabled = false;
    var finished = false;
    await open(
      tester,
      onEnabled: () => enabled = true,
      onFinished: () async {
        finished = true;
      },
      request: (path, [body]) async {
        if (path.endsWith('/setup')) return {'secret': secret, 'uri': uri};
        attempts++;
        throw const ApiException('invalid-mfa', 'Code incorrect.');
      },
    );
    await tap(tester, 'Activer la 2FA');
    expect(attempts, 0);
    await tester.enterText(
      find.byKey(const ValueKey('enrollment-mfa-code')),
      '999999',
    );
    await tap(tester, 'Activer la 2FA');
    expect(attempts, 1);
    expect(enabled, false);
    expect(find.text('Code incorrect.'), findsOneWidget);
    await tap(tester, 'Passer pour le moment');
    expect(finished, true);
  });

  testWidgets('Setup failure can be skipped without enabling MFA', (
    tester,
  ) async {
    var finished = false;
    await open(
      tester,
      onFinished: () async {
        finished = true;
      },
      request: (_, [body]) async => throw Exception('offline'),
    );
    expect(find.text('Réessayer'), findsOneWidget);
    await tap(tester, 'Passer pour le moment');
    expect(finished, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Skipping is available while the optional QR is loading', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    var finished = false;
    // No pumpAndSettle while the loading indicator animates.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScaffold(
          formBuilder: (_, compact) => MfaEnrollment(
            password: 'password',
            onEnabled: () {},
            onFinished: () async {
              finished = true;
            },
            request: (_, [body]) => pending.future,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Passer pour le moment'));
    await tester.tap(find.text('Passer pour le moment'));
    await tester.pump();
    expect(finished, true);
    await tester.pumpWidget(const SizedBox());
    pending.complete({'secret': secret, 'uri': uri});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('A lost activation response is reconciled before leaving', (
    tester,
  ) async {
    var enabled = false;
    var canReachServer = false;
    await open(
      tester,
      onEnabled: () => enabled = true,
      request: (path, [body]) async {
        if (path.endsWith('/setup')) return {'secret': secret, 'uri': uri};
        if (path == 'auth/mfa' && canReachServer) return {'enabled': true};
        throw Exception('response lost');
      },
    );
    await tester.enterText(
      find.byKey(const ValueKey('enrollment-mfa-code')),
      '123456',
    );
    await tap(tester, 'Activer la 2FA');
    expect(enabled, false);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Passer pour le moment'),
          )
          .onPressed,
      isNull,
    );
    canReachServer = true;
    await tap(tester, 'Vérifier l’activation');
    expect(enabled, true);
    expect(
      find.text('La double authentification est activée.'),
      findsOneWidget,
    );
    expect(find.text('Passer pour le moment'), findsNothing);
  });
}
