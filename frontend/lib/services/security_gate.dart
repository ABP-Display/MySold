import 'dart:convert';

import 'package:mysold/data/document_store.dart';
import 'package:crypto/crypto.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:flutter/material.dart';
import 'package:mysold/l10n/app_localizations.dart';

class SecurityGate {
  static String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  static Future<bool> requestPin(
    BuildContext context, {
    String title = 'Confirmation PIN',
    String message = 'Entrez votre code PIN pour confirmer cette action.',
  }) async {
    final uid = LocalAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final doc = await DocumentStore.instance.collection('users').doc(uid).get();
    final storedPin = doc.data()?['pin']?.toString();
    if (storedPin == null || storedPin.isEmpty) return true;
    if (!context.mounted) return false;

    final controller = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(context.tr(title)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr(message)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 6,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.tr('Code PIN'),
                      counterText: '',
                      errorText: errorText,
                      prefixIcon: const Icon(Icons.pin_outlined),
                    ),
                    onSubmitted: (_) {
                      _validatePin(
                        dialogContext,
                        controller.text,
                        storedPin,
                        (value) => setModalState(() => errorText = value),
                      );
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(context.tr('Annuler')),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _validatePin(
                      dialogContext,
                      controller.text,
                      storedPin,
                      (value) => setModalState(() => errorText = value),
                    );
                  },
                  icon: const Icon(Icons.lock_open_rounded),
                  label: Text(context.tr('Confirmer')),
                ),
              ],
            );
          },
        );
      },
    );

    return result == true;
  }

  static void _validatePin(
    BuildContext context,
    String pin,
    String storedPin,
    ValueChanged<String?> setError,
  ) {
    final cleanPin = pin.trim();
    if (cleanPin.length != 6) {
      setError(AppLocalizations.of(context).t('Le PIN doit faire 6 chiffres.'));
      return;
    }
    if (_hashPin(cleanPin) != storedPin) {
      setError(AppLocalizations.of(context).t('PIN incorrect'));
      return;
    }
    Navigator.pop(context, true);
  }
}
