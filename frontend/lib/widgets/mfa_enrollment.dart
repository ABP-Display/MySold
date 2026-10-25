import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mysold/data/api_client.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/widgets/totp_qr_code.dart';

typedef MfaRequest =
    Future<Map<String, dynamic>> Function(
      String path, [
      Map<String, dynamic>? body,
    ]);

/// Optional registration step. Only the server's successful verification enables
/// MFA; showing or skipping a pending QR code never enables it.
class MfaEnrollment extends StatefulWidget {
  final String password;
  final Future<void> Function() onFinished;
  final VoidCallback onEnabled;
  final MfaRequest? request;

  const MfaEnrollment({
    super.key,
    required this.password,
    required this.onFinished,
    required this.onEnabled,
    this.request,
  });

  @override
  State<MfaEnrollment> createState() => _MfaEnrollmentState();
}

class _MfaEnrollmentState extends State<MfaEnrollment> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _busy = true;
  bool _enabling = false;
  bool _finishing = false;
  bool _enabled = false;
  bool _activationUncertain = false;
  bool _saved = false;
  String? _secret;
  String? _uri;
  String? _error;
  List<String>? _recoveryCodes;

  MfaRequest get _request => widget.request ?? ApiClient.instance.request;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : context.tr('Connexion au serveur impossible. Veuillez réessayer.');

  Future<void> _setup() async {
    setState(() {
      _busy = true;
      _error = null;
      _secret = null;
      _uri = null;
      _code.clear();
    });
    try {
      final data = await _request('auth/mfa/setup', {
        'password': widget.password,
      });
      if (!mounted) return;
      setState(() {
        _secret = data['secret'] as String;
        _uri = data['uri'] as String;
        _code.clear();
      });
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _acceptEnabled(List<String>? codes) {
    setState(() {
      _enabled = true;
      _activationUncertain = false;
      _secret = null;
      _uri = null;
      _code.clear();
      _recoveryCodes = codes;
    });
    widget.onEnabled();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _enable() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _enabling = true;
      _activationUncertain = true;
      _error = null;
    });
    try {
      final data = await _request('auth/mfa/enable', {
        'password': widget.password,
        'code': _code.text.trim(),
      });
      if (!mounted) return;
      _acceptEnabled(List<String>.from(data['recovery_codes'] as List));
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.code == 'invalid-mfa') {
        _activationUncertain = false;
      }
      // An interrupted response can follow a committed activation. Check the
      // actual server state before offering to skip an already enabled factor.
      if (error is! ApiException || error.code != 'invalid-mfa') {
        try {
          final status = await _request('auth/mfa');
          if (!mounted) return;
          if (status['enabled'] == true) {
            _acceptEnabled(null);
            return;
          }
          _activationUncertain = false;
        } catch (_) {
          // Retain the verification screen until the server can be reached.
        }
      }
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _enabling = false;
        });
    }
  }

  Future<void> _checkActivation() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await _request('auth/mfa');
      if (!mounted) return;
      if (status['enabled'] == true) {
        _acceptEnabled(null);
      } else {
        setState(() => _activationUncertain = false);
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (_enabling || _finishing || _activationUncertain) return;
    setState(() {
      _finishing = true;
      _error = null;
    });
    try {
      await widget.onFinished();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Future<void> _copy(String value, String confirmation) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr(confirmation))));
    } catch (_) {
      if (mounted)
        setState(
          () => _error = context.tr(
            'La copie a échoué. Sélectionnez le texte pour le copier manuellement.',
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_busy || _finishing) const LinearProgressIndicator(),
      if (_enabled) ...[
        Icon(
          Icons.verified_user_outlined,
          size: 40,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            context.tr('La double authentification est activée.'),
            style: const TextStyle(fontWeight: FontWeight.w600, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.tr(
            _recoveryCodes == null
                ? 'La confirmation du serveur a été interrompue. Votre 2FA est bien active ; renouvelez vos codes de secours dans les paramètres.'
                : 'Conservez ces codes dans un endroit sûr. Ils ne seront affichés qu’une fois. Chaque code permet une seule connexion si vous perdez votre authentificateur.',
          ),
          style: const TextStyle(height: 1.6),
        ),
        if (_recoveryCodes != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              _recoveryCodes!.join('\n'),
              key: const ValueKey('mfa-recovery-codes'),
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.8),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _copy(_recoveryCodes!.join('\n'), 'Codes copiés'),
            icon: const Icon(Icons.copy_outlined),
            label: Text(context.tr('Copier les codes')),
          ),
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              value: _saved,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: _finishing
                  ? null
                  : (value) => setState(() => _saved = value ?? false),
              title: Text(context.tr('J’ai sauvegardé mes codes')),
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _finishing || (_recoveryCodes != null && !_saved)
              ? null
              : _finish,
          child: Text(context.tr('Accéder à mon espace')),
        ),
      ] else ...[
        Text(
          context.tr(
            'Ajoutez MySold dans votre application d’authentification avec ce QR code ou la clé manuelle.',
          ),
          style: const TextStyle(height: 1.6),
        ),
        if (_uri != null) ...[
          const SizedBox(height: 20),
          TotpQrCode(key: const ValueKey('mfa-qr'), uri: _uri!),
          const SizedBox(height: 16),
          Text(
            context.tr('Clé de configuration'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SelectableText(
            _secret!,
            key: const ValueKey('mfa-secret'),
            style: const TextStyle(height: 1.6),
            textAlign: TextAlign.center,
          ),
          TextButton.icon(
            onPressed: () => _copy(_secret!, 'Clé copiée'),
            icon: const Icon(Icons.copy_outlined, size: 18),
            label: Text(context.tr('Copier la clé')),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              'Saisissez le code à 6 chiffres de votre authentificateur pour confirmer l’activation. Cette configuration expire après 10 minutes.',
            ),
            style: const TextStyle(height: 1.6),
          ),
          const SizedBox(height: 16),
          Form(
            key: _form,
            child: TextFormField(
              key: const ValueKey('enrollment-mfa-code'),
              controller: _code,
              enabled: !_busy && !_finishing && !_activationUncertain,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              autofillHints: const [AutofillHints.oneTimeCode],
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _enable(),
              validator: (value) => RegExp(r'^[0-9]{6}$').hasMatch(value ?? '')
                  ? null
                  : context.tr('Saisissez un code à 6 chiffres.'),
              decoration: InputDecoration(
                labelText: context.tr('Code à 6 chiffres'),
                prefixIcon: const Icon(Icons.password_outlined),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy || _finishing
                ? null
                : _activationUncertain
                ? _checkActivation
                : _enable,
            icon: const Icon(Icons.verified_user_outlined, size: 20),
            label: Text(
              context.tr(
                _activationUncertain
                    ? 'Vérifier l’activation'
                    : 'Activer la 2FA',
              ),
            ),
          ),
        ],
        TextButton(
          onPressed: _busy || _finishing || _activationUncertain
              ? null
              : _setup,
          child: Text(
            context.tr(
              _uri == null ? 'Réessayer' : 'Recommencer la configuration',
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _enabling || _finishing || _activationUncertain
              ? null
              : _finish,
          child: Text(context.tr('Passer pour le moment')),
        ),
        const SizedBox(height: 10),
        Text(
          context.tr(
            'Cette étape est facultative. Vous pourrez activer la 2FA dans les paramètres.',
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
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
    ],
  );
}
