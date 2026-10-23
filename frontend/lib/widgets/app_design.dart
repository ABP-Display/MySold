import 'package:flutter/material.dart';

abstract final class AppDesign {
  static const contentWidth = 1280.0;
  static const radius = 12.0;
  static TextStyle pageTitle(BuildContext context) => Theme.of(context)
      .textTheme
      .headlineMedium!
      .copyWith(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.8);
  static Color border(BuildContext context) =>
      Theme.of(context).colorScheme.outline.withValues(alpha: 0.38);
  static BoxDecoration panel(BuildContext context) => BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border(context)),
  );
}

/// Keep long navigation titles readable, including with enlarged system text.
AppBar appPageBar(
  BuildContext context, {
  required Text title,
  Widget? leading,
  PreferredSizeWidget? bottom,
  Color? backgroundColor,
}) {
  final style = AppDesign.pageTitle(context);
  final measurement =
      TextPainter(
        text: TextSpan(text: title.data, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      )..layout(
        maxWidth: (MediaQuery.sizeOf(context).width - 88).clamp(
          1,
          double.infinity,
        ),
      );
  final height = (measurement.height + 24).clamp(76.0, double.infinity);
  measurement.dispose();
  return AppBar(
    leading: leading,
    title: Semantics(
      header: true,
      child: Text(
        title.data!,
        key: title.key,
        style: style,
        softWrap: true,
        overflow: TextOverflow.visible,
        textScaler: MediaQuery.textScalerOf(context),
      ),
    ),
    titleTextStyle: style,
    centerTitle: false,
    titleSpacing: 16,
    toolbarHeight: height,
    bottom: bottom,
    backgroundColor: backgroundColor,
  );
}

/// Page headings share the same size on phones and desktop.
class PageIntro extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? eyebrow;
  final Widget? action;
  final Key? titleKey;
  const PageIntro({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.action,
    this.titleKey,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth <
              240 * MediaQuery.textScalerOf(context).scale(14) / 14;
          final heading = Semantics(
            header: true,
            child: Text(
              title,
              key: titleKey,
              style: AppDesign.pageTitle(context),
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (action == null || stacked)
                heading
              else
                Row(
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 0.52,
                      ),
                      child: action!,
                    ),
                  ],
                ),
              if (action != null && stacked) ...[
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: action!),
              ],
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
          );
        },
      ),
    );
  }
}

class AppPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: AppDesign.panel(context),
    child: child,
  );
}

class AppDialogHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const AppDialogHeader({super.key, required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
      const SizedBox(width: 12),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      IconButton(
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.close, size: 20),
      ),
    ],
  );
}

class AppOperationCard extends StatelessWidget {
  final String title, subtitle, amount;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const AppOperationCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final colors = Theme.of(context).colorScheme;
            final amountText = Text(
              amount,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Color.lerp(color, colors.onSurface, 0.35)
                        : color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: (constraints.maxWidth * 0.37).clamp(88.0, 180.0),
                  child: amountText,
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class AppMetricGrid extends StatelessWidget {
  final List<Widget> children;
  const AppMetricGrid({super.key, required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
      final columns = constraints.maxWidth >= 900
          ? (largeText ? 2 : 4)
          : constraints.maxWidth >= 560 || !largeText
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: children
            .map((child) => SizedBox(width: width, child: child))
            .toList(),
      );
    },
  );
}

class AppMetricCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const AppMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => AppPanel(
    padding: const EdgeInsets.all(16),
    child: LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: constraints.maxWidth < 160 ? 18 : 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Compact desktop dialog; full-width bottom sheet on mobile. Existing builders
/// keep ownership of their forms and scrolling, including keyboard insets.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool showDragHandle = true,
  Color? backgroundColor,
  ShapeBorder? shape,
}) {
  if (MediaQuery.sizeOf(context).width >= 760) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.86,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: MaterialLocalizations.of(
                    dialogContext,
                  ).closeButtonTooltip,
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(child: builder(dialogContext)),
              ),
            ],
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.90,
      ),
      child: SingleChildScrollView(child: builder(sheetContext)),
    ),
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    useSafeArea: true,
  );
}
