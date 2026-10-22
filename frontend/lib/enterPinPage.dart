import 'dart:convert';

import 'package:mysold/data/document_store.dart';
import 'package:crypto/crypto.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:flutter/material.dart';
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
      await DocumentStore.instance.collection('users').doc(uid).set(
        {'pin': enteredHashedPin},
        SetOptions(merge: true),
      );

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.primary.withOpacity(0.22),
                      ),
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'MySold',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Material(
                    color: colors.surfaceVariant.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(14),
                    child: IconButton(
                      tooltip: context.tr('Deconnexion'),
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: loadingPinStatus
                      ? const CircularProgressIndicator()
                      : SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.surfaceVariant.withOpacity(0.34),
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: colors.outline.withOpacity(0.12),
                                ),
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 24, 20, 22),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Icon(
                                      Icons.password_rounded,
                                      color: colors.primary,
                                      size: 34,
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      needsPinCreation
                                          ? context.tr('Creer votre PIN')
                                          : context.tr('Code PIN'),
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      needsPinCreation
                                          ? context.tr(
                                              'Choisissez un code a 6 chiffres pour securiser votre espace.',
                                            )
                                          : context.tr(
                                              'Entrez votre code a 6 chiffres pour deverrouiller vos donnees.',
                                            ),
                                      textAlign: TextAlign.center,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color:
                                            colors.onSurface.withOpacity(0.68),
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    PinCodeTextField(
                                      appContext: context,
                                      length: 6,
                                      obscureText: true,
                                      keyboardType: TextInputType.number,
                                      animationType: AnimationType.fade,
                                      animationDuration:
                                          const Duration(milliseconds: 180),
                                      enableActiveFill: true,
                                      cursorColor: colors.primary,
                                      textStyle: TextStyle(
                                        color: colors.onSurface,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                      pinTheme: PinTheme(
                                        shape: PinCodeFieldShape.box,
                                        borderRadius: BorderRadius.circular(14),
                                        fieldHeight: 52,
                                        fieldWidth: 44,
                                        activeColor: colors.primary,
                                        selectedColor: colors.primary,
                                        inactiveColor:
                                            colors.outline.withOpacity(0.25),
                                        activeFillColor:
                                            colors.primary.withOpacity(0.12),
                                        selectedFillColor:
                                            colors.primary.withOpacity(0.16),
                                        inactiveFillColor:
                                            colors.surface.withOpacity(0.45),
                                        errorBorderColor: colors.error,
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          _pin = value;
                                          errorText = null;
                                        });
                                      },
                                      onCompleted: (_) => _checkPin(),
                                    ),
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      child: errorText == null
                                          ? const SizedBox(height: 24)
                                          : Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 4,
                                              ),
                                              child: Text(
                                                errorText!,
                                                key: ValueKey(errorText),
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: colors.error,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      height: 52,
                                      child: ElevatedButton.icon(
                                        onPressed: _pin.length == 6 && !loading
                                            ? _checkPin
                                            : null,
                                        icon: loading
                                            ? SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: colors.onPrimary,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.arrow_forward_rounded,
                                              ),
                                        label: Text(
                                          loading
                                              ? context.tr('Verification...')
                                              : needsPinCreation
                                                  ? context.tr('Creer mon PIN')
                                                  : context.tr('Deverrouiller'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
