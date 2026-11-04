// Real workspace pages with an empty, unauthenticated fixture and no API calls.
import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:mysold/providers/user_data_provider.dart';
import 'package:mysold/screens/analytics/analytics_page.dart';
import 'package:mysold/screens/dashboard/dashboard.dart';
import 'package:mysold/screens/month/month_manager.dart';
import 'package:mysold/screens/profile/profile_page.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/widgets/app_loading_screen.dart';
import 'package:mysold/widgets/retained_page_view.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;

class WorkspaceFixture extends StatefulWidget {
  const WorkspaceFixture({super.key});
  @override
  State<WorkspaceFixture> createState() => _WorkspaceFixtureState();
}

class _WorkspaceFixtureState extends State<WorkspaceFixture> {
  final _controller = PageController();
  final _ready = List.generate(4, (_) => Completer<void>());
  final _notifications = [0, 0, 0, 0];
  bool _prepared = false;
  late final _readiness = _ready.map((ready) => ready.future).toList();
  late final _pages = [
    MonthManagerScreen(onInitialLoad: () => _signal(0)),
    AnalyticsPage(onInitialLoad: () => _signal(1)),
    DashboardScreen(onInitialLoad: () => _signal(2)),
    ProfilePage(onInitialLoad: () => _signal(3)),
  ];
  late final JSFunction _navigate = ((web.CustomEvent event) {
    final index = (event.detail as JSNumber).toDartInt;
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
    );
  }).toJS;

  void _signal(int index) {
    _notifications[index]++;
    web.document.body!.setAttribute(
      'data-page-notifications',
      _notifications.join(','),
    );
    _ready[index].complete();
  }

  @override
  void initState() {
    super.initState();
    web.window.addEventListener('mysold-fixture-tab', _navigate);
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => UserDataProvider()),
      ChangeNotifierProvider(create: (_) => CurrencyProvider()),
      ChangeNotifierProvider(create: (_) => PrivacyProvider()),
    ],
    child: MaterialApp(
      home: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            excluding: !_prepared,
            child: ExcludeFocus(
              excluding: !_prepared,
              child: RetainedPageView(
                controller: _controller,
                readiness: _readiness,
                onPrepared: () {
                  setState(() => _prepared = true);
                  web.document.body!.setAttribute('data-fixture-ready', 'true');
                  web.document.body!.setAttribute(
                    'data-selected-tab',
                    '${_controller.page}',
                  );
                },
                onPageChanged: (index) => web.document.body!.setAttribute(
                  'data-selected-tab',
                  '$index',
                ),
                children: _pages,
              ),
            ),
          ),
          if (!_prepared) const AppLoadingScreen(),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    web.window.removeEventListener('mysold-fixture-tab', _navigate);
    _controller.dispose();
    super.dispose();
  }
}
