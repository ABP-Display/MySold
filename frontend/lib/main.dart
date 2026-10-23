import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mysold/data/document_store.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

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
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  DateTime _lastShakeAt = DateTime.fromMillisecondsSinceEpoch(0);

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
    _startShakePrivacyListener();
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

  void _startShakePrivacyListener() {
    if (kIsWeb) return;

    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      final force = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      final now = DateTime.now();
      if (force < 22 || now.difference(_lastShakeAt).inMilliseconds < 900) {
        return;
      }

      _lastShakeAt = now;
      if (!mounted) return;
      final privacy = context.read<PrivacyProvider>();
      privacy.toggleShakeHideAmounts();
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            privacy.persistentHideAmounts
                ? context.tr('Mode discret actif dans les parametres')
                : privacy.shakeHideAmounts
                ? context.tr('Montants masques')
                : context.tr('Montants visibles'),
          ),
          duration: const Duration(milliseconds: 900),
        ),
      );
    });
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

  Widget _buildTopNavigation(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.28),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.outline.withOpacity(0.10)),
          ),
          child: Row(
            children: List.generate(_navItems.length, (index) {
              return Expanded(
                child: _TopNavigationButton(
                  item: _navItems[index],
                  isSelected: _selectedIndex == index,
                  onTap: () => _goToPage(index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildTopNavigation(context),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: const [
                MonthManagerScreen(),
                AnalyticsPage(),
                DashboardScreen(),
                ProfilePage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accelerometerSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }
}

class _TopNavigationButton extends StatelessWidget {
  final _HomeNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _TopNavigationButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedColor = colorScheme.primary;
    final idleColor = colorScheme.onSurface.withOpacity(0.70);
    final contentColor = isSelected ? selectedColor : idleColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? selectedColor.withOpacity(0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? selectedColor.withOpacity(0.30)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 18, color: contentColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  context.tr(item.labelKey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: contentColor,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeNavItem {
  final String labelKey;
  final IconData icon;

  const _HomeNavItem({required this.labelKey, required this.icon});
}
