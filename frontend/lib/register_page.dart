// ignore_for_file: unused_element

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mysold/data/document_store.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:mysold/services/auth_service.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/providers/user_data_provider.dart';
import 'package:mysold/screens/settings/currency_selector.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/language_selector.dart';
import 'package:mysold/screens/settings/language_provider.dart';
import 'package:mysold/screens/settings/theme_selector.dart';
import 'package:mysold/screens/settings/theme_settings.dart';
import 'package:mysold/main.dart';
import 'package:mysold/login_page.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  _RegisterFlowState createState() => _RegisterFlowState();
}

class _RegisterFlowState extends State<Register> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Données collectées
  String _selectedCurrencyCode = CurrencyProvider.defaultCurrencyCode;
  String _selectedLanguageCode = LanguageProvider.defaultLanguageCode;
  String _selectedTheme = AppThemes.defaultThemeName;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  bool _personalInfoConfirmed = false;
  bool _accountInfoConfirmed = false;
  bool _securityConfirmed = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscurePin = true;

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  bool _isSecurePassword(String password) {
    final regex = RegExp(r'^(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$&*~%?+=]).+$');
    return regex.hasMatch(password);
  }

  String _reconnectionFrequency = 'never';
  final List<String> _frequencies = [
    'never',
    'always',
  ];

  String _frequencyLabel(String value) {
    return value == 'always' ? context.tr('Toujours') : context.tr('Jamais');
  }

  void _nextPage() {
    if (_currentPage < 6) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  void _goToLogin() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (context) => LoginPage()));
  }

  Future<void> _register() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Les mots de passe ne correspondent pas.')),
        ),
      );
      return;
    }

    final authService = AuthService();
    final hashedPin = sha256
        .convert(utf8.encode(_pinController.text))
        .toString();
    final user = await authService.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      additionalData: {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'pin': hashedPin,
        'theme': AppThemes.normalizeThemeName(_selectedTheme),
        'currency': CurrencyProvider.optionForCode(_selectedCurrencyCode).symbol,
        'currencyCode': CurrencyProvider.normalizeCurrencyCode(
          _selectedCurrencyCode,
        ),
        'language': LanguageProvider.optionForCode(
          _selectedLanguageCode,
        ).name,
        'languageCode': LanguageProvider.normalizeLanguageCode(
          _selectedLanguageCode,
        ),
        'reconnectionFrequency': _reconnectionFrequency,
        'lockDelayMinutes': 0,
        'createdAt': Timestamp.now(),
      },
    );

    if (user != null && mounted) {
      final references = context.read<UserDataProvider>();
      references.setUser(user.uid);
      await references.ensureReferences();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Erreur lors de la creation du compte')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        children: [
          // Page 0: Présentation 1
          _buildModernPresentationPage(
            title: 'Espace financier personnel',
            description:
                '👋 Bienvenue dans votre espace financier personnel ! 👋\n\n'
                '🔄 Synchronisation multiplateforme 🔄\n Accédez à vos données où que vous soyez — sur mobile, tablette ou ordinateur — grâce à un compte sécurisé et synchronisé. \n\n'
                '💼 Accès fluide et continu à ses finances personnelles 💼\n Créez votre compte en quelques secondes pour commencer à gérer vos finances simplement, efficacement et en toute sécurité.',
            imageAsset: 'assets/icons/welcome_icon.png',
            pageIndex: 0,
          ),
          // Page 1: Présentation 2
          _buildModernPresentationPage(
            title: 'Fonctionnalités',
            description:
                '💡 Fonctionnalités puissantes, liberté totale.💡\n\n'
                'Prenez le contrôle total de vos finances personnelles grâce à une application 100% autonome, simple et intuitive.\n\n'
                '⚙️ Fonctionnalités clés ⚙️\n\n'
                '🧾 Gestion de budget personnalisée 🧾\n'
                '📊 Visualisations graphiques claires 📊\n'
                '🗂️ Catégorisation libre 🗂️\n'
                '💼 Simulation d\'investissement simple 💼\n'
                '🗓️ Vue mensuelle et vue globale 🗓️\n',
            imageAsset: 'assets/icons/fonctionalities_icon.png',
            pageIndex: 1,
          ),
          // Page 2: Présentation 3
          _buildModernPresentationPage(
            title: 'Sécurité',
            description:
                '🔐 La sécurité de vos données est notre priorité. 🔐\n\n'
                'Vos informations personnelles sont chiffrées et stockées de manière sécurisée, accessibles uniquement par vous. '
                'Grâce à un compte protégé et une synchronisation sécurisée, vous gérez vos finances en toute confiance, sur toutes vos plateformes.',
            imageAsset: 'assets/icons/security_icon.png',
            pageIndex: 2,
          ),
          // Page 3: Sélection des options
          _buildModernSettingsSelectionPage(),

          // Page 4: Formulaire d'inscription
          _buildRegistrationForm(),
        ],
      ),
    );
  }

  Widget _buildModernPresentationPage({
    required String title,
    required String description,
    required String imageAsset,
    required int pageIndex,
  }) {
    final bullets = _presentationBullets(pageIndex);

    return _buildOnboardingShell(
      pageIndex: pageIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          _buildProgressDots(pageIndex),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    height: 210,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceVariant.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Image.asset(imageAsset, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _presentationIntro(pageIndex),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.45,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.72),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...bullets.map(
                    (item) => _buildFeatureRow(
                      icon: item.icon,
                      title: item.title,
                      subtitle: item.subtitle,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildNavigationButtons(
            backLabel: pageIndex == 0 ? 'Connexion' : 'Retour',
            onBack: pageIndex == 0 ? _goToLogin : _previousPage,
            onNext: _nextPage,
          ),
        ],
      ),
    );
  }

  Widget _buildModernSettingsSelectionPage() {
    return _buildOnboardingShell(
      pageIndex: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          _buildProgressDots(3),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Personnalisation',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choisissez les preferences qui suivront votre compte.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.68),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Image.asset(
                    'assets/icons/user_settings_icon.png',
                    height: 150,
                  ),
                  const SizedBox(height: 24),
                  _buildPreferenceCard(
                    icon: Icons.payments_outlined,
                    title: 'Devise',
                    subtitle: 'Format utilise dans vos comptes et graphiques.',
                    child: CurrencySelector(
                      initialCurrencyCode: _selectedCurrencyCode,
                      onCurrencyChanged: (value) {
                        setState(() {
                          _selectedCurrencyCode = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildPreferenceCard(
                    icon: Icons.translate_outlined,
                    title: 'Langue',
                    subtitle: 'Preference sauvegardee pour votre profil.',
                    child: LanguageSelector(
                      initialLanguageCode: _selectedLanguageCode,
                      onLanguageChanged: (value) {
                        setState(() {
                          _selectedLanguageCode = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildPreferenceCard(
                    icon: Icons.palette_outlined,
                    title: 'Theme',
                    subtitle: 'L apparence change directement pendant le choix.',
                    child: ThemeSelector(
                      initialTheme: _selectedTheme,
                      onThemeChanged: (value) {
                        setState(() {
                          _selectedTheme = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildNavigationButtons(
            backLabel: 'Retour',
            onBack: _previousPage,
            onNext: _nextPage,
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingShell({
    required int pageIndex,
    required Widget child,
  }) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        child: child,
      ),
    );
  }

  Widget _buildProgressDots(int pageIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final isActive = index == pageIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: isActive ? 26 : 8,
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.35),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.35,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.66),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.24),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.62),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildNavigationButtons({
    required String backLabel,
    required VoidCallback onBack,
    required VoidCallback onNext,
  }) {
    return Row(
      children: [
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            label: Text(backLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Suivant',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _presentationIntro(int pageIndex) {
    switch (pageIndex) {
      case 0:
        return 'Un espace simple pour suivre vos comptes, vos mouvements et votre solde au quotidien.';
      case 1:
        return 'Des outils clairs pour classer vos revenus, vos depenses, vos transferts et vos investissements.';
      case 2:
        return 'Votre compte reste protege par authentification et code PIN avant acces a vos donnees.';
      default:
        return '';
    }
  }

  List<_OnboardingBullet> _presentationBullets(int pageIndex) {
    switch (pageIndex) {
      case 0:
        return const [
          _OnboardingBullet(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Vue claire',
            subtitle: 'Retrouvez vos comptes et votre solde en quelques secondes.',
          ),
          _OnboardingBullet(
            icon: Icons.sync_outlined,
            title: 'Synchronisation',
            subtitle: 'Vos donnees suivent votre compte sur vos appareils.',
          ),
          _OnboardingBullet(
            icon: Icons.timeline_outlined,
            title: 'Suivi mensuel',
            subtitle: 'Gardez le fil de vos mouvements mois apres mois.',
          ),
        ];
      case 1:
        return const [
          _OnboardingBullet(
            icon: Icons.category_outlined,
            title: 'Categories libres',
            subtitle: 'Organisez vos depenses et revenus selon vos habitudes.',
          ),
          _OnboardingBullet(
            icon: Icons.bar_chart_outlined,
            title: 'Graphiques',
            subtitle: 'Visualisez rapidement les tendances importantes.',
          ),
          _OnboardingBullet(
            icon: Icons.trending_up_outlined,
            title: 'Investissements',
            subtitle: 'Suivez vos supports comme ETF, gold ou crypto.',
          ),
        ];
      case 2:
        return const [
          _OnboardingBullet(
            icon: Icons.lock_outline,
            title: 'Code PIN',
            subtitle: 'Une couche de protection rapide avant ouverture.',
          ),
          _OnboardingBullet(
            icon: Icons.verified_user_outlined,
            title: 'Compte protege',
            subtitle: 'Connexion securisee et donnees liees a votre profil.',
          ),
          _OnboardingBullet(
            icon: Icons.privacy_tip_outlined,
            title: 'Controle',
            subtitle: 'Vous gardez la main sur vos preferences utilisateur.',
          ),
        ];
      default:
        return const [];
    }
  }

  Widget _buildPresentationPage({
    required String title,
    required String description,
    required String imageAsset,
    required int pageIndex,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          SizedBox(height: 16),

          // Titre seul (plus impactant visuellement)
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),

          // Image illustrative
          Image.asset(imageAsset, height: 200, fit: BoxFit.contain),

          SizedBox(height: 24),

          // Bloc description modernisé
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 53, 53, 53),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          SizedBox(height: 16),

          // Boutons navigation
          Row(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.15,
                child: OutlinedButton(
                  onPressed: () {
                    if (pageIndex == 0) {
                      _goToLogin();
                    } else {
                      _previousPage();
                    }
                  },
                  child: Icon(Icons.arrow_back),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    textStyle: TextStyle(fontSize: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(context.tr('Suivant')),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSettingsSelectionPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 16),
                  Text(
                    context.tr('Preferences utilisateur'),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  Image.asset(
                    'assets/icons/user_settings_icon.png',
                    height: 200,
                  ),
                  SizedBox(height: 24),

                  // --- Devise ---
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color.fromARGB(255, 53, 53, 53),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Selectionnez votre devise'),
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        SizedBox(height: 8),
                        CurrencySelector(
                          initialCurrencyCode: _selectedCurrencyCode,
                          onCurrencyChanged: (value) {
                            setState(() {
                              _selectedCurrencyCode = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // --- Langue ---
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color.fromARGB(255, 53, 53, 53),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Selectionnez votre langue'),
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        SizedBox(height: 8),
                        LanguageSelector(
                          initialLanguageCode: _selectedLanguageCode,
                          onLanguageChanged: (value) {
                            setState(() {
                              _selectedLanguageCode = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // --- Thème ---
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color.fromARGB(255, 53, 53, 53),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Selectionnez votre theme'),
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        SizedBox(height: 8),
                        ThemeSelector(
                          initialTheme: _selectedTheme,
                          onThemeChanged: (value) {
                            setState(() {
                              _selectedTheme = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // --- Boutons bas de page ---
          SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.13,
                child: OutlinedButton(
                  onPressed: _previousPage,
                  child: Icon(Icons.arrow_back),
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: TextStyle(fontSize: 18),
                  ),
                  child: Text(context.tr('Suivant')),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRegistrationForm() {
    final bool allSectionsConfirmed =
        _personalInfoConfirmed && _accountInfoConfirmed && _securityConfirmed;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                const SizedBox(height: 8),
                _buildProgressDots(4),
                const SizedBox(height: 22),
                Text(
                  context.tr('Creation du compte'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'Completez chaque section pour securiser votre espace MySold.',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.68),
                  ),
                ),
                const SizedBox(height: 22),

                // SECTION 1
                _buildExpandableSection(
                  title: context.tr('Informations personnelles'),
                  confirmed: _personalInfoConfirmed,
                  onEdit: () => setState(() => _personalInfoConfirmed = false),
                  contentVisible: !_personalInfoConfirmed,
                  content: Column(
                    children: [
                      TextField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: context.tr('Prenom'),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: context.tr('Nom'),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: context.tr('Telephone'),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: Icon(Icons.check),
                        label: Text(context.tr('Confirmer')),
                        onPressed: () {
                          if (_firstNameController.text.isNotEmpty &&
                              _lastNameController.text.isNotEmpty &&
                              _phoneController.text.isNotEmpty) {
                            setState(() => _personalInfoConfirmed = true);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.tr(
                                    'Veuillez remplir tous les champs personnels.',
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // SECTION 2
                _buildExpandableSection(
                  title: context.tr('Informations du compte'),
                  confirmed: _accountInfoConfirmed,
                  onEdit: () => setState(() => _accountInfoConfirmed = false),
                  contentVisible:
                      !_accountInfoConfirmed && _personalInfoConfirmed,
                  content: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: context.tr('Email'),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: context.tr('Mot de passe'),
                          border: OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: context.tr('Confirmer le mot de passe'),
                          border: OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: Icon(Icons.check),
                        label: Text(context.tr('Confirmer')),
                        onPressed: () {
                          if (_emailController.text.isNotEmpty &&
                              _isValidEmail(_emailController.text) &&
                              _passwordController.text.isNotEmpty &&
                              _isSecurePassword(_passwordController.text) &&
                              _confirmPasswordController.text ==
                                  _passwordController.text) {
                            setState(() => _accountInfoConfirmed = true);
                          } else {
                            String message;
                            if (!_isValidEmail(_emailController.text)) {
                              message = context.tr('Adresse email invalide.');
                            } else if (!_isSecurePassword(
                              _passwordController.text,
                            )) {
                              message = context.tr(
                                'Le mot de passe doit contenir au moins 1 majuscule, 1 chiffre et 1 caractere special.',
                              );
                            } else if (_passwordController.text !=
                                _confirmPasswordController.text) {
                              message = context.tr(
                                'Les mots de passe ne correspondent pas.',
                              );
                            } else {
                              message = context.tr(
                                'Veuillez remplir tous les champs du compte.',
                              );
                            }

                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(message)));
                          }
                        },
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // SECTION 3
                _buildExpandableSection(
                  title: context.tr('Securite de l application'),
                  confirmed: _securityConfirmed,
                  onEdit: () => setState(() => _securityConfirmed = false),
                  contentVisible:
                      !_securityConfirmed &&
                      _personalInfoConfirmed &&
                      _accountInfoConfirmed,
                  content: Column(
                    children: [
                      TextField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        obscureText: _obscurePin,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: context.tr('PIN (6 chiffres)'),
                          border: OutlineInputBorder(),
                          counterText: '',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePin
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() => _obscurePin = !_obscurePin);
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _reconnectionFrequency,
                        items: _frequencies
                            .map(
                              (f) => DropdownMenuItem(
                                value: f,
                                child: Text(_frequencyLabel(f)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null)
                            setState(() => _reconnectionFrequency = value);
                        },
                        decoration: InputDecoration(
                          labelText:
                              context.tr('Demande de reconnexion tous les...'),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: Icon(Icons.check),
                        label: Text(context.tr('Confirmer')),
                        onPressed: () {
                          if (_pinController.text.length == 6) {
                            setState(() => _securityConfirmed = true);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.tr(
                                    'Le code PIN doit contenir 6 chiffres.',
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // BOUTON BAS DE PAGE
          SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.13,
                child: OutlinedButton(
                  onPressed: _previousPage,
                  child: Icon(Icons.arrow_back),
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (allSectionsConfirmed) {
                      _register();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.tr(
                              'Veuillez completer toutes les sections.',
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: allSectionsConfirmed
                        ? Colors.green
                        : Theme.of(context).colorScheme.outline,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    context.tr('Creer mon compte'),
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required bool confirmed,
    required VoidCallback onEdit,
    required bool contentVisible,
    required Widget content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.24),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: confirmed
              ? Colors.green.withOpacity(0.35)
              : Theme.of(context).colorScheme.outline.withOpacity(0.14),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec icône et bouton éditer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    confirmed ? Icons.check_circle : Icons.cancel,
                    color: confirmed ? Colors.green : Colors.red,
                  ),
                  SizedBox(width: 8),
                  Text(title, style: TextStyle(fontSize: 18)),
                ],
              ),
              IconButton(icon: Icon(Icons.edit), onPressed: onEdit),
            ],
          ),
          SizedBox(height: 12),
          // Contenu uniquement si nécessaire
          if (contentVisible) content,
        ],
      ),
    );
  }
}

class _OnboardingBullet {
  final IconData icon;
  final String title;
  final String subtitle;

  const _OnboardingBullet({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
