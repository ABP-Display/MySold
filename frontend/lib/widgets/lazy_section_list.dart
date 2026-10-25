import 'package:flutter/material.dart';

/// Defer constructing chart data and panel widgets until the scroll viewport
/// needs them, rather than eagerly calling every section from the page build.
class LazySectionList extends StatelessWidget {
  final List<WidgetBuilder> sections;
  final List<double> gaps;
  final EdgeInsetsGeometry padding;
  const LazySectionList({
    super.key,
    required this.sections,
    required this.gaps,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 28),
  }) : assert(gaps.length == sections.length - 1);

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: padding,
    itemCount: sections.length,
    itemBuilder: (context, index) => sections[index](context),
    separatorBuilder: (context, index) => SizedBox(height: gaps[index]),
  );
}
