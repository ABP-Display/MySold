import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/widgets/simulation/simulation_workspace.dart';

class SimulationScreen extends StatelessWidget {
  final bool withBack;
  const SimulationScreen({super.key, this.withBack = false});

  @override
  Widget build(BuildContext context) => SimulationWorkspace(
    currency: context.watch<CurrencyProvider>().currency,
    withBack: withBack,
  );
}
