import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/widgets/app_selection_button.dart';

String annualEntityAmount(
  BuildContext context,
  num value,
  String currency, {
  required bool hidden,
}) => hidden
    ? '•••• $currency'
    : NumberFormat.currency(
        locale: Localizations.localeOf(context).toString(),
        symbol: currency,
        decimalDigits: 2,
      ).format(value);

class AnnualEntityRow extends StatelessWidget {
  final String name, subtitle, amount;
  final IconData icon;
  final Color color;
  final num? percent;
  final bool hidden, category, expense;
  final VoidCallback onTap;
  final Widget? menu;
  const AnnualEntityRow({
    super.key,
    required this.name,
    required this.subtitle,
    required this.amount,
    required this.icon,
    required this.color,
    required this.percent,
    required this.hidden,
    required this.onTap,
    this.category = false,
    this.expense = false,
    this.menu,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = percent;
    final rate = hidden
        ? '••••'
        : value == null
        ? '—'
        : '${value > 0 ? '+' : ''}${NumberFormat.decimalPercentPattern(locale: Localizations.localeOf(context).toString(), decimalDigits: 1).format(value / 100)}';
    final rateColor = hidden || value == null || value == 0
        ? colors.onSurfaceVariant
        : (value > 0) != (category && expense)
        ? Colors.green
        : Colors.redAccent;
    return AppSelectionButton(
      selected: false,
      onPressed: onTap,
      backgroundColor: colors.surface,
      borderRadius: BorderRadius.circular(8),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width < 400 ? 116 : 190,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Tooltip(
                  message: context.tr(
                    value == null
                        ? 'Non calculable'
                        : category
                        ? 'Année précédente, même période'
                        : 'Au 1er janvier',
                  ),
                  child: Text(
                    rate,
                    style: TextStyle(color: rateColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          if (menu != null)
            menu!
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.chevron_right, size: 20),
            ),
        ],
      ),
    );
  }
}

class EntityActionsMenu extends StatelessWidget {
  final VoidCallback onEdit, onDelete;
  const EntityActionsMenu({
    super.key,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
    itemBuilder: (context) => [
      PopupMenuItem(
        value: 'edit',
        child: Row(
          children: [
            const Icon(Icons.edit_outlined),
            const SizedBox(width: 8),
            Text(context.tr('Modifier')),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(context.tr('Supprimer')),
          ],
        ),
      ),
    ],
  );
}
