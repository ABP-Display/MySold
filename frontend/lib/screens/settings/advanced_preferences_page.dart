import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/services/local_notification_service.dart';
import 'package:mysold/services/shake_privacy_service.dart';
import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/widgets/settings/settings_overview.dart';

class AdvancedPreferencesPage extends StatefulWidget {
  const AdvancedPreferencesPage({super.key});
  @override
  State<AdvancedPreferencesPage> createState() =>
      _AdvancedPreferencesPageState();
}

class _AdvancedPreferencesPageState extends State<AdvancedPreferencesPage> {
  bool _notifications = true, _budgetAlerts = true, _loading = true;
  bool _requestingMotion = false, _requestingNotifications = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notifications = prefs.getBool('notifications_enabled') ?? true;
      _budgetAlerts = prefs.getBool('budget_alerts_enabled') ?? true;
      _loading = false;
    });
  }

  Future<void> _setNotifications(bool value) async {
    if (_requestingNotifications) return;
    setState(() => _requestingNotifications = true);
    try {
      if (value) value = await LocalNotificationService.requestPermission();
      if (!mounted) return;
      setState(() => _notifications = value);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', value);
    } finally {
      if (mounted) setState(() => _requestingNotifications = false);
    }
  }

  Future<void> _setBudgetAlerts(bool value) async {
    setState(() => _budgetAlerts = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('budget_alerts_enabled', value);
  }

  Future<void> _setShakeEnabled(bool value) async {
    if (_requestingMotion) return;
    final privacy = context.read<PrivacyProvider>();
    if (!value) {
      await privacy.setShakeEnabled(false);
      return;
    }
    setState(() => _requestingMotion = true);
    try {
      final allowed = await ShakePrivacyService.requestPermission();
      if (!mounted) return;
      if (allowed) {
        await privacy.setShakeEnabled(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'Le capteur de mouvement est indisponible ou son accès est refusé. Le bouton de masquage reste disponible.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _requestingMotion = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appPageBar(
      context,
      title: Text(context.tr('Préférences avancées')),
    ),
    body: Consumer<PrivacyProvider>(
      builder: (context, privacy, _) => AdvancedPreferencesContent(
        notifications: _notifications,
        budgetAlerts: _budgetAlerts,
        hideAmounts: privacy.hideAmounts,
        shakeEnabled: privacy.shakeEnabled,
        requestingMotion: _requestingMotion,
        loading: _loading || _requestingNotifications,
        onNotifications: _setNotifications,
        onBudgetAlerts: _setBudgetAlerts,
        onHideAmounts: privacy.setHideAmounts,
        onShake: _setShakeEnabled,
      ),
    ),
  );
}
