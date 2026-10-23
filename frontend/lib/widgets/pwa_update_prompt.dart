import 'package:flutter/material.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/services/pwa_update_service.dart';

class PwaUpdatePrompt extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  const PwaUpdatePrompt({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  static bool _dialogVisible = false;

  /// Shared with the manual check in Settings, to avoid overlapping dialogs.
  static Future<bool> offer(BuildContext context) async {
    if (_dialogVisible) return false;
    _dialogVisible = true;
    try {
      return await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(context.tr('Une mise à jour est disponible')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.tr('Version installée')} : ${PwaUpdateService.currentBuild}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${context.tr('Nouvelle version')} : ${PwaUpdateService.availableBuild}',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr(
                        'Installer la nouvelle version de MySold ? L’application va se recharger. Enregistrez vos modifications avant de continuer.',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(context.tr('Plus tard')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(context.tr('Mettre à jour')),
                ),
              ],
            ),
          ) ??
          false;
    } finally {
      _dialogVisible = false;
    }
  }

  @override
  State<PwaUpdatePrompt> createState() => _PwaUpdatePromptState();
}

class _PwaUpdatePromptState extends State<PwaUpdatePrompt>
    with WidgetsBindingObserver {
  bool _checking = false;
  String? _offeredBuild;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final result = await PwaUpdateService.check();
      if (!mounted || result != 'available') return;
      final build = PwaUpdateService.availableBuild;
      if (build == _offeredBuild || PwaUpdatePrompt._dialogVisible) return;
      final context = widget.navigatorKey.currentState?.overlay?.context;
      if (context == null || !context.mounted) return;
      _offeredBuild = build;
      final confirmed = await PwaUpdatePrompt.offer(context);
      if (!confirmed || !mounted) return;
      final applied = await PwaUpdateService.apply();
      if (!applied && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'La mise à jour n’a pas pu être appliquée. Vérifiez votre connexion et réessayez.',
              ),
            ),
          ),
        );
      }
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
