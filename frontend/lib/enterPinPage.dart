import 'dart:convert';

import 'package:mysold/data/document_store.dart';
import 'package:crypto/crypto.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mysold/widgets/auth_layout.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/login_page.dart';
import 'package:mysold/main.dart';

class EnterPinPage extends StatefulWidget {
  const EnterPinPage({super.key});

  @override
  State<EnterPinPage> createState() => _EnterPinPageState();
}

class _EnterPinPageState extends State<EnterPinPage> {
  String _pin = '';
  String? errorText;
  bool loading = false;
  bool loadingPinStatus = true;
  bool needsPinCreation = false;

  String hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

  @override
  void initState() {
    super.initState();
    _loadPinStatus();
  }

  Future<void> _loadPinStatus() async {
    final uid = LocalAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await DocumentStore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (!mounted) return;
    setState(() {
      needsPinCreation = snapshot.data()?['pin'] == null;
      loadingPinStatus = false;
    });
  }

  Future<void> _checkPin() async {
    if (_pin.length != 6 || loading) return;

    final uid = LocalAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      loading = true;
      errorText = null;
    });

    final snapshot = await DocumentStore.instance
        .collection('users')
        .doc(uid)
        .get();
    final storedHashedPin = snapshot.data()?['pin'];
    final enteredHashedPin = hashPin(_pin);

    if (storedHashedPin == null) {
      await DocumentStore.instance.collection('users').doc(uid).set({
        'pin': enteredHashedPin,
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => loading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }

    if (!mounted) return;
    setState(() => loading = false);

    if (enteredHashedPin == storedHashedPin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      setState(() => errorText = context.tr('PIN incorrect'));
    }
  }

  Future<void> _logout() async {
    await LocalAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AuthPalette.theme,
    child: Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (viewport.maxHeight - 32).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AuthPalette.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AuthPalette.border, width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AuthBrand(logoSize: 100),
                        const SizedBox(height: 28),
                        const Icon(
                          Icons.lock_outline,
                          color: AuthPalette.accent,
                          size: 32,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr(
                            needsPinCreation ? 'Creer votre PIN' : 'Code PIN',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AuthPalette.text,
                            fontSize: 27,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          context.tr(
                            needsPinCreation
                                ? 'Choisissez un code a 6 chiffres pour securiser votre espace.'
                                : 'Entrez votre code a 6 chiffres pour deverrouiller vos donnees.',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AuthPalette.muted,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (loadingPinStatus)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          LayoutBuilder(
                            builder: (context, constraints) => PinCodeTextField(
                              appContext: context,
                              length: 6,
                              obscureText: true,
                              enabled: !loading,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              animationType: AnimationType.fade,
                              enableActiveFill: true,
                              cursorColor: AuthPalette.accent,
                              textStyle: const TextStyle(
                                color: AuthPalette.text,
                                fontSize: 20,
                              ),
                              pinTheme: PinTheme(
                                shape: PinCodeFieldShape.box,
                                borderRadius: BorderRadius.circular(10),
                                fieldHeight: 54,
                                fieldWidth: ((constraints.maxWidth - 30) / 6)
                                    .clamp(24.0, 48.0),
                                borderWidth: 1.5,
                                selectedBorderWidth: 2,
                                activeColor: AuthPalette.accent,
                                selectedColor: AuthPalette.accent,
                                inactiveColor: AuthPalette.border,
                                activeFillColor: AuthPalette.tint,
                                selectedFillColor: AuthPalette.tint,
                                inactiveFillColor: AuthPalette.field,
                                errorBorderColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                              ),
                              onChanged: (value) => setState(() {
                                _pin = value;
                                errorText = null;
                              }),
                              onCompleted: (_) => _checkPin(),
                            ),
                          ),
                          if (errorText != null) ...[
                            const SizedBox(height: 10),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                errorText!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AuthPalette.theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _pin.length == 6 && !loading
                                ? _checkPin
                                : null,
                            child: Text(
                              context.tr(
                                loading
                                    ? 'Verification...'
                                    : needsPinCreation
                                    ? 'Creer mon PIN'
                                    : 'Deverrouiller',
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        TextButton.icon(
                          onPressed: loading ? null : _logout,
                          icon: const Icon(Icons.logout, size: 18),
                          label: Text(context.tr('Deconnexion')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
