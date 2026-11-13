// Real pages backed by the runner's in-memory API fixtures, never user data.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/providers/user_data_provider.dart';
import 'package:mysold/screens/profile/category_page.dart';
import 'package:mysold/screens/profile/entity_evolution_page.dart';
import 'package:mysold/screens/profile/account_page.dart';
import 'package:flutter/semantics.dart';
import 'package:mysold/screens/profile/investment_page.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/screens/settings/theme_settings.dart';
import 'package:mysold/widgets/app_typography.dart';
import 'package:mysold/widgets/simulation/simulation_workspace.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  await initializeDateFormatting();
  FlutterError.onError = (details) {
    web.document.body!.dataset['fixtureError'] = details.exceptionAsString();
  };
  final page = Uri.base.queryParameters['page'];
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserDataProvider()),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
        ChangeNotifierProvider(create: (_) => PrivacyProvider()),
      ],
      child: MaterialApp(
        navigatorObservers: [_FixtureNavigation()],
        locale: Locale(Uri.base.queryParameters['lang'] ?? 'fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppThemes.dark,
        builder: (context, child) => NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.axis == Axis.vertical)
              web.document.body!.dataset['scrollOffset'] =
                  '${n.metrics.pixels}';
            return false;
          },
          child: AppTypography.readable(context, child!),
        ),
        home: switch (page) {
          'annual' => EntityEvolutionPage(
            userId: 'fixture',
            entityPath: 'accounts/0',
            name: 'Compte titres',
            onEdit: (_) async {},
          ),
          'accounts' => const ComptePage(userId: 'fixture'),
          'categories' => const CategoriePage(userId: 'fixture'),
          'investments' => const InvestmentPage(userId: 'fixture'),
          _ => const SimulationWorkspace(currency: '€'),
        },
      ),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    web.document.body!.dataset['fixtureReady'] = 'true';
  });
}

class _FixtureNavigation extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    web.document.body!.dataset['routeName'] = route.settings.name ?? '/';
  }
}
