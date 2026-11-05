// Real pages backed by the runner's in-memory API fixtures, never user data.
import 'package:flutter/material.dart';
import 'package:mysold/providers/user_data_provider.dart';
import 'package:mysold/screens/profile/category_page.dart';
import 'package:mysold/screens/profile/investment_page.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/screens/settings/theme_settings.dart';
import 'package:mysold/widgets/app_typography.dart';
import 'package:mysold/widgets/simulation/simulation_workspace.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        theme: AppThemes.dark,
        builder: (context, child) => AppTypography.readable(context, child!),
        home: switch (page) {
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
