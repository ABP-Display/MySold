import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mysold/enterPinPage.dart';
import 'package:mysold/services/auth_service.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/providers/user_data_provider.dart';
import 'package:mysold/register_page.dart';
import 'package:mysold/widgets/auth_layout.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:mysold/data/api_client.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _mfaCode = TextEditingController();
  String? _challenge;
  bool _recoveryMode = false;
  bool loading = false;
  bool obscurePassword = true;
  String? _error;

  void _showLegalNotice(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Theme(
        data: AuthPalette.theme,
        child: AlertDialog(
          title: Text(dialogContext.tr(title)),
          content: SingleChildScrollView(child: Text(dialogContext.tr(body))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.tr('Fermer')),
            ),
          ],
        ),
      ),
    );
  }

  void _openPasswordResetDialog() => _showLegalNotice(
    'Mot de passe oublié',
    'Contactez la personne qui administre votre instance MySold pour réinitialiser votre mot de passe.',
  );

  Future<void> _signIn() async {
    if (loading || !_form.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      loading = true;
      _error = null;
    });
    try {
      final user = _challenge != null
          ? await LocalAuth.instance.authenticate('mfa/verify', {
              'challenge': _challenge,
              'code': _mfaCode.text.trim(),
            })
          : await context.read<AuthService>().signIn(
              email: emailController.text.trim(),
              password: passwordController.text,
            );
      if (!mounted) return;
      if (user == null) {
        setState(() => _error = context.tr('Erreur de connexion'));
        return;
      }
      TextInput.finishAutofillContext();
      final references = context.read<UserDataProvider>();
      references.setUser(user.uid);
      await references.ensureReferences();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const EnterPinPage()),
      );
    } on MfaRequired catch (factor) {
      if (mounted)
        setState(() {
          _challenge = factor.challenge;
          passwordController.clear();
        });
    } on ApiException catch (error) {
      if (mounted)
        setState(() {
          _error = error.message;
          if (error.code == 'mfa-expired') _challenge = null;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _error = context.tr(
            'Connexion au serveur impossible. Veuillez réessayer.',
          ),
        );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    formBuilder: (context, compact) => Padding(
      padding: EdgeInsets.all(compact ? 22 : 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (compact) ...[const AuthBrand(), const SizedBox(height: 32)],
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AuthPalette.tint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.lock_outline,
                color: AuthPalette.accent,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.tr('HEUREUX DE VOUS RETROUVER'),
            style: const TextStyle(
              color: AuthPalette.accent,
              fontSize: 11,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              _challenge == null
                  ? 'Votre espace personnel'
                  : 'Vérification en deux étapes',
            ),
            style: const TextStyle(
              color: AuthPalette.text,
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              _challenge == null
                  ? 'Retrouvez vos comptes, votre budget et vos projets.'
                  : 'Saisissez le code de votre application d’authentification ou un code de secours.',
            ),
            style: const TextStyle(
              color: AuthPalette.muted,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          AutofillGroup(
            child: Form(
              key: _form,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_challenge != null) ...[
                    TextFormField(
                      key: const ValueKey('mfa-code'),
                      controller: _mfaCode,
                      enabled: !loading,
                      keyboardType: _recoveryMode
                          ? TextInputType.text
                          : TextInputType.number,
                      autofillHints: _recoveryMode
                          ? null
                          : const [AutofillHints.oneTimeCode],
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _signIn(),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? context.tr('Ce champ est requis.')
                          : null,
                      decoration: InputDecoration(
                        labelText: context.tr(
                          _recoveryMode
                              ? 'Code de secours'
                              : 'Code à 6 chiffres',
                        ),
                        prefixIcon: const Icon(Icons.verified_user_outlined),
                      ),
                    ),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () => setState(() {
                              _recoveryMode = !_recoveryMode;
                              _mfaCode.clear();
                            }),
                      child: Text(
                        context.tr(
                          _recoveryMode
                              ? 'Utiliser l’authentificateur'
                              : 'Utiliser un code de secours',
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () => setState(() {
                              _challenge = null;
                              _mfaCode.clear();
                              _error = null;
                            }),
                      child: Text(context.tr('Revenir à la connexion')),
                    ),
                  ] else ...[
                    TextFormField(
                      controller: emailController,
                      enabled: !loading,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          value == null ||
                              !RegExp(
                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                              ).hasMatch(value.trim())
                          ? context.tr('Adresse email invalide.')
                          : null,
                      decoration: InputDecoration(
                        labelText: context.tr('Adresse e-mail'),
                        prefixIcon: const Icon(Icons.mail_outline, size: 19),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: passwordController,
                      enabled: !loading,
                      obscureText: obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _signIn(),
                      validator: (value) => value == null || value.isEmpty
                          ? context.tr('Ce champ est requis.')
                          : null,
                      decoration: InputDecoration(
                        labelText: context.tr('Mot de passe'),
                        prefixIcon: const Icon(Icons.lock_outline, size: 19),
                        suffixIcon: IconButton(
                          tooltip: context.tr(
                            obscurePassword ? 'Afficher' : 'Masquer',
                          ),
                          onPressed: loading
                              ? null
                              : () => setState(
                                  () => obscurePassword = !obscurePassword,
                                ),
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: loading ? null : _openPasswordResetDialog,
                        child: Text(context.tr('Mot de passe oublie ?')),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 6),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: loading ? null : _signIn,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (loading) ...[
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AuthPalette.background,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Text(
                            context.tr(
                              loading
                                  ? 'Connexion...'
                                  : _challenge == null
                                  ? 'Se connecter'
                                  : 'Vérifier le code',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (!loading) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                context.tr('Pas encore de compte ?'),
                style: const TextStyle(color: AuthPalette.muted, fontSize: 13),
              ),
              TextButton(
                onPressed: loading
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const Register()),
                      ),
                child: Text(context.tr('Creer un compte')),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Divider(color: AuthPalette.border),
          const SizedBox(height: 10),
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
  );

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _mfaCode.dispose();
    super.dispose();
  }
}

class _LegalNotice extends StatelessWidget {
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;
  const _LegalNotice({required this.onTermsTap, required this.onPrivacyTap});

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        context.tr('En continuant, vous acceptez les'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: AuthPalette.muted, fontSize: 12),
      ),
      TextButton(onPressed: onTermsTap, child: Text(context.tr('CGU'))),
      Text(
        context.tr('et la'),
        style: const TextStyle(color: AuthPalette.muted, fontSize: 12),
      ),
      TextButton(
        onPressed: onPrivacyTap,
        child: Text(context.tr('Politique de confidentialite')),
      ),
      const Text('.', style: TextStyle(color: AuthPalette.muted, fontSize: 12)),
    ],
  );
}
