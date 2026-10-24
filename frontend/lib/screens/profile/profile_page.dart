import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/data/document_store.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:flutter/material.dart';

import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/screens/profile/account_page.dart';
import 'package:mysold/screens/profile/budget_alert_page.dart';
import 'package:mysold/screens/profile/category_page.dart';
import 'package:mysold/screens/profile/export_report_page.dart';
import 'package:mysold/screens/profile/investment_page.dart';
import 'package:mysold/screens/profile/simulation.dart';
import 'package:mysold/screens/settings/settings_sheet.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<_ProfileUser> _user;
  @override
  void initState() {
    super.initState();
    _user = _getUser();
  }

  Future<_ProfileUser> _getUser() async {
    final uid = LocalAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const _ProfileUser(firstName: 'Inconnu', lastName: '', email: '');
    }

    final snapshot = await DocumentStore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = snapshot.data();
    final authUser = LocalAuth.instance.currentUser;

    return _ProfileUser(
      firstName: (data?['firstName'] ?? 'Prenom').toString(),
      lastName: (data?['lastName'] ?? 'Nom').toString(),
      email: authUser?.email ?? '',
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _openSimulation(BuildContext context) {
    _push(context, const SimulationScreen(withBack: true));
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsSheet(withBack: true)),
    );
    if (mounted) setState(() => _user = _getUser());
  }

  void _openExport(BuildContext context) {
    _push(context, const ExportReportPage());
  }

  @override
  Widget build(BuildContext context) {
    final uid = LocalAuth.instance.currentUser?.uid;

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_ProfileUser>(
          future: _user,
          builder: (context, snapshot) {
            final user = snapshot.data;
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              children: [
                PageIntro(
                  eyebrow: context.tr('ESPACE PERSONNEL'),
                  title: context.tr('Votre profil'),
                  subtitle: context.tr(
                    'Organisez vos finances et personnalisez MySold.',
                  ),
                ),
                _buildHeader(context, user, isLoading),
                const SizedBox(height: 28),
                _buildSectionTitle(context, 'Gestion', Icons.tune_outlined),
                const SizedBox(height: 10),
                _buildActionList(context, uid),
                const SizedBox(height: 22),
                _buildSectionTitle(
                  context,
                  'Outils',
                  Icons.auto_graph_outlined,
                ),
                const SizedBox(height: 10),
                _buildToolPanel(context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    _ProfileUser? user,
    bool isLoading,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final initials = user == null
        ? '..'
        : '${user.firstName.isNotEmpty ? user.firstName[0] : ''}${user.lastName.isNotEmpty ? user.lastName[0] : ''}'
              .toUpperCase();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(context),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      initials.isEmpty ? '?' : initials,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoading
                      ? 'Chargement'
                      : '${user?.firstName ?? ''} ${user?.lastName ?? ''}'
                            .trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email.isNotEmpty == true
                      ? user!.email
                      : 'Espace personnel MySold',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.62),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('Parametres'),
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          context.tr(title),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildActionList(BuildContext context, String? uid) {
    final actions = [
      _ProfileAction(
        title: 'Comptes',
        subtitle: 'Soldes et banques',
        icon: Icons.account_balance_wallet_outlined,
        onTap: uid == null
            ? null
            : () => _push(context, ComptePage(userId: uid)),
      ),
      _ProfileAction(
        title: 'Categories',
        subtitle: 'Revenus et depenses',
        icon: Icons.category_outlined,
        onTap: uid == null
            ? null
            : () => _push(context, CategoriePage(userId: uid)),
      ),
      _ProfileAction(
        title: 'Investissements',
        subtitle: 'Actifs et supports',
        icon: Icons.trending_up_outlined,
        onTap: uid == null
            ? null
            : () => _push(context, InvestmentPage(userId: uid)),
      ),
      _ProfileAction(
        title: 'Limites',
        subtitle: 'Alertes budget',
        icon: Icons.notifications_active_outlined,
        onTap: uid == null
            ? null
            : () => _push(context, BudgetAlertPage(userId: uid)),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 650 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final action in actions)
              SizedBox(
                width: width,
                child: AppPanel(
                  padding: const EdgeInsets.all(6),
                  child: _ProfileActionRow(action: action),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildToolPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: _panelDecoration(context),
      child: Column(
        children: [
          _ToolTile(
            icon: Icons.calculate_outlined,
            title: 'Simulation',
            subtitle: 'Budget, investissement et prêt',
            onTap: () => _openSimulation(context),
          ),
          Divider(
            height: 1,
            color: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: 0.30),
          ),
          _ToolTile(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Export PDF',
            subtitle: 'Rapport annuel, mensuel ou personnalise',
            onTap: () => _openExport(context),
          ),
          Divider(
            height: 1,
            color: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: 0.30),
          ),
          _ToolTile(
            icon: Icons.settings_outlined,
            title: 'Parametres',
            subtitle: 'Theme, langue, devise et securite',
            onTap: () => _openSettings(context),
          ),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.30),
      ),
    );
  }
}

class _ProfileActionRow extends StatelessWidget {
  final _ProfileAction action;

  const _ProfileActionRow({required this.action});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        leading: Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(action.icon, color: colorScheme.primary),
        ),
        title: Text(
          context.tr(action.title),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          context.tr(action.subtitle),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.62),
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: action.onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolTile({
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
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          context.tr(subtitle),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _ProfileAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _ProfileAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

class _ProfileUser {
  final String firstName;
  final String lastName;
  final String email;

  const _ProfileUser({
    required this.firstName,
    required this.lastName,
    required this.email,
  });
}
