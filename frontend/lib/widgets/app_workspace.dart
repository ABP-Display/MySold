import 'package:mysold/widgets/app_selection_button.dart';
import 'package:flutter/material.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/widgets/app_design.dart';

class WorkspaceDestination {
  final String label;
  final IconData icon;
  const WorkspaceDestination(this.label, this.icon);
}

class AppWorkspace extends StatelessWidget {
  final int selectedIndex;
  final List<WorkspaceDestination> destinations;
  final ValueChanged<int> onSelected;
  final VoidCallback onPrivacy;
  final bool hidden;
  final Widget child;
  const AppWorkspace({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
    required this.onPrivacy,
    required this.hidden,
    required this.child,
  });

  Widget _brand(BuildContext context, {bool compact = false}) => Row(
    children: [
      Container(
        width: compact ? 36 : 44,
        height: compact ? 36 : 44,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Image.asset('assets/icons/logo.png', fit: BoxFit.contain),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          'MySold.',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 20 : 25,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    ],
  );

  Widget _privacy(BuildContext context, bool compact) {
    final label = context.tr(
      hidden ? 'Afficher les montants' : 'Masquer les montants',
    );
    if (compact)
      return IconButton(
        tooltip: label,
        onPressed: onPrivacy,
        icon: Icon(
          hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 21,
        ),
      );
    return OutlinedButton.icon(
      onPressed: onPrivacy,
      icon: Icon(
        hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 18,
      ),
      label: Text(context.tr(hidden ? 'Montants masqués' : 'Mode discret')),
    );
  }

  Widget _sidebar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 234,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: AppDesign.border(context))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _brand(context),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppDesign.border(context)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 19,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('Espace personnel'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Text(
                context.tr('VOTRE BUDGET'),
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < destinations.length; index++) ...[
                AppSelectionButton(
                  key: ValueKey('destination-$index'),
                  selected: index == selectedIndex,
                  outlined: false,
                  minHeight: 56,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  onPressed: () => onSelected(index),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Icon(destinations[index].icon, size: 21),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          context.tr(destinations[index].label),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: index == selectedIndex
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
              const Spacer(),
              Divider(color: AppDesign.border(context)),
              const SizedBox(height: 12),
              Text(
                context.tr('Votre budget, en toute clarté.'),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth >= 1040 &&
          constraints.maxHeight >= 600 &&
          MediaQuery.textScalerOf(context).scale(13) <= 20;
      final colors = Theme.of(context).colorScheme;
      return Scaffold(
        body: Row(
          children: [
            if (wide) _sidebar(context),
            Expanded(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border(
                        bottom: BorderSide(color: AppDesign.border(context)),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: wide ? 28 : 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            if (wide)
                              Expanded(
                                child: Text(
                                  '${context.tr('Espace personnel')} / ${context.tr(destinations[selectedIndex].label)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              )
                            else
                              Expanded(child: _brand(context, compact: true)),
                            _privacy(context, !wide),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppDesign.contentWidth,
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppDesign.border(context)),
                  ),
                ),
                key: const ValueKey('bottom-navigation'),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        for (
                          var index = 0;
                          index < destinations.length;
                          index++
                        )
                          Expanded(
                            child: AppSelectionButton(
                              key: ValueKey('destination-$index'),
                              selected: selectedIndex == index,
                              outlined: false,
                              minHeight: 68,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              onPressed: () => onSelected(index),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(destinations[index].icon, size: 22),
                                  const SizedBox(height: 4),
                                  Text(
                                    context.tr(destinations[index].label),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
      );
    },
  );
}
