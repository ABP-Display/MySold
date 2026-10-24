import 'package:mysold/screens/settings/advanced_preferences_page.dart';
import 'package:mysold/widgets/settings/settings_overview.dart';
import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/data/document_store.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:flutter/material.dart';

import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/login_page.dart';
import 'package:mysold/screens/settings/currency_selector.dart';
import 'package:mysold/screens/settings/language_selector.dart';
import 'package:mysold/screens/settings/security_privacy_page.dart';
import 'package:mysold/screens/settings/theme_selector.dart';
import 'package:mysold/services/security_gate.dart';
import 'package:mysold/services/pwa_update_service.dart';
import 'package:mysold/widgets/pwa_update_prompt.dart';

class SettingsSheet extends StatefulWidget {
  final bool withBack;

  const SettingsSheet({super.key, this.withBack = false});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  bool _checkingUpdate = false;

  Future<void> _checkForUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      final result = await PwaUpdateService.check();
      if (!mounted) return;
      if (result == 'available') {
        final confirmed = await PwaUpdatePrompt.offer(context);
        if (confirmed != true || !mounted) return;
        final applied = await PwaUpdateService.apply();
        if (!applied && mounted)
          _showUpdateMessage(
            'La mise à jour n’a pas pu être appliquée. Vérifiez votre connexion et réessayez.',
          );
      } else {
        _showUpdateMessage(switch (result) {
          'latest' => 'Votre application est à jour.',
          'offline' =>
            'Vous êtes hors connexion. Reconnectez-vous pour vérifier les mises à jour.',
          'unsupported' =>
            'La mise à jour PWA nécessite un navigateur compatible et une connexion HTTPS (ou localhost).',
          _ =>
            'Impossible de vérifier les mises à jour. Vérifiez votre connexion et réessayez.',
        });
      }
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  void _showUpdateMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.tr(message))));
  }

  DocumentReference<Map<String, dynamic>>? get _userRef {
    final uid = LocalAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return DocumentStore.instance.collection('users').doc(uid);
  }

  Future<Map<String, dynamic>> _loadUserData() async {
    final ref = _userRef;
    if (ref == null) return {};
    final doc = await ref.get();
    return doc.data() ?? {};
  }

  Future<void> _openPersonalDataEditor() async {
    final authorized = await SecurityGate.requestPin(
      context,
      title: 'Données personnelles',
      message: 'Confirmez votre PIN avant de modifier vos informations.',
    );
    if (!authorized || !mounted) return;

    final data = await _loadUserData();
    if (!mounted) return;

    final firstNameCtrl = TextEditingController(
      text: (data['firstName'] ?? '').toString(),
    );
    final lastNameCtrl = TextEditingController(
      text: (data['lastName'] ?? '').toString(),
    );
    final phoneCtrl = TextEditingController(
      text: (data['phone'] ?? '').toString(),
    );

    final saved = await showAppSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetTitle(context, 'Données personnelles'),
                const SizedBox(height: 18),
                TextField(
                  controller: firstNameCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr('Prénom'),
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: lastNameCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr('Nom'),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: context.tr('Téléphone'),
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final ref = _userRef;
                      if (ref == null) return;

                      await ref.set({
                        'firstName': firstNameCtrl.text.trim(),
                        'lastName': lastNameCtrl.text.trim(),
                        'phone': phoneCtrl.text.trim(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));

                      if (context.mounted) Navigator.pop(context, true);
                    },
                    icon: const Icon(Icons.check),
                    label: Text(context.tr('Enregistrer')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Donnees personnelles enregistrees')),
        ),
      );
    }
  }

  Future<void> _openSecurityPrivacyPage() async {
    final authorized = await SecurityGate.requestPin(
      context,
      title: 'Sécurité et confidentialité',
      message: 'Confirmez votre PIN pour acceder aux parametres sensibles.',
    );
    if (!authorized || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SecurityPrivacyPage()),
    );
  }

  void _openAboutSheet() {
    showAboutDialog(
      context: context,
      applicationName: 'MySold',
      applicationVersion: PwaUpdateService.currentBuild,
      applicationIcon: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.14),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.account_balance_wallet_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      children: [
        Text(
          context.tr(
            'MySold aide a suivre comptes, transactions, categories, investissements et limites budgetaires.',
          ),
        ),
        const SizedBox(height: 12),
        Text(context.tr('Application en developpement actif.')),
      ],
    );
  }

  Widget _sheetTitle(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        context.tr(title),
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _logout() async {
    await LocalAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.withBack
          ? appPageBar(
              context,
              leading: BackButton(onPressed: () => Navigator.pop(context)),
              title: Text(context.tr('Paramètres')),
            )
          : null,
      body: SettingsOverview(
        showIntro: !widget.withBack,
        quickPreferences: const [
          ThemeSelector(),
          LanguageSelector(),
          CurrencySelector(),
        ],
        actions: [
          SettingsAction(
            icon: Icons.lock_outline,
            title: 'Sécurité et confidentialité',
            subtitle: 'PIN, verrouillage et double authentification',
            onTap: _openSecurityPrivacyPage,
          ),
          SettingsAction(
            icon: Icons.person_outline,
            title: 'Données personnelles',
            subtitle: 'Nom, prénom et téléphone',
            onTap: _openPersonalDataEditor,
          ),
          SettingsAction(
            icon: Icons.tune_outlined,
            title: 'Préférences avancées',
            subtitle: 'Notifications et mode discret',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AdvancedPreferencesPage(),
              ),
            ),
          ),
          SettingsAction(
            icon: Icons.system_update_outlined,
            title: 'Mettre à jour l’application',
            subtitle: _checkingUpdate
                ? 'Vérification en cours…'
                : 'Rechercher une nouvelle version de MySold',
            onTap: _checkForUpdate,
            busy: _checkingUpdate,
          ),
          SettingsAction(
            icon: Icons.info_outline,
            title: 'À propos',
            subtitle: 'Version et informations de l’application',
            onTap: _openAboutSheet,
          ),
        ],
        footer: FilledButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          label: Text(context.tr('Déconnexion')),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}
