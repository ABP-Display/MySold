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
    itemBuilder: (context, index) =>
        _RetainedSection(key: ValueKey(index), builder: sections[index]),
    separatorBuilder: (context, index) => SizedBox(height: gaps[index]),
  );
}

/// Only visited sections are kept. Returning to a chart does not construct its
/// render tree again; sections outside the viewport neither paint nor lay out.
class _RetainedSection extends StatefulWidget {
  final WidgetBuilder builder;
  const _RetainedSection({super.key, required this.builder});
  @override
  State<_RetainedSection> createState() => _RetainedSectionState();
}

class _RetainedSectionState extends State<_RetainedSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.builder(context);
  }
}
