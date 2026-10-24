import 'package:flutter/material.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/widgets/app_design.dart';

class SettingsAction {
  final String title, subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool busy;
  const SettingsAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.busy = false,
  });
}

class SettingsActionTile extends StatelessWidget {
  final SettingsAction action;
  const SettingsActionTile({super.key, required this.action});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(action.icon, color: colors.primary, size: 22),
        ),
        title: Text(
          context.tr(action.title),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(context.tr(action.subtitle)),
        ),
        trailing: action.busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right, size: 20),
        onTap: action.busy ? null : action.onTap,
      ),
    );
  }
}

class SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => AppPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr(title),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Material(type: MaterialType.transparency, child: child),
      ],
    ),
  );
}

class SettingsOverview extends StatelessWidget {
  final List<Widget> quickPreferences;
  final List<SettingsAction> actions;
  final Widget footer;
  final bool showIntro;
  const SettingsOverview({
    super.key,
    required this.quickPreferences,
    required this.actions,
    required this.footer,
    this.showIntro = true,
  });
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 920),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          if (showIntro)
            PageIntro(
              eyebrow: context.tr('PERSONNALISATION'),
              title: context.tr('Paramètres'),
              subtitle: context.tr(
                'Une application à votre image, des données sous votre contrôle.',
              ),
            ),
          SettingsSection(
            title: 'Préférences rapides',
            icon: Icons.tune_outlined,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final inline =
                    constraints.maxWidth >= 720 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 20;
                if (inline)
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final field in quickPreferences)
                        Expanded(child: field),
                    ],
                  );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < quickPreferences.length; i++) ...[
                      if (i > 0) const SizedBox(height: 20),
                      quickPreferences[i],
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: AppDesign.panel(context),
            child: Column(
              children: [
                for (var index = 0; index < actions.length; index++) ...[
                  if (index > 0)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: AppDesign.border(context),
                    ),
                  SettingsActionTile(action: actions[index]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          footer,
        ],
      ),
    ),
  );
}

class AdvancedPreferencesContent extends StatelessWidget {
  final bool notifications,
      budgetAlerts,
      hideAmounts,
      shakeEnabled,
      requestingMotion,
      loading;
  final ValueChanged<bool>? onNotifications,
      onBudgetAlerts,
      onHideAmounts,
      onShake;
  const AdvancedPreferencesContent({
    super.key,
    required this.notifications,
    required this.budgetAlerts,
    required this.hideAmounts,
    required this.shakeEnabled,
    required this.requestingMotion,
    required this.loading,
    required this.onNotifications,
    required this.onBudgetAlerts,
    required this.onHideAmounts,
    required this.onShake,
  });
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 920),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          SettingsSection(
            title: 'Notifications',
            icon: Icons.notifications_none_outlined,
            child: Column(
              children: [
                if (loading) const LinearProgressIndicator(),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: notifications,
                  onChanged: loading ? null : onNotifications,
                  title: Text(context.tr('Notifications locales')),
                  subtitle: Text(
                    context.tr(
                      'Autoriser MySold à afficher des notifications sur cet appareil.',
                    ),
                  ),
                ),
                const Divider(height: 24),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: budgetAlerts,
                  onChanged: loading || !notifications ? null : onBudgetAlerts,
                  title: Text(context.tr('Alertes budgétaires')),
                  subtitle: Text(
                    context.tr(
                      'Recevoir les alertes de seuils de votre budget mensuel.',
                    ),
                  ),
                ),
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_note_outlined),
                  title: Text(context.tr('Rappel mensuel')),
                  subtitle: Text(
                    context.tr(
                      'À venir. Aucun rappel automatique n’est programmé actuellement.',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SettingsSection(
            title: 'Mode discret',
            icon: Icons.visibility_off_outlined,
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: hideAmounts,
                  onChanged: onHideAmounts,
                  title: Text(context.tr('Masquer les montants')),
                  subtitle: Text(
                    context.tr(
                      'Également accessible avec le bouton œil dans la navigation.',
                    ),
                  ),
                ),
                const Divider(height: 24),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: shakeEnabled,
                  onChanged: requestingMotion ? null : onShake,
                  title: Text(context.tr('Secouer pour cacher')),
                  subtitle: Text(
                    context.tr(
                      requestingMotion
                          ? 'Vérification du capteur…'
                          : 'En option sur mobile compatible. Une secousse masque les montants ; le bouton œil les réaffiche.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
