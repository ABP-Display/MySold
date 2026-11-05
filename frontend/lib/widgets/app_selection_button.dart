import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

/// A navigation/filter selection changes immediately. Hover and keyboard focus
/// remain visible without scheduling ripple, text-style or color animations.
class AppSelectionButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final bool selected;
  final bool outlined;
  final bool isTab;
  final double minHeight;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final BorderRadius borderRadius;
  final EdgeInsets selectionInset;
  const AppSelectionButton({
    super.key,
    required this.child,
    required this.onPressed,
    required this.selected,
    this.outlined = true,
    this.isTab = false,
    this.minHeight = 46,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.backgroundColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.selectionInset = EdgeInsets.zero,
  });

  @override
  State<AppSelectionButton> createState() => _AppSelectionButtonState();
}

class _AppSelectionButtonState extends State<AppSelectionButton> {
  bool _hovered = false;
  bool _focused = false;
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _activate() {
    _focus.requestFocus();
    widget.onPressed();
  }

  Widget _surface(BoxDecoration decoration, Widget child) {
    final constraints = BoxConstraints(
      minWidth: 44,
      minHeight: widget.minHeight,
    );
    if (widget.selectionInset == EdgeInsets.zero) {
      return Container(
        constraints: constraints,
        padding: widget.padding,
        decoration: decoration,
        child: child,
      );
    }
    // Shrink only the painted selection, not its tap target or text layout.
    return ConstrainedBox(
      constraints: constraints,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: widget.selectionInset,
                child: DecoratedBox(decoration: decoration),
              ),
            ),
          ),
          Padding(
            padding: widget.padding.add(const EdgeInsets.all(1.25)),
            child: child,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = widget.selected
        ? colors.primary
        : colors.onSurfaceVariant;
    final background = widget.backgroundColor ?? Colors.transparent;
    final fill = widget.selected
        ? Color.alphaBlend(colors.primary.withValues(alpha: 0.12), background)
        : background;
    return Semantics(
      button: !widget.isTab,
      role: widget.isTab ? SemanticsRole.tab : null,
      selected: widget.selected,
      onTap: _activate,
      child: FocusableActionDetector(
        focusNode: _focus,
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: _activate,
          child: _surface(
            BoxDecoration(
              color: _hovered
                  ? Color.alphaBlend(
                      colors.primary.withValues(alpha: 0.06),
                      fill,
                    )
                  : fill,
              borderRadius: widget.borderRadius,
              border: Border.all(
                width: 1.25,
                color: _focused
                    ? colors.primary
                    : widget.outlined
                    ? widget.selected
                          ? colors.primary.withValues(alpha: 0.6)
                          : colors.outlineVariant
                    : Colors.transparent,
              ),
            ),
            IconTheme.merge(
              data: IconThemeData(color: foreground),
              child: DefaultTextStyle.merge(
                style: Theme.of(
                  context,
                ).textTheme.labelLarge!.copyWith(color: foreground),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
