import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:mysold/data/document_store.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/login_page.dart';
import 'package:mysold/main.dart';
import 'package:mysold/providers/user_data_provider.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/language_provider.dart';
import 'package:mysold/screens/settings/theme_settings.dart';
import 'package:mysold/services/auth_service.dart';
import 'package:mysold/widgets/auth_layout.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterFlowState();
}

class _RegisterFlowState extends State<Register> {
  final _forms = List.generate(3, (_) => GlobalKey<FormState>());
  final _scrollController = ScrollController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _pin = TextEditingController();
  int _step = 0;
  bool _busy = false;
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  bool _hidePin = true;
  String? _error;
  String _currency = CurrencyProvider.defaultCurrencyCode;
  String _language = LanguageProvider.defaultLanguageCode;
  String _theme = AppThemes.defaultThemeName;
  String _reconnection = 'never';

  @override
  void dispose() {
    _scrollController.dispose();
    for (final controller in [
      _firstName,
      _lastName,
      _email,
      _phone,
      _password,
      _confirmation,
      _pin,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _goToLogin() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  void _changeStep(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _step = step;
      _error = null;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _continue() {
    if (_busy || !_forms[_step].currentState!.validate()) return;
    if (_step < 2) {
      _changeStep(_step + 1);
    } else {
      _register();
    }
  }

  Future<void> _register() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    var accountCreated = false;
    try {
      final user = await context.read<AuthService>().signUp(
        email: _email.text.trim(),
        password: _password.text,
        additionalData: {
          'firstName': _firstName.text.trim(),
          'lastName': _lastName.text.trim(),
          'phone': _phone.text.trim(),
          'pin': sha256.convert(utf8.encode(_pin.text)).toString(),
          'theme': AppThemes.normalizeThemeName(_theme),
          'currency': CurrencyProvider.optionForCode(_currency).symbol,
          'currencyCode': _currency,
          'language': LanguageProvider.optionForCode(_language).name,
          'languageCode': _language,
          'reconnectionFrequency': _reconnection,
          'lockDelayMinutes': 0,
          'createdAt': Timestamp.now(),
        },
      );
      if (!mounted) return;
      if (user == null) {
        setState(
          () => _error = context.tr(
            'Impossible de créer ce compte. Vérifiez vos informations et réessayez.',
          ),
        );
        return;
      }
      accountCreated = true;
      TextInput.finishAutofillContext();
      final references = context.read<UserDataProvider>();
      references.setUser(user.uid);
      await references.ensureReferences();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen()));
    } catch (_) {
      if (!mounted) return;
      if (accountCreated) {
        // The account exists: do not offer a second registration attempt.
        _goToLogin();
      } else {
        setState(
          () => _error = context.tr(
            'Connexion au serveur impossible. Veuillez réessayer.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    scrollController: _scrollController,
    formBuilder: (context, compact) => _formPanel(context, compact: compact),
  );

  Widget _formPanel(BuildContext context, {required bool compact}) {
    final titles = [
      'Faisons connaissance',
      'Protégez votre espace',
      'À votre image',
    ];
    final descriptions = [
      'Quelques informations pour créer votre profil.',
      'Choisissez vos identifiants et votre code de verrouillage.',
      'Ces préférences pourront être modifiées dans les paramètres.',
    ];
    return Padding(
      padding: EdgeInsets.all(compact ? 22 : 40),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (compact) ...[const AuthBrand(), const SizedBox(height: 28)],
            _progress(),
            const SizedBox(height: 30),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AuthPalette.tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  [Icons.person_outline, Icons.lock_outline, Icons.tune][_step],
                  color: AuthPalette.accent,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr(titles[_step]),
              style: const TextStyle(
                color: AuthPalette.text,
                fontSize: 27,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(descriptions[_step]),
              style: const TextStyle(
                color: AuthPalette.muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 26),
            Form(
              key: _forms[_step],
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: AbsorbPointer(
                absorbing: _busy,
                child: switch (_step) {
                  0 => _profileFields(),
                  1 => _securityFields(),
                  _ => _preferences(),
                },
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
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
            ],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _busy ? null : _continue,
              style: FilledButton.styleFrom(
                backgroundColor: AuthPalette.accent,
                foregroundColor: AuthPalette.background,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_busy) ...[
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
                          _busy
                              ? 'Création en cours…'
                              : _step == 2
                              ? 'Créer mon compte'
                              : 'Continuer',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (!_busy) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ],
                ),
              ),
            ),
            if (_step > 0)
              TextButton(
                onPressed: _busy ? null : () => _changeStep(_step - 1),
                child: Text(context.tr('Retour')),
              ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  context.tr('Déjà un compte ?'),
                  style: const TextStyle(
                    color: AuthPalette.muted,
                    fontSize: 13,
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _goToLogin,
                  child: Text(context.tr('Se connecter')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _progress() => Semantics(
    label: context.tr('Étape ${_step + 1} sur 3'),
    child: Row(
      children: List.generate(3, (index) {
        final active = index <= _step;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 2 ? 0 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: active ? AuthPalette.accent : AuthPalette.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  '${index + 1}. ${context.tr(['Profil', 'Sécurité', 'Préférences'][index])}',
                  style: TextStyle(
                    fontSize: 11,
                    color: active ? AuthPalette.accent : AuthPalette.muted,
                    fontWeight: index == _step
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    ),
  );

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? context.tr('Ce champ est requis.')
      : null;

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    Iterable<String>? autofill,
    String? Function(String?)? validator,
    bool obscure = false,
    VoidCallback? toggle,
    String? helper,
    List<TextInputFormatter>? formatters,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboard,
      autofillHints: autofill,
      obscureText: obscure,
      autocorrect: toggle == null && keyboard == TextInputType.name,
      enableSuggestions: toggle == null,
      textInputAction: TextInputAction.next,
      inputFormatters: formatters,
      maxLength: maxLength,
      validator: validator ?? _required,
      decoration: InputDecoration(
        labelText: context.tr(label),
        prefixIcon: Icon(icon, size: 19),
        helperText: helper == null ? null : context.tr(helper),
        helperMaxLines: 3,
        counterText: '',
        suffixIcon: toggle == null
            ? null
            : IconButton(
                tooltip: context.tr(obscure ? 'Afficher' : 'Masquer'),
                onPressed: toggle,
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
              ),
      ),
    ),
  );

  Widget _profileFields() => Column(
    children: [
      Builder(
        builder: (context) {
          final first = _field(
            _firstName,
            'Prénom',
            Icons.person_outline,
            keyboard: TextInputType.name,
            autofill: [AutofillHints.givenName],
          );
          final last = _field(
            _lastName,
            'Nom',
            Icons.person_outline,
            keyboard: TextInputType.name,
            autofill: [AutofillHints.familyName],
          );
          if (MediaQuery.sizeOf(context).width < 500)
            return Column(children: [first, last]);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 12),
              Expanded(child: last),
            ],
          );
        },
      ),
      _field(
        _email,
        'Adresse e-mail',
        Icons.mail_outline,
        keyboard: TextInputType.emailAddress,
        autofill: [AutofillHints.email],
        validator: (value) {
          if (value == null ||
              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim()) ||
              value.trim().length > 254)
            return context.tr('Adresse email invalide.');
          return null;
        },
      ),
      _field(
        _phone,
        'Téléphone',
        Icons.phone_outlined,
        keyboard: TextInputType.phone,
        autofill: [AutofillHints.telephoneNumber],
      ),
    ],
  );

  Widget _securityFields() => Column(
    children: [
      _field(
        _password,
        'Mot de passe',
        Icons.lock_outline,
        autofill: [AutofillHints.newPassword],
        obscure: _hidePassword,
        toggle: () => setState(() => _hidePassword = !_hidePassword),
        helper:
            '8 caractères minimum, une majuscule, un chiffre et un caractère spécial.',
        validator: (value) {
          if (value == null ||
              value.length < 8 ||
              value.length > 256 ||
              !RegExp(r'[A-Z]').hasMatch(value) ||
              !RegExp(r'\d').hasMatch(value) ||
              !RegExp(r'[!@#\$&*~%?+=]').hasMatch(value))
            return context.tr(
              'Choisissez un mot de passe respectant les critères indiqués.',
            );
          return null;
        },
      ),
      _field(
        _confirmation,
        'Confirmer le mot de passe',
        Icons.lock_outline,
        autofill: [AutofillHints.newPassword],
        obscure: _hideConfirmation,
        toggle: () => setState(() => _hideConfirmation = !_hideConfirmation),
        validator: (value) =>
            value != _password.text || value == null || value.isEmpty
            ? context.tr('Les mots de passe ne correspondent pas.')
            : null,
      ),
      _field(
        _pin,
        'PIN (6 chiffres)',
        Icons.dialpad_outlined,
        keyboard: TextInputType.number,
        obscure: _hidePin,
        toggle: () => setState(() => _hidePin = !_hidePin),
        formatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 6,
        helper: 'Ce code verrouille votre interface MySold.',
        validator: (value) =>
            value == null || !RegExp(r'^\d{6}$').hasMatch(value)
            ? context.tr('Le code PIN doit contenir 6 chiffres.')
            : null,
      ),
      DropdownButtonFormField<String>(
        initialValue: _reconnection,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: context.tr('Demander une reconnexion'),
          prefixIcon: const Icon(Icons.shield_outlined, size: 19),
        ),
        items: ['never', 'always']
            .map(
              (value) => DropdownMenuItem(
                value: value,
                child: Text(
                  context.tr(value == 'always' ? 'Toujours' : 'Jamais'),
                ),
              ),
            )
            .toList(),
        onChanged: (value) =>
            setState(() => _reconnection = value ?? _reconnection),
      ),
    ],
  );

  Widget _preferences() => Column(
    children: [
      DropdownButtonFormField<String>(
        initialValue: _currency,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: context.tr('Devise'),
          prefixIcon: const Icon(Icons.payments_outlined, size: 19),
        ),
        items: CurrencyProvider.currencies
            .map(
              (option) => DropdownMenuItem(
                value: option.code,
                child: Text(option.label, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _currency = value ?? _currency),
      ),
      const SizedBox(height: 18),
      DropdownButtonFormField<String>(
        initialValue: _language,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: context.tr('Langue'),
          prefixIcon: const Icon(Icons.translate, size: 19),
        ),
        items: LanguageProvider.languages
            .map(
              (option) => DropdownMenuItem(
                value: option.code,
                child: Text(option.name),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _language = value ?? _language),
      ),
      const SizedBox(height: 18),
      DropdownButtonFormField<String>(
        initialValue: _theme,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: context.tr('Thème'),
          prefixIcon: const Icon(Icons.palette_outlined, size: 19),
        ),
        items: AppThemes.themes.keys
            .map((name) => DropdownMenuItem(value: name, child: Text(name)))
            .toList(),
        onChanged: (value) => setState(() => _theme = value ?? _theme),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AuthPalette.tint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 20,
              color: AuthPalette.accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr(
                  'Tout est prêt. Votre espace personnel vous attend.',
                ),
                style: const TextStyle(
                  color: AuthPalette.accent,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
