import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mysold/data/document_store.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:provider/provider.dart';

import 'package:mysold/enterPinPage.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/providers/user_data_provider.dart';
import 'package:mysold/screens/analytics/analytics_page.dart';
import 'package:mysold/screens/month/month_manager.dart';
import 'package:mysold/screens/dashboard/dashboard.dart';
import 'package:mysold/screens/profile/profile_page.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/language_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/screens/settings/theme_provider.dart';
import 'package:mysold/services/auth_service.dart';
import 'package:mysold/login_page.dart';
import 'package:mysold/services/local_notification_service.dart';
import 'package:mysold/widgets/icon_loader.dart';
import 'package:mysold/widgets/pwa_update_prompt.dart';
import 'package:mysold/widgets/app_workspace.dart';
import 'package:mysold/services/shake_privacy_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    initializeDateFormatting('fr', null),
    initializeDateFormatting('fr_FR', null),
    initializeDateFormatting('en', null),
    initializeDateFormatting('es', null),
    initializeDateFormatting('de', null),
    initializeDateFormatting('it', null),
    initializeDateFormatting('ja', null),
  ]);

  final currencyProvider = CurrencyProvider();
  await currencyProvider.loadCurrency();

  final languageProvider = LanguageProvider();
  await languageProvider.loadLanguage();

  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  final privacyProvider = PrivacyProvider();
  await privacyProvider.load();

  try {
    await LocalAuth.instance.initialize();
  } catch (_) {
    runApp(
      MaterialApp(
        title: 'MySold',
        debugShowCheckedModeBanner: false,
        theme: themeProvider.themeData,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 40),
                  const SizedBox(height: 16),
                  const Text(
                    'Connexion à votre serveur MySold impossible.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: main,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }
  await LocalNotificationService.initialize();

  if (kIsWeb) {
    IconLoader.load();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => currencyProvider),
        ChangeNotifierProvider(create: (_) => languageProvider),
        ChangeNotifierProvider(create: (_) => themeProvider),
        ChangeNotifierProvider(create: (_) => privacyProvider),
        ChangeNotifierProvider(create: (_) => UserDataProvider()),
        Provider<AuthService>(create: (_) => AuthService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();

    return MaterialApp(
      navigatorKey: _navigatorKey,
      builder: (context, child) => PwaUpdatePrompt(
        navigatorKey: _navigatorKey,
        child: child ?? const SizedBox.shrink(),
      ),
      title: 'MySold',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      locale: languageProvider.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: StreamBuilder<User?>(
        stream: LocalAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return snapshot.data == null
              ? const LoginPage()
              : UserPreferencesLoader(
                  user: snapshot.data!,
                  child: const EnterPinPage(),
                );
        },
      ),
    );
  }
}

class UserPreferencesLoader extends StatefulWidget {
  final User user;
  final Widget child;

  const UserPreferencesLoader({
    super.key,
    required this.user,
    required this.child,
  });

  @override
  State<UserPreferencesLoader> createState() => _UserPreferencesLoaderState();
}

class _UserPreferencesLoaderState extends State<UserPreferencesLoader> {
  late Future<void> _loadPreferencesFuture;

  @override
  void initState() {
    super.initState();
    _loadPreferencesFuture = _loadPreferences();
  }

  @override
  void didUpdateWidget(covariant UserPreferencesLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      setState(() {
        _loadPreferencesFuture = _loadPreferences();
      });
    }
  }

  Future<void> _loadPreferences() async {
    final uid = widget.user.uid;
    context.read<UserDataProvider>().setUser(uid);
    await Future.wait([
      context.read<AuthService>().updateLastConnection(widget.user),
      context.read<ThemeProvider>().loadThemeForUser(uid),
      context.read<CurrencyProvider>().loadCurrencyForUser(uid),
      context.read<LanguageProvider>().loadLanguageForUser(uid),
      context.read<UserDataProvider>().ensureReferences(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadPreferencesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return widget.child;
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final PageController _pageController;
  int _selectedIndex = 0;
  bool _wasInBackground = false;
  bool _isLocking = false;
  DateTime? _backgroundAt;
  final _shakeService = ShakePrivacyService();
  PrivacyProvider? _privacy;
  bool _shakeListening = false;

  List<_HomeNavItem> get _navItems => const [
    _HomeNavItem(labelKey: 'Mois', icon: Icons.calendar_month_outlined),
    _HomeNavItem(labelKey: 'Stats', icon: Icons.query_stats_rounded),
    _HomeNavItem(labelKey: 'Global', icon: Icons.dashboard_outlined),
    _HomeNavItem(labelKey: 'Profil', icon: Icons.person_outline),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _wasInBackground = true;
      _backgroundAt ??= DateTime.now();
      return;
    }

    if (state == AppLifecycleState.resumed && _wasInBackground) {
      _wasInBackground = false;
      _lockIfNeeded();
    }
  }

  Future<void> _lockIfNeeded() async {
    if (_isLocking || !mounted) return;

    final uid = LocalAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _isLocking = true;
    try {
      final doc = await DocumentStore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data() ?? {};
      final frequency = _normalizeLockFrequency(data['reconnectionFrequency']);
      final delayMinutes = _normalizeLockDelay(data['lockDelayMinutes']);
      final elapsed = _backgroundAt == null
          ? Duration.zero
          : DateTime.now().difference(_backgroundAt!);
      _backgroundAt = null;

      final shouldLock =
          frequency == 'always' && elapsed >= Duration(minutes: delayMinutes);

      if (!shouldLock || !mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EnterPinPage()),
      );
    } finally {
      _isLocking = false;
    }
  }

  String _normalizeLockFrequency(dynamic value) {
    final raw = (value ?? 'never').toString().toLowerCase().trim();
    if (raw == 'always' ||
        raw == 'toujours' ||
        raw == 'chaque ouverture' ||
        raw == 'chaque ouverture de l app' ||
        raw == 'chaque ouverture de l\'app') {
      return 'always';
    }
    return 'never';
  }

  int _normalizeLockDelay(dynamic value) {
    if (value is num) return value.toInt().clamp(0, 1440).toInt();
    return int.tryParse((value ?? '0').toString())?.clamp(0, 1440).toInt() ?? 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final privacy = context.read<PrivacyProvider>();
    if (_privacy != privacy) {
      _privacy?.removeListener(_syncShakePreference);
      _privacy = privacy;
      privacy.addListener(_syncShakePreference);
      _syncShakePreference();
    }
  }

  void _syncShakePreference() {
    final enabled = _privacy?.shakeEnabled ?? false;
    if (enabled == _shakeListening) return;
    _shakeListening = enabled;
    if (enabled) {
      _shakeService.start(() {
        if (mounted) _privacy?.hideWithShake();
      });
    } else {
      _shakeService.stop();
    }
  }

  void _onPageChanged(int index) {
    setState(() => _selectedIndex = index);
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final privacy = context.watch<PrivacyProvider>();
    return AppWorkspace(
      selectedIndex: _selectedIndex,
      destinations: _navItems
          .map((item) => WorkspaceDestination(item.labelKey, item.icon))
          .toList(),
      onSelected: _goToPage,
      hidden: privacy.hideAmounts,
      onPrivacy: () => privacy.setHideAmounts(!privacy.hideAmounts),
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: _onPageChanged,
        children: const [
          MonthManagerScreen(),
          AnalyticsPage(),
          DashboardScreen(),
          ProfilePage(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _privacy?.removeListener(_syncShakePreference);
    _shakeService.stop();
    _pageController.dispose();
    super.dispose();
  }
}

class _HomeNavItem {
  final String labelKey;
  final IconData icon;

  const _HomeNavItem({required this.labelKey, required this.icon});
}
