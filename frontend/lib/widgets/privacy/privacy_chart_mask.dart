import 'package:flutter/material.dart';
import 'package:mysold/l10n/app_localizations.dart';

class PrivacyChartMask extends StatelessWidget {
  final double height;

  const PrivacyChartMask({
    super.key,
    this.height = 190,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withOpacity(0.24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outline.withOpacity(0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.visibility_off_outlined,
            color: colors.onSurface.withOpacity(0.48),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('Graphique masque'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface.withOpacity(0.58),
                ),
          ),
        ],
      ),
    );
  }
}
