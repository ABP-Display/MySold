import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/annual_evolution.dart';
import 'app_design.dart';

/// Values stay visible next to the comparison; no hover, swipe or tooltip needed.
class AnnualEvolutionSection extends StatefulWidget {
  final String title, subtitle, beginningLabel, endingLabel, emptyLabel;
  final String currency;
  final IconData icon;
  final List<EvolutionEntry> entries;
  final bool hideAmounts, lowerIsBetter;
  final String? note;
  final Widget? controls;
  const AnnualEvolutionSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.beginningLabel,
    required this.endingLabel,
    required this.entries,
    required this.currency,
    required this.icon,
    required this.emptyLabel,
    this.hideAmounts = false,
    this.lowerIsBetter = false,
    this.note,
    this.controls,
  });
  @override
  State<AnnualEvolutionSection> createState() => _AnnualEvolutionSectionState();
}

class _AnnualEvolutionSectionState extends State<AnnualEvolutionSection> {
  int _visible = 6;
  @override
  void didUpdateWidget(covariant AnnualEvolutionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subtitle != widget.subtitle ||
        oldWidget.title != widget.title)
      _visible = 6;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme;
    final extent = widget.entries.fold(
      0.0,
      (value, entry) =>
          math.max(value, math.max(entry.beginning.abs(), entry.ending.abs())),
    );
    final negative = widget.entries.any(
      (entry) => entry.beginning < 0 || entry.ending < 0,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDesign.panel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (widget.controls != null) ...[
            const SizedBox(height: 16),
            widget.controls!,
          ],
          const SizedBox(height: 18),
          if (widget.entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(widget.emptyLabel),
            )
          else ...[
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _Legend(
                  label: widget.beginningLabel,
                  color: scheme.onSurfaceVariant.withValues(alpha: .65),
                ),
                _Legend(label: widget.endingLabel, color: scheme.primary),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, bounds) {
                final columns =
                    bounds.maxWidth >= 820 &&
                        MediaQuery.textScalerOf(context).scale(14) < 23
                    ? 2
                    : 1;
                final width = (bounds.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final entry in widget.entries.take(_visible))
                      SizedBox(
                        width: width,
                        child: _EvolutionCard(
                          entry: entry,
                          currency: widget.currency,
                          beginningLabel: widget.beginningLabel,
                          endingLabel: widget.endingLabel,
                          hideAmounts: widget.hideAmounts,
                          lowerIsBetter: widget.lowerIsBetter,
                          extent: extent,
                          negative: negative,
                        ),
                      ),
                  ],
                );
              },
            ),
            if (_visible < widget.entries.length)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton.icon(
                  onPressed: () => setState(() => _visible += 6),
                  icon: const Icon(Icons.expand_more),
                  label: Text(
                    '${context.tr('Afficher plus')} (${widget.entries.length - _visible})',
                  ),
                ),
              ),
          ],
          if (widget.note != null) ...[
            const SizedBox(height: 16),
            Text(
              widget.note!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  const _Legend({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 5,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    ],
  );
}

class _EvolutionCard extends StatelessWidget {
  final EvolutionEntry entry;
  final String currency, beginningLabel, endingLabel;
  final bool hideAmounts, lowerIsBetter, negative;
  final double extent;
  const _EvolutionCard({
    required this.entry,
    required this.currency,
    required this.beginningLabel,
    required this.endingLabel,
    required this.hideAmounts,
    required this.lowerIsBetter,
    required this.extent,
    required this.negative,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final money = NumberFormat.currency(
      locale: locale,
      symbol: currency,
      decimalDigits: 2,
    );
    final number = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 1,
    );
    final delta = entry.change;
    final good = lowerIsBetter ? delta < 0 : delta > 0;
    final color = hideAmounts || delta == 0
        ? scheme.onSurfaceVariant
        : good
        ? Colors.green.shade600
        : scheme.error;
    final rate = hideAmounts
        ? '** %'
        : entry.percent == null
        ? context.tr('Base nulle')
        : '${entry.percent! > 0 ? '+' : ''}${number.format(entry.percent)} %';
    String amount(double value) =>
        hideAmounts ? '•••• $currency' : money.format(value);
    return Container(
      key: ValueKey('evolution-${entry.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppDesign.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            entry.name.isEmpty
                ? context.tr('Catégorie non renseignée')
                : entry.name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!hideAmounts) ...[
                      Icon(
                        delta == 0
                            ? Icons.remove
                            : delta > 0
                            ? Icons.north_east
                            : Icons.south_east,
                        size: 14,
                        color: color,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        rate,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                hideAmounts
                    ? '•••• $currency'
                    : '${delta > 0 ? '+' : ''}${money.format(delta)}',
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, bounds) {
              Widget value(String label, double value) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    amount(value),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
              if (bounds.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(14) > 23)
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    value(beginningLabel, entry.beginning),
                    const SizedBox(height: 12),
                    value(endingLabel, entry.ending),
                  ],
                );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: value(beginningLabel, entry.beginning)),
                  const SizedBox(width: 12),
                  Expanded(child: value(endingLabel, entry.ending)),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          // Hidden amounts must not leak through bar lengths, directions or colors.
          ExcludeSemantics(
            child: SizedBox(
              height: 30,
              child: CustomPaint(
                painter: _ComparisonPainter(
                  beginning: hideAmounts ? 1 : entry.beginning,
                  ending: hideAmounts ? 1 : entry.ending,
                  extent: hideAmounts ? 1 : extent,
                  negative: !hideAmounts && negative,
                  beginningColor: scheme.onSurfaceVariant.withValues(
                    alpha: hideAmounts ? .25 : .65,
                  ),
                  endingColor: hideAmounts
                      ? scheme.onSurfaceVariant.withValues(alpha: .25)
                      : scheme.primary,
                  trackColor: scheme.onSurface.withValues(alpha: .07),
                ),
              ),
            ),
          ),
          if (!hideAmounts && entry.percent == null) ...[
            const SizedBox(height: 8),
            Text(
              context.tr('Taux non calculable depuis un montant nul.'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComparisonPainter extends CustomPainter {
  final double beginning, ending, extent;
  final bool negative;
  final Color beginningColor, endingColor, trackColor;
  const _ComparisonPainter({
    required this.beginning,
    required this.ending,
    required this.extent,
    required this.negative,
    required this.beginningColor,
    required this.endingColor,
    required this.trackColor,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final zero = negative ? size.width / 2 : 0.0;
    final scale = extent > 0
        ? (negative ? size.width / 2 : size.width) / extent
        : 0.0;
    final paint = Paint();
    for (final item in [
      (beginning, beginningColor, 1.0),
      (ending, endingColor, 18.0),
    ]) {
      paint.color = trackColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, item.$3, size.width, 8),
          const Radius.circular(4),
        ),
        paint,
      );
      final end = (zero + item.$1 * scale).clamp(0.0, size.width);
      paint.color = item.$2;
      if (end != zero)
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              math.min(zero, end),
              item.$3,
              math.max(zero, end),
              item.$3 + 8,
            ),
            const Radius.circular(4),
          ),
          paint,
        );
    }
    if (negative)
      canvas.drawLine(
        Offset(zero, 0),
        Offset(zero, size.height),
        Paint()
          ..color = beginningColor
          ..strokeWidth = 1,
      );
  }

  @override
  bool shouldRepaint(covariant _ComparisonPainter old) =>
      beginning != old.beginning ||
      ending != old.ending ||
      extent != old.extent ||
      negative != old.negative ||
      beginningColor != old.beginningColor ||
      endingColor != old.endingColor ||
      trackColor != old.trackColor;
}
