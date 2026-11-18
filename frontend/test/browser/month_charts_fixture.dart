import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/month_chart_data.dart';
import 'package:mysold/screens/month/month_graph.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/screens/settings/theme_settings.dart';
import 'package:mysold/widgets/app_typography.dart';
import 'package:mysold/widgets/web_scroll_scope.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import '../fixtures/month_chart_fixture.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  await initializeDateFormatting();
  FlutterError.onError = (details) {
    web.document.body!.dataset['fixtureError'] = details.toString();
  };
  final data = MonthChartData.build(
    DateTime(2026, 6),
    monthChartFixture(),
    investmentTypes: chartFixtureTypes,
  );
  if (data.investmentTotal != 45000 ||
      data.transferTotal != 65000 ||
      data.weeks[1].total != 15000) {
    throw StateError('Incorrect fixture aggregation');
  }
  final args = Uri.base.queryParameters;
  final privacy = PrivacyProvider();
  if (args['privacy'] == 'true') await privacy.setHideAmounts(true);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
        ChangeNotifierProvider.value(value: privacy),
      ],
      child: MaterialApp(
        theme: args['theme'] == 'light' ? AppThemes.light : AppThemes.dark,
        locale: Locale(args['lang'] ?? 'fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              double.tryParse(args['scale'] ?? '1') ?? 1,
            ),
          ),
          child: WebScrollScope(child: AppTypography.readable(context, child!)),
        ),
        home: Scaffold(
          body: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              web.document.body!.dataset['scrollOffset'] =
                  '${n.metrics.pixels}';
              return false;
            },
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'MySold · Juin 2026',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        MonthGraph(
                          month: DateTime(2026, 6),
                          transactions: monthChartFixture(),
                          categories: chartFixtureCategories,
                          accountIds: chartFixtureAccounts,
                          investmentIds: chartFixtureInvestments,
                          investmentTypes: chartFixtureTypes,
                          type: args['type'] ?? 'expense',
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Transactions mensuelles',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList.builder(
                  itemCount: 40,
                  itemBuilder: (context, i) => ListTile(
                    title: Text('Opération illustrative ${i + 1}'),
                    subtitle: const Text('Compte courant · 06/2026'),
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    web.document.body!.dataset['fixtureReady'] = 'true';
  });
}
