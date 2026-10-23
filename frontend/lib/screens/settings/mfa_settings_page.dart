import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr/qr.dart';
import 'package:mysold/data/api_client.dart';
import 'package:mysold/l10n/app_localizations.dart';

class MfaSettingsPage extends StatefulWidget {
  const MfaSettingsPage({super.key});
  @override
  State<MfaSettingsPage> createState() => _MfaSettingsPageState();
}

class _MfaSettingsPageState extends State<MfaSettingsPage> {
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _busy = true;
  bool _loaded = false;
  bool _enabled = false;
  int _remaining = 0;
  String? _secret;
  String? _uri;
  List<String>? _codes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = context.tr(
            'Connexion au serveur impossible. Veuillez réessayer.',
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() => _run(() async {
    final status = await ApiClient.instance.request('auth/mfa');
    if (mounted)
      setState(() {
        _enabled = status['enabled'] == true;
        _remaining = (status['recovery_remaining'] as num).toInt();
        _loaded = true;
      });
  });

  Map<String, dynamic> get _credentials => {
    'password': _password.text,
    'code': _code.text.trim(),
  };

  Future<void> _setup() => _run(() async {
    final data = await ApiClient.instance.request('auth/mfa/setup', {
      'password': _password.text,
    });
    if (mounted)
      setState(() {
        _secret = data['secret'] as String;
        _uri = data['uri'] as String;
        _code.clear();
      });
  });

  Future<void> _enable() => _run(() async {
    final data = await ApiClient.instance.request(
      'auth/mfa/enable',
      _credentials,
    );
    if (mounted)
      setState(() {
        _enabled = true;
        _secret = null;
        _uri = null;
        _codes = List<String>.from(data['recovery_codes'] as List);
        _remaining = _codes!.length;
        _password.clear();
        _code.clear();
      });
  });

  Future<void> _regenerate() async {
    final confirmed = await _confirm(
      'Renouveler les codes de secours ?',
      'Les anciens codes de secours seront immédiatement invalidés.',
    );
    if (!confirmed || !mounted) return;
    await _run(() async {
      final data = await ApiClient.instance.request(
        'auth/mfa/recovery',
        _credentials,
      );
      if (mounted)
        setState(() {
          _codes = List<String>.from(data['recovery_codes'] as List);
          _remaining = _codes!.length;
          _password.clear();
          _code.clear();
        });
    });
  }

  Future<bool> _confirm(String title, String description) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.tr(title)),
          content: SingleChildScrollView(child: Text(context.tr(description))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('Annuler')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.tr('Confirmer')),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _disable() async {
    final confirmed = await _confirm(
      'Désactiver la double authentification ?',
      'Les prochaines connexions ne demanderont plus de code d’authentificateur.',
    );
    if (!confirmed || !mounted) return;
    await _run(() async {
      await ApiClient.instance.request('auth/mfa/disable', _credentials);
      if (mounted)
        setState(() {
          _enabled = false;
          _remaining = 0;
          _password.clear();
          _code.clear();
        });
    });
  }

  @override
  void dispose() {
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Double authentification'))),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                _enabled ? Icons.verified_user_outlined : Icons.shield_outlined,
                size: 42,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(
                  _enabled
                      ? 'Protection activée'
                      : 'Un code en plus, un compte mieux protégé',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                context.tr(
                  'Utilisez une application d’authentification compatible TOTP. Le code change toutes les 30 secondes. Activez l’heure automatique sur vos appareils.',
                ),
                style: const TextStyle(height: 1.6),
              ),
              if (_enabled) ...[
                const SizedBox(height: 12),
                Text(
                  '${context.tr('Codes de secours restants')} : $_remaining',
                ),
              ],
              const SizedBox(height: 24),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              if (!_loaded && !_busy)
                TextButton(
                  onPressed: _load,
                  child: Text(context.tr('Réessayer')),
                ),
              if (_codes != null) ...[
                const SizedBox(height: 20),
                Text(
                  context.tr(
                    'Conservez ces codes dans un endroit sûr. Ils ne seront affichés qu’une fois. Chaque code permet une seule connexion si vous perdez votre authentificateur.',
                  ),
                  style: const TextStyle(height: 1.6),
                ),
                const SizedBox(height: 18),
                SelectableText(
                  _codes!.join('\n'),
                  style: const TextStyle(fontFamily: 'monospace', height: 1.8),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: _codes!.join('\n')),
                  ),
                  icon: const Icon(Icons.copy),
                  label: Text(context.tr('Copier les codes')),
                ),
                FilledButton(
                  onPressed: () => setState(() => _codes = null),
                  child: Text(context.tr('J’ai sauvegardé mes codes')),
                ),
              ] else if (_loaded) ...[
                const SizedBox(height: 16),
                if (_secret != null) ...[
                  Text(
                    context.tr(
                      '1. Scannez ce QR code dans votre authentificateur, ou saisissez la clé manuellement. Cette configuration expire après 10 minutes.',
                    ),
                    style: const TextStyle(height: 1.6),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: CustomPaint(painter: _TotpQrPainter(_uri!)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SelectableText(
                    _secret!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr(
                      '2. Confirmez le code à 6 chiffres pour activer la protection. La clé et le QR code sont confidentiels.',
                    ),
                    style: const TextStyle(height: 1.6),
                  ),
                  const SizedBox(height: 18),
                ],
                TextField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: context.tr('Mot de passe actuel'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (_enabled || _secret != null) ...[
                  const SizedBox(height: 18),
                  TextField(
                    controller: _code,
                    enabled: !_busy,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: _enabled
                        ? TextInputType.text
                        : TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.tr(
                        _enabled
                            ? 'Code TOTP ou code de secours'
                            : 'Code à 6 chiffres',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (!_enabled)
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : _secret == null
                        ? _setup
                        : _enable,
                    child: Text(
                      context.tr(
                        _secret == null
                            ? 'Configurer l’authentificateur'
                            : 'Activer la double authentification',
                      ),
                    ),
                  ),
                if (_secret != null)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _secret = null;
                            _uri = null;
                            _code.clear();
                          }),
                    child: Text(context.tr('Recommencer la configuration')),
                  ),
                if (_enabled) ...[
                  OutlinedButton(
                    onPressed: _busy ? null : _regenerate,
                    child: Text(context.tr('Renouveler les codes de secours')),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy ? null : _disable,
                    child: Text(
                      context.tr('Désactiver la double authentification'),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _TotpQrPainter extends CustomPainter {
  final String data;
  final QrImage image;
  _TotpQrPainter(this.data)
    : image = QrImage(
        QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
      );
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final module = size.width / (image.moduleCount + 8);
    final paint = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (var y = 0; y < image.moduleCount; y++) {
      for (var x = 0; x < image.moduleCount; x++) {
        if (image.isDark(y, x))
          canvas.drawRect(
            Rect.fromLTWH((x + 4) * module, (y + 4) * module, module, module),
            paint,
          );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TotpQrPainter oldDelegate) =>
      oldDelegate.data != data;
}
