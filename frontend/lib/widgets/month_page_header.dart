import 'package:flutter/material.dart';
import 'package:mysold/widgets/app_design.dart';

class MonthPageHeader extends StatelessWidget {
  final String title, subtitle, eyebrow, monthLabel, compactMonthLabel;
  final String previousLabel, nextLabel;
  final VoidCallback onPrevious, onNext;
  const MonthPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.eyebrow,
    required this.monthLabel,
    required this.compactMonthLabel,
    required this.previousLabel,
    required this.nextLabel,
    required this.onPrevious,
    required this.onNext,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 600;
      final colors = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              eyebrow.toUpperCase(),
              style: TextStyle(
                color: colors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    key: const ValueKey('month-page-title'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: compact ? 20 : 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.7,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.52,
                  ),
                  child: Container(
                    key: const ValueKey('month-selector'),
                    decoration: AppDesign.panel(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: previousLabel,
                          onPressed: onPrevious,
                          icon: const Icon(Icons.chevron_left, size: 20),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(36, 44),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        Flexible(
                          child: Semantics(
                            label: monthLabel,
                            excludeSemantics: true,
                            child: Text(
                              compact ? compactMonthLabel : monthLabel,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: nextLabel,
                          onPressed: onNext,
                          icon: const Icon(Icons.chevron_right, size: 20),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(36, 44),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                height: 1.6,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    },
  );
}
