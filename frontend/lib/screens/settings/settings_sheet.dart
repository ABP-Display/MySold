import 'package:mysold/data/document_store.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/login_page.dart';
import 'package:mysold/screens/settings/currency_selector.dart';
import 'package:mysold/screens/settings/language_selector.dart';
import 'package:mysold/screens/settings/security_privacy_page.dart';
import 'package:mysold/screens/settings/theme_selector.dart';
import 'package:mysold/services/security_gate.dart';
import 'package:mysold/services/local_notification_service.dart';

class SettingsSheet extends StatefulWidget {
  final bool withBack;

  const SettingsSheet({super.key, this.withBack = false});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  bool _notificationsEnabled = true;
  bool _budgetAlertsEnabled = true;
  bool _monthlyReminderEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadLocalSettings();
  }

  Future<void> _loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _budgetAlertsEnabled = prefs.getBool('budget_alerts_enabled') ?? true;
      _monthlyReminderEnabled =
          prefs.getBool('monthly_reminder_enabled') ?? false;
    });
  }

  Future<void> _setLocalBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
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
      title: 'Donnees personnelles',
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

    final saved = await showModalBottomSheet<bool>(
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
                _sheetHandle(context),
                const SizedBox(height: 18),
                _sheetTitle(context, 'Donnees personnelles'),
                const SizedBox(height: 18),
                TextField(
                  controller: firstNameCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr('Prenom'),
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
                    labelText: context.tr('Telephone'),
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

                      await ref.set(
                        {
                          'firstName': firstNameCtrl.text.trim(),
                          'lastName': lastNameCtrl.text.trim(),
                          'phone': phoneCtrl.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        },
                        SetOptions(merge: true),
                      );

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
        SnackBar(content: Text(context.tr('Donnees personnelles enregistrees'))),
      );
    }
  }

  Future<void> _openSecurityPrivacyPage() async {
    final authorized = await SecurityGate.requestPin(
      context,
      title: 'Securite et confidentialite',
      message: 'Confirmez votre PIN pour acceder aux parametres sensibles.',
    );
    if (!authorized || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SecurityPrivacyPage()),
    );
  }

  Future<void> _openNotificationSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> update(String key, bool value) async {
              if (key == 'notifications_enabled' && value) {
                value = await LocalNotificationService.requestPermission();
                if (!mounted) return;
              }
              setState(() {
                if (key == 'notifications_enabled') {
                  _notificationsEnabled = value;
                } else if (key == 'budget_alerts_enabled') {
                  _budgetAlertsEnabled = value;
                } else if (key == 'monthly_reminder_enabled') {
                  _monthlyReminderEnabled = value;
                }
              });
              setModalState(() {});
              await _setLocalBool(key, value);
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _sheetHandle(context),
                    const SizedBox(height: 18),
                    _sheetTitle(context, 'Notifications'),
                    const SizedBox(height: 8),
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _notificationsEnabled,
                        onChanged: (value) =>
                            update('notifications_enabled', value),
                        title: Text(context.tr('Notifications locales')),
                        subtitle: Text(
                          context.tr(
                            'Autoriser MySold a prevenir sur ce telephone',
                          ),
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _budgetAlertsEnabled,
                        onChanged: _notificationsEnabled
                            ? (value) => update('budget_alerts_enabled', value)
                            : null,
                        title: Text(context.tr('Alertes budgetaires')),
                        subtitle: Text(
                          context.tr('Seuils depenses / revenus du mois'),
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _monthlyReminderEnabled,
                        onChanged: _notificationsEnabled
                            ? (value) =>
                                update('monthly_reminder_enabled', value)
                            : null,
                        title: Text(context.tr('Rappel mensuel')),
                        subtitle: Text(
                          context.tr('Preparation pour un rappel de suivi'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openAboutSheet() {
    showAboutDialog(
      context: context,
      applicationName: 'MySold',
      applicationVersion: '2025.1.0+2',
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

  Widget _sheetHandle(BuildContext context) {
    return Container(
      width: 44,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline.withOpacity(0.35),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _sheetTitle(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        context.tr(title),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
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
          ? AppBar(
              leading: BackButton(onPressed: () => Navigator.pop(context)),
              title: Text(context.tr('Parametres')),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _buildPanel(
            context,
            title: 'Preferences',
            icon: Icons.tune_outlined,
            children: const [
              _SelectorBlock(
                title: 'Theme',
                icon: Icons.palette_outlined,
                child: ThemeSelector(),
              ),
              _PanelDivider(),
              _SelectorBlock(
                title: 'Langue',
                icon: Icons.language_outlined,
                child: LanguageSelector(),
              ),
              _PanelDivider(),
              _SelectorBlock(
                title: 'Devise',
                icon: Icons.payments_outlined,
                child: CurrencySelector(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPanel(
            context,
            title: 'Compte',
            icon: Icons.person_outline,
            children: [
              _SettingsRow(
                icon: Icons.lock_outline,
                title: 'Securite et confidentialite',
                subtitle: 'PIN, verrouillage et affichage discret',
                onTap: _openSecurityPrivacyPage,
              ),
              const _PanelDivider(),
              _SettingsRow(
                icon: Icons.person_outline,
                title: 'Donnees personnelles',
                subtitle: 'Nom, prenom et telephone',
                onTap: _openPersonalDataEditor,
              ),
              const _PanelDivider(),
              _SettingsRow(
                icon: Icons.notifications_none_outlined,
                title: 'Notifications',
                subtitle: 'Alertes locales et rappels',
                onTap: _openNotificationSettings,
              ),
              const _PanelDivider(),
              _SettingsRow(
                icon: Icons.info_outline,
                title: 'A propos',
                subtitle: 'Version et informations app',
                onTap: _openAboutSheet,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: Text(context.tr('Deconnexion')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.10),
        ),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              leading: Icon(icon),
              title: Text(
                context.tr(title),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SelectorBlock extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SelectorBlock({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                context.tr(title),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        leading: Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: colorScheme.primary),
        ),
        title: Text(
          context.tr(title),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          context.tr(subtitle),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _PanelDivider extends StatelessWidget {
  const _PanelDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outline.withOpacity(0.10),
    );
  }
}
