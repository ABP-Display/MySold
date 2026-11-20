import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
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
  bool _requestingMotion = false;

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
        hideAmounts: privacy.hideAmounts,
        shakeEnabled: privacy.shakeEnabled,
        requestingMotion: _requestingMotion,
        onHideAmounts: privacy.setHideAmounts,
        onShake: _setShakeEnabled,
      ),
    ),
  );
}
