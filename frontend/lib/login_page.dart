import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mysold/enterPinPage.dart';
import 'package:mysold/services/auth_service.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/providers/user_data_provider.dart';
import 'package:mysold/register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool loading = false;
  bool obscurePassword = true;

  void _showLegalNotice(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr(title)),
        content: SingleChildScrollView(
          child: Text(dialogContext.tr(body)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('Fermer')),
          ),
        ],
      ),
    );
  }

  Future<void> _openPasswordResetDialog() async {
    _showLegalNotice('Mot de passe oublié',
        'Contactez la personne qui administre votre instance MySold pour réinitialiser votre mot de passe.');
  }

  Future<void> _signIn() async {
    if (loading) return;

    setState(() => loading = true);
    final authService = context.read<AuthService>();
    final user = await authService.signIn(
      email: emailController.text.trim(),
      password: passwordController.text,
    );

    if (!mounted) return;
    setState(() => loading = false);

    if (user != null) {
      final references = context.read<UserDataProvider>();
      references.setUser(user.uid);
      await references.ensureReferences();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EnterPinPage()),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('Erreur de connexion'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _AuthHeader(),
                  const SizedBox(height: 28),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant.withOpacity(0.34),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colors.outline.withOpacity(0.12),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: context.tr('Email'),
                              prefixIcon: const Icon(Icons.mail_outline),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _signIn(),
                            decoration: InputDecoration(
                              labelText: context.tr('Mot de passe'),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: obscurePassword
                                    ? context.tr('Afficher')
                                    : context.tr('Masquer'),
                                onPressed: () => setState(
                                  () => obscurePassword = !obscurePassword,
                                ),
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _openPasswordResetDialog,
                              child: Text(context.tr('Mot de passe oublie ?')),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: loading ? null : _signIn,
                              icon: loading
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colors.onPrimary,
                                      ),
                                    )
                                  : const Icon(Icons.login_rounded),
                              label: Text(
                                loading
                                    ? context.tr('Connexion...')
                                    : context.tr('Connexion'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const Register()),
                      );
                    },
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: Text(context.tr('Creer un compte')),
                  ),
                  const SizedBox(height: 14),
                  _LegalNotice(
                    onTermsTap: () => _showLegalNotice(
                      'Conditions generales d utilisation',
                      'legal_terms_full',
                    ),
                    onPrivacyTap: () => _showLegalNotice(
                      'Politique de confidentialite',
                      'privacy_policy_full',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}

class _LegalNotice extends StatelessWidget {
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  const _LegalNotice({
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62),
        );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          context.tr('En continuant, vous acceptez les'),
          textAlign: TextAlign.center,
          style: style,
        ),
        TextButton(
          onPressed: onTermsTap,
          child: Text(context.tr('CGU')),
        ),
        Text(
          context.tr('et la'),
          style: style,
        ),
        TextButton(
          onPressed: onPrivacyTap,
          child: Text(context.tr('Politique de confidentialite')),
        ),
        Text('.', style: style),
      ],
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 150,
          height: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceVariant.withOpacity(0.42),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.outline.withOpacity(0.12)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/icons/app_icon.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'MySold',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('Connectez-vous a votre espace bancaire.'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurface.withOpacity(0.70),
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
